package vn.teaching.service;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Arrays;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/** Desktop authorization code + PKCE. Google tokens remain in process memory. */
@Service
public class GoogleOAuthService {
    static final String MEET_SCOPE = "https://www.googleapis.com/auth/meetings.space.created";
    private static final Duration FLOW_TTL = Duration.ofMinutes(5);
    private static final Duration SESSION_IDLE_TTL = Duration.ofHours(12);
    private final String clientId;
    private final String clientSecret;
    private final HttpClient httpClient;
    private final URI tokenEndpoint;
    private final URI userInfoEndpoint;
    private final SecureRandom random = new SecureRandom();
    private final Map<String, Flow> flows = new ConcurrentHashMap<>();
    private final Map<String, Grant> grants = new ConcurrentHashMap<>();
    private final ScheduledExecutorService worker = Executors.newScheduledThreadPool(2, runnable -> {
        Thread thread = new Thread(runnable, "google-oauth-loopback");
        thread.setDaemon(true);
        return thread;
    });
    private HttpServer callbackServer;

    @Autowired
    public GoogleOAuthService(@Value("${google.oauth.client-id:}") String clientId,
                              @Value("${google.oauth.client-secret:}") String clientSecret) {
        this(clientId, clientSecret, HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build(),
                URI.create("https://oauth2.googleapis.com/token"),
                URI.create("https://openidconnect.googleapis.com/v1/userinfo"));
    }

    GoogleOAuthService(String clientId, String clientSecret, HttpClient httpClient,
                       URI tokenEndpoint, URI userInfoEndpoint) {
        this.clientId = clientId.trim();
        this.clientSecret = clientSecret.trim();
        this.httpClient = httpClient;
        this.tokenEndpoint = tokenEndpoint;
        this.userInfoEndpoint = userInfoEndpoint;
        worker.scheduleAtFixedRate(this::cleanup, 1, 1, TimeUnit.MINUTES);
    }

    public synchronized Map<String, Object> start(String loginHint) {
        if (clientId.isBlank()) {
            throw new IllegalStateException("Chưa cấu hình Google OAuth. Cần GOOGLE_OAUTH_CLIENT_ID loại Desktop app trên dịch vụ Java.");
        }
        cleanup();
        if (flows.size() >= 8) throw new IllegalStateException("Có quá nhiều yêu cầu Google đang chờ. Hãy đóng yêu cầu cũ rồi thử lại.");
        try {
            if (callbackServer == null) {
                callbackServer = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
                callbackServer.createContext("/oauth/callback", this::callback);
                callbackServer.setExecutor(worker);
                callbackServer.start();
            }
            String redirectUri = "http://127.0.0.1:" + callbackServer.getAddress().getPort() + "/oauth/callback";
            String flowId = randomId();
            Flow flow = new Flow(randomId(), randomId(), redirectUri);
            flows.put(flowId, flow);
            String challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(
                    MessageDigest.getInstance("SHA-256").digest(flow.verifier.getBytes(StandardCharsets.US_ASCII)));
            Map<String, String> params = new HashMap<>();
            params.put("client_id", clientId);
            params.put("redirect_uri", redirectUri);
            params.put("response_type", "code");
            params.put("scope", "openid email profile " + MEET_SCOPE);
            params.put("state", flow.state);
            params.put("code_challenge", challenge);
            params.put("code_challenge_method", "S256");
            params.put("access_type", "offline");
            params.put("prompt", "consent select_account");
            if (loginHint != null && !loginHint.isBlank()) params.put("login_hint", loginHint);
            return Map.of("success", true, "flowId", flowId, "authorizationUrl",
                    "https://accounts.google.com/o/oauth2/v2/auth?" + form(params), "expiresIn", FLOW_TTL.toSeconds());
        } catch (IOException | java.security.NoSuchAlgorithmException e) {
            throw new IllegalStateException("Không thể mở cổng nhận kết quả Google trên máy này.");
        }
    }

    public Map<String, Object> status(String flowId) {
        Flow flow = flowId == null ? null : flows.get(flowId);
        if (flow == null || flow.created.plus(FLOW_TTL).isBefore(Instant.now())) {
            return Map.of("success", false, "status", "EXPIRED", "error", "Phiên cấp quyền đã hết hạn. Hãy kết nối Google lại.");
        }
        synchronized (flow) {
            if (flow.sessionId != null) {
                Grant grant = grants.get(flow.sessionId);
                if (grant == null) return Map.of("success", false, "status", "EXPIRED", "error", "Phiên Google đã đóng.");
                return Map.of("success", true, "status", "CONNECTED", "sessionId", flow.sessionId,
                        "user", Map.of("name", grant.name, "email", grant.email, "avatar", grant.avatar));
            }
            if (flow.error != null) return Map.of("success", false, "status", "ERROR", "error", flow.error);
            return Map.of("success", true, "status", "PENDING");
        }
    }

    public void cancel(String flowId) {
        Flow flow = flowId == null ? null : flows.remove(flowId);
        if (flow != null) {
            synchronized (flow) {
                flow.cancelled = true;
                if (flow.sessionId != null) grants.remove(flow.sessionId);
            }
        }
    }

    public void disconnect(String sessionId) {
        if (sessionId != null) grants.remove(sessionId);
    }

    public String accessToken(String sessionId) {
        Grant grant = sessionId == null ? null : grants.get(sessionId);
        if (grant == null || grant.lastUsed.plus(SESSION_IDLE_TTL).isBefore(Instant.now())) {
            if (sessionId != null) grants.remove(sessionId);
            throw new IllegalStateException("Hãy kết nối Google và cấp quyền tạo phòng Meet trước.");
        }
        synchronized (grant) {
            grant.lastUsed = Instant.now();
            if (grant.expiresAt.isAfter(Instant.now().plusSeconds(60))) return grant.accessToken;
            if (grant.refreshToken == null || grant.refreshToken.isBlank()) {
                grants.remove(sessionId);
                throw new IllegalStateException("Phiên Google đã hết hạn. Hãy kết nối lại Google.");
            }
            try {
                JsonObject refreshed = tokenRequest(Map.of("grant_type", "refresh_token", "refresh_token", grant.refreshToken));
                if (refreshed.has("scope") && !hasMeetScope(refreshed)) throw new IllegalStateException("Thiếu quyền tạo phòng Meet.");
                grant.accessToken = refreshed.get("access_token").getAsString();
                grant.expiresAt = Instant.now().plusSeconds(refreshed.get("expires_in").getAsLong());
                return grant.accessToken;
            } catch (Exception e) {
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                grants.remove(sessionId);
                throw new IllegalStateException("Không thể gia hạn phiên Google. Hãy kết nối lại Google.");
            }
        }
    }

    private void callback(HttpExchange exchange) throws IOException {
        String message = "Không nhận diện được phiên Google. Hãy quay lại HocLuc và thử lại.";
        int httpStatus = 400;
        try {
            Map<String, String> params = parseQuery(exchange.getRequestURI().getRawQuery());
            Flow flow = flows.values().stream().filter(item -> item.state.equals(params.get("state"))).findFirst().orElse(null);
            if (!"GET".equals(exchange.getRequestMethod()) || !"/oauth/callback".equals(exchange.getRequestURI().getPath())
                    || flow == null || flow.created.plus(FLOW_TTL).isBefore(Instant.now())) {
                reply(exchange, httpStatus, message);
                return;
            }
            synchronized (flow) {
                if (flow.claimed || flow.cancelled) {
                    reply(exchange, 400, "Phiên cấp quyền này đã được xử lý hoặc đã hủy.");
                    return;
                }
                flow.claimed = true;
            }
            try {
                if (params.containsKey("error")) throw new IllegalStateException("Bạn chưa cấp quyền Google. Hãy kết nối lại khi sẵn sàng.");
                if (!params.containsKey("code") || params.get("code").isBlank()) throw new IllegalStateException("Google không trả mã cấp quyền.");
                JsonObject tokens = tokenRequest(Map.of("grant_type", "authorization_code", "code", params.get("code"),
                        "redirect_uri", flow.redirectUri, "code_verifier", flow.verifier));
                if (!hasMeetScope(tokens)) throw new IllegalStateException("Chưa cấp quyền tạo phòng Meet. Hãy kết nối lại và cho phép quyền Google Meet.");
                String accessToken = tokens.get("access_token").getAsString();
                HttpResponse<String> profileResponse = httpClient.send(HttpRequest.newBuilder(userInfoEndpoint)
                        .header("Authorization", "Bearer " + accessToken).timeout(Duration.ofSeconds(15)).GET().build(),
                        HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                if (profileResponse.statusCode() != 200) throw new IllegalStateException("Không xác minh được tài khoản Google.");
                JsonObject profile = JsonParser.parseString(profileResponse.body()).getAsJsonObject();
                if (!profile.has("sub") || !profile.has("email") || !profile.has("email_verified")
                        || !profile.get("email_verified").getAsBoolean()) throw new IllegalStateException("Google chưa xác minh email của tài khoản này.");
                Grant grant = new Grant(accessToken, tokens.has("refresh_token") ? tokens.get("refresh_token").getAsString() : null,
                        Instant.now().plusSeconds(tokens.get("expires_in").getAsLong()),
                        profile.has("name") ? profile.get("name").getAsString() : "Giáo viên",
                        profile.get("email").getAsString(), profile.has("picture") ? profile.get("picture").getAsString() : "");
                synchronized (flow) {
                    if (flow.cancelled || flow.created.plus(FLOW_TTL).isBefore(Instant.now())) throw new IllegalStateException("Phiên cấp quyền đã hủy hoặc hết hạn.");
                    flow.sessionId = randomId();
                    grants.put(flow.sessionId, grant);
                }
                message = "Đã kết nối Google. Bạn có thể đóng tab này và quay lại HocLuc.";
                httpStatus = 200;
            } catch (IllegalStateException e) {
                synchronized (flow) { flow.error = e.getMessage(); }
                message = e.getMessage();
            } catch (Exception e) {
                if (e instanceof InterruptedException) Thread.currentThread().interrupt();
                message = "Không hoàn tất được kết nối Google. Kiểm tra mạng rồi thử lại.";
                synchronized (flow) { flow.error = message; }
            }
        } catch (IllegalArgumentException ignored) {
            // Malformed or duplicate parameters never advance an OAuth flow.
        }
        reply(exchange, httpStatus, message);
    }

    private JsonObject tokenRequest(Map<String, String> values) throws IOException, InterruptedException {
        Map<String, String> params = new HashMap<>(values);
        params.put("client_id", clientId);
        if (!clientSecret.isBlank()) params.put("client_secret", clientSecret);
        HttpResponse<String> response = httpClient.send(HttpRequest.newBuilder(tokenEndpoint)
                        .header("Content-Type", "application/x-www-form-urlencoded")
                        .POST(HttpRequest.BodyPublishers.ofString(form(params)))
                        .timeout(Duration.ofSeconds(20)).build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
        if (response.statusCode() != 200) throw new IllegalStateException("Google từ chối cấp token. Kiểm tra cấu hình OAuth và kết nối lại.");
        return JsonParser.parseString(response.body()).getAsJsonObject();
    }

    private static boolean hasMeetScope(JsonObject tokens) {
        return tokens.has("scope") && Arrays.asList(tokens.get("scope").getAsString().split("\\s+")).contains(MEET_SCOPE);
    }

    private String randomId() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private static String form(Map<String, String> params) {
        return params.entrySet().stream().map(e -> URLEncoder.encode(e.getKey(), StandardCharsets.UTF_8)
                + "=" + URLEncoder.encode(e.getValue(), StandardCharsets.UTF_8)).collect(java.util.stream.Collectors.joining("&"));
    }

    private static Map<String, String> parseQuery(String query) {
        Map<String, String> result = new HashMap<>();
        if (query == null) return result;
        for (String pair : query.split("&")) {
            String[] parts = pair.split("=", 2);
            String key = URLDecoder.decode(parts[0], StandardCharsets.UTF_8);
            String value = parts.length > 1 ? URLDecoder.decode(parts[1], StandardCharsets.UTF_8) : "";
            if (result.putIfAbsent(key, value) != null) throw new IllegalArgumentException("Duplicate parameter");
        }
        return result;
    }

    private static void reply(HttpExchange exchange, int status, String message) throws IOException {
        String escaped = message.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;");
        byte[] body = ("<!doctype html><html lang=\"vi\"><meta charset=\"utf-8\"><title>HocLuc · Google</title>"
                + "<body><h1>HocLuc · Google Meet</h1><p>" + escaped + "</p></body></html>").getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "text/html; charset=utf-8");
        exchange.getResponseHeaders().set("Cache-Control", "no-store");
        exchange.getResponseHeaders().set("Referrer-Policy", "no-referrer");
        exchange.getResponseHeaders().set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'");
        exchange.sendResponseHeaders(status, body.length);
        try (var output = exchange.getResponseBody()) { output.write(body); }
    }

    private void cleanup() {
        flows.entrySet().removeIf(e -> e.getValue().created.plus(FLOW_TTL).isBefore(Instant.now()));
        grants.entrySet().removeIf(e -> e.getValue().lastUsed.plus(SESSION_IDLE_TTL).isBefore(Instant.now()));
    }

    @PreDestroy
    public synchronized void close() {
        if (callbackServer != null) callbackServer.stop(0);
        flows.clear();
        grants.clear();
        worker.shutdownNow();
    }

    private static class Flow {
        final String state;
        final String verifier;
        final String redirectUri;
        final Instant created = Instant.now();
        boolean claimed;
        boolean cancelled;
        String sessionId;
        String error;
        Flow(String state, String verifier, String redirectUri) {
            this.state = state; this.verifier = verifier; this.redirectUri = redirectUri;
        }
    }

    private static class Grant {
        String accessToken;
        final String refreshToken;
        Instant expiresAt;
        volatile Instant lastUsed = Instant.now();
        final String name;
        final String email;
        final String avatar;
        Grant(String accessToken, String refreshToken, Instant expiresAt, String name, String email, String avatar) {
            this.accessToken = accessToken; this.refreshToken = refreshToken; this.expiresAt = expiresAt;
            this.name = name; this.email = email; this.avatar = avatar;
        }
    }
}
