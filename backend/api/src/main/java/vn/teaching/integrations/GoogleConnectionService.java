package vn.teaching.integrations;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.util.UriComponentsBuilder;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class GoogleConnectionService {
    static final String SCOPES = "openid email profile https://www.googleapis.com/auth/classroom.courses https://www.googleapis.com/auth/classroom.rosters https://www.googleapis.com/auth/classroom.profile.emails https://www.googleapis.com/auth/meetings.space.created https://www.googleapis.com/auth/calendar.events.owned";
    private static final class Flow {
        final String verifier = random(), proof = random(), email;
        final long expires = System.currentTimeMillis() + 300_000;
        boolean used; String error; boolean complete; String connectedEmail;
        Flow(String email) { this.email = email; }
    }
    private final Map<String,Flow> flows = new ConcurrentHashMap<>();
    private final GoogleGateway google;
    private final GoogleStore store;
    private final String clientId, secret, redirect;
    public GoogleConnectionService(GoogleGateway google, GoogleStore store,
            @Value("${app.integrations.google.client-id:}") String clientId,
            @Value("${app.integrations.google.client-secret:}") String secret,
            @Value("${app.integrations.google.redirect-uri:http://127.0.0.1:47831/api/integrations/google/callback}") String redirect) {
        this.google=google; this.store=store; this.clientId=clientId; this.secret=secret; this.redirect=redirect;
    }
    public Map<String,Object> status(String email) {
        boolean configured = !clientId.isBlank() && store.configured();
        var subject = email == null || email.isBlank() ? Optional.<String>empty() : store.subject(normalizeEmail(email));
        return Map.of("configured", configured, "connected", configured && subject.isPresent(), "email", subject.isPresent() ? normalizeEmail(email) : "");
    }
    public Map<String,Object> start(String email) {
        return start(email,false);
    }
    public Map<String,Object> start(String email, boolean forceConsent) {
        email = email == null || email.isBlank() ? "" : normalizeEmail(email);
        if (clientId.isBlank() || !store.configured()) throw new GoogleFailure(503,"GOOGLE_NOT_CONFIGURED","Ứng dụng chưa được cấu hình kết nối Google. Liên hệ người cài đặt HocLuc.");
        flows.entrySet().removeIf(e -> e.getValue().expires < System.currentTimeMillis());
        if (flows.size() >= 100) throw new GoogleFailure(429,"OAUTH_BUSY","Có quá nhiều phiên kết nối. Thử lại sau.");
        String state=random(); Flow flow=new Flow(email); flows.put(state,flow);
        String url=UriComponentsBuilder.fromHttpUrl("https://accounts.google.com/o/oauth2/v2/auth")
            .queryParam("client_id",clientId).queryParam("redirect_uri",redirect).queryParam("response_type","code")
            .queryParam("scope",SCOPES).queryParam("state",state).queryParam("code_challenge",hash(flow.verifier))
            .queryParam("code_challenge_method","S256").queryParam("access_type","offline")
            .queryParam("prompt",forceConsent || email.isBlank() || store.subject(email).isEmpty() ? "consent" : "select_account")
            .queryParamIfPresent("login_hint",email.isBlank() ? Optional.empty() : Optional.of(email)).build().encode().toUriString();
        return Map.of("authorizationUrl",url,"state",state,"pollToken",flow.proof,"expiresAt",flow.expires);
    }
    public void callback(String state,String code,String error) {
        Flow flow=flows.get(state == null ? "" : state);
        if (flow==null || flow.expires<System.currentTimeMillis()) throw new GoogleFailure(400,"OAUTH_EXPIRED","Phiên kết nối hết hạn.");
        synchronized(flow) {
            if (flow.used) throw new GoogleFailure(400,"OAUTH_USED","Phiên kết nối đã sử dụng.");
            flow.used=true;
            if (error!=null || code==null || code.isBlank()) { flow.error="Bạn đã hủy cấp quyền Google."; return; }
            try {
                var form=new LinkedHashMap<String,String>(); form.put("client_id",clientId);
                if (!secret.isBlank()) form.put("client_secret",secret);
                form.put("code",code); form.put("code_verifier",flow.verifier); form.put("redirect_uri",redirect); form.put("grant_type","authorization_code");
                var tokens=google.token(form);
                String access=string(tokens,"access_token");
                if (access.isBlank()) throw new GoogleFailure(400,"TOKEN_MISSING","Google không cấp token hợp lệ.");
                var identity=google.call("GET","https://openidconnect.googleapis.com/v1/userinfo",access,null);
                String email=normalizeEmail(string(identity,"email")), subject=string(identity,"sub");
                if (!Boolean.TRUE.equals(identity.get("email_verified")) || subject.isBlank())
                    throw new GoogleFailure(400,"IDENTITY_UNVERIFIED","Google chưa xác minh danh tính tài khoản. Vui lòng chọn tài khoản Google hợp lệ.");
                Set<String> scopes=new HashSet<>(Arrays.asList(string(tokens,"scope").split(" ")));
                for (String required:SCOPES.split(" ")) {
                    if (required.startsWith("https://") && !scopes.contains(required))
                        throw new GoogleFailure(400,"SCOPE_MISSING","Chưa cấp đủ quyền Classroom, Meet và Calendar. Kết nối lại và chọn các quyền cần thiết.");
                }
                var credentials=new LinkedHashMap<String,Object>(tokens);
                if (string(tokens,"refresh_token").isBlank()) {
                    try { credentials.put("refresh_token",store.credentials(subject).get("refresh_token")); } catch (GoogleFailure ignored) { }
                }
                if (string(credentials,"refresh_token").isBlank()) throw new GoogleFailure(400,"REFRESH_MISSING","Google chưa cấp quyền duy trì kết nối. Vui lòng kết nối lại.");
                credentials.put("expiresAt",System.currentTimeMillis()+((Number)tokens.getOrDefault("expires_in",3600)).longValue()*1000);
                store.saveConnection(subject,email,credentials); flow.connectedEmail=email; flow.complete=true;
            } catch (GoogleFailure e) { flow.error=e.getMessage(); }
            catch (Exception e) { flow.error="Không hoàn tất kết nối Google. Vui lòng thử lại."; }
        }
    }
    public Map<String,Object> poll(String state,String proof) {
        Flow flow=flows.get(state == null ? "" : state);
        if (flow==null || proof==null || flow.expires<System.currentTimeMillis()
                || !MessageDigest.isEqual(flow.proof.getBytes(StandardCharsets.UTF_8),proof.getBytes(StandardCharsets.UTF_8)))
            throw new GoogleFailure(401,"OAUTH_EXPIRED","Phiên kết nối hết hạn hoặc không hợp lệ.");
        synchronized(flow) {
            if(flow.error!=null) { flows.remove(state); throw new GoogleFailure(400,"OAUTH_FAILED",flow.error); }
            if(!flow.complete) return Map.of("status","PENDING");
            flows.remove(state); return Map.of("status","COMPLETE","email",flow.connectedEmail);
        }
    }
    public String subject(String email) { return store.subject(normalizeEmail(email)).orElseThrow(() -> new GoogleFailure(401,"CONNECT_GOOGLE","Vui lòng kết nối Google.")); }
    public synchronized String access(String email) {
        String subject=subject(email); var credentials=store.credentials(subject);
        if (((Number)credentials.getOrDefault("expiresAt",0)).longValue()>System.currentTimeMillis()+60_000) return string(credentials,"access_token");
        var form=new LinkedHashMap<String,String>(); form.put("client_id",clientId); if(!secret.isBlank()) form.put("client_secret",secret);
        form.put("grant_type","refresh_token"); form.put("refresh_token",string(credentials,"refresh_token"));
        Map<String,Object> fresh;
        try { fresh=google.token(form); } catch (GoogleFailure e) { throw new GoogleFailure(401,"RECONNECT_GOOGLE","Không gia hạn được quyền Google. Vui lòng kết nối lại."); }
        if(string(fresh,"access_token").isBlank()) throw new GoogleFailure(401,"RECONNECT_GOOGLE","Vui lòng kết nối lại Google.");
        credentials.putAll(fresh); credentials.put("expiresAt",System.currentTimeMillis()+((Number)fresh.getOrDefault("expires_in",3600)).longValue()*1000);
        store.saveConnection(subject,normalizeEmail(email),credentials); return string(credentials,"access_token");
    }
    public synchronized void disconnect(String email) {
        String subject=subject(email); var credentials=store.credentials(subject);
        try { google.revoke(string(credentials,"refresh_token")); }
        catch(GoogleFailure e) { if(!e.code.equals("GOOGLE_400")) throw e; }
        store.disconnect(subject);
    }
    static String normalizeEmail(String input) {
        String email=input==null?"":input.trim().toLowerCase(Locale.ROOT);
        if(email.length()>320 || !email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) throw new GoogleFailure(400,"INVALID_EMAIL","Nhập địa chỉ email Google hợp lệ.");
        return email;
    }
    static String string(Map<?,?> map,String key) { Object value=map.get(key); return value==null?"":value.toString(); }
    static String random() { byte[] bytes=new byte[32]; new SecureRandom().nextBytes(bytes); return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); }
    static String hash(String value) {
        try { return Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.US_ASCII))); }
        catch(NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
