package vn.teaching.exam;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;
import org.springframework.web.util.UriComponentsBuilder;

/** Server-side code flow: state, PKCE and one-time polling proof, no email-only login. */
@Service("examGoogleOAuthService")
public class GoogleOAuthService {
    private static final class Flow {
        final String verifier,proofHash; final long expires; final AtomicBoolean callback=new AtomicBoolean();
        volatile Map<String,Object> result; volatile String error;
        Flow(String verifier,String proof) { this.verifier=verifier; this.proofHash=ExamAuth.digest(proof.getBytes(StandardCharsets.UTF_8)); this.expires=System.currentTimeMillis()+300000; }
    }
    private final Map<String,Flow> flows=new ConcurrentHashMap<>();
    private final ExamAuth auth; private final GoogleOAuthProvider provider; private final String clientId,redirectUri;
    public GoogleOAuthService(ExamAuth auth,GoogleOAuthProvider provider,@Value("${app.auth.google.client-id:}") String clientId,@Value("${app.auth.google.redirect-uri:http://127.0.0.1:47831/api/auth/google/callback}") String redirectUri) {
        this.auth=auth; this.provider=provider; this.clientId=clientId; this.redirectUri=redirectUri;
    }
    public Map<String,Object> start() {
        if(clientId.isBlank()) throw new ExamException(HttpStatus.SERVICE_UNAVAILABLE,"GOOGLE_NOT_CONFIGURED","Chưa cấu hình Google OAuth cho app. Cần GOOGLE_CLIENT_ID và GOOGLE_CLIENT_SECRET ở backend.",List.of());
        flows.entrySet().removeIf(e->e.getValue().expires<System.currentTimeMillis());
        if(flows.size()>=1000) throw new ExamException(HttpStatus.TOO_MANY_REQUESTS,"OAUTH_BUSY","Vui lòng thử lại sau.",List.of());
        String state=random(),proof=random(),verifier=random(); Flow flow=new Flow(verifier,proof); flows.put(state,flow);
        String challenge;
        try { challenge=Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(verifier.getBytes(StandardCharsets.US_ASCII))); }
        catch(NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
        String url=UriComponentsBuilder.fromHttpUrl("https://accounts.google.com/o/oauth2/v2/auth").queryParam("client_id",clientId).queryParam("redirect_uri",redirectUri).queryParam("response_type","code").queryParam("scope","openid email profile").queryParam("state",state).queryParam("code_challenge",challenge).queryParam("code_challenge_method","S256").queryParam("prompt","select_account").build().encode().toUriString();
        return Map.of("authorizationUrl",url,"state",state,"pollToken",proof,"expiresAt",flow.expires);
    }
    public void callback(String state,String code,String error) {
        if(state==null||state.isBlank()) throw ExamException.missing();
        Flow flow=flows.get(state);
        if(flow==null||flow.expires<System.currentTimeMillis()||!flow.callback.compareAndSet(false,true)) throw ExamException.bad("Phiên đăng nhập đã hết hạn hoặc đã sử dụng.");
        if(error!=null||code==null||code.isBlank()) { flow.error="Đăng nhập Google đã bị hủy."; return; }
        try {
            var identity=provider.exchange(code,flow.verifier,redirectUri);
            var result=new HashMap<String,Object>(auth.google(identity.subject(),identity.email(),identity.name()));
            result.put("googleAccessToken",identity.accessToken()); flow.result=Map.copyOf(result);
        } catch(Exception e) { flow.error="Không xác minh được đăng nhập Google. Vui lòng thử lại."; }
    }
    public synchronized Map<String,Object> poll(String state,String proof) {
        if(state==null||state.isBlank()) throw ExamException.missing();
        Flow flow=flows.get(state);
        if(flow==null||proof==null||flow.expires<System.currentTimeMillis()||!MessageDigest.isEqual(flow.proofHash.getBytes(StandardCharsets.US_ASCII),ExamAuth.digest(proof.getBytes(StandardCharsets.UTF_8)).getBytes(StandardCharsets.US_ASCII))) throw ExamException.missing();
        if(flow.error!=null) { flows.remove(state); throw ExamException.bad(flow.error); }
        if(flow.result==null) return Map.of("status","PENDING");
        flows.remove(state); var result=new HashMap<>(flow.result); result.put("status","COMPLETE"); return result;
    }
    private String random() { byte[] bytes=new byte[32]; new SecureRandom().nextBytes(bytes); return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes); }
}
