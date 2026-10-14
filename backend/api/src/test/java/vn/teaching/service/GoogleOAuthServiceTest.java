package vn.teaching.service;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import java.net.InetSocketAddress;
import java.net.URI;
import java.net.URLDecoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import static org.junit.jupiter.api.Assertions.*;

class GoogleOAuthServiceTest {
    private HttpServer provider;
    private GoogleOAuthService oauth;
    private final HttpClient http = HttpClient.newHttpClient();
    private final AtomicInteger exchanges = new AtomicInteger();
    private final AtomicInteger refreshes = new AtomicInteger();
    private Map<String, String> lastExchange;
    private String grantedScope = "openid email profile " + GoogleOAuthService.MEET_SCOPE;
    private int expiresIn = 3600;
    private boolean failRefresh;

    @BeforeEach
    void setup() throws Exception {
        provider = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        provider.createContext("/token", request -> {
            lastExchange = query(new String(request.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            boolean refresh = "refresh_token".equals(lastExchange.get("grant_type"));
            if (refresh) refreshes.incrementAndGet(); else exchanges.incrementAndGet();
            String body = refresh && failRefresh ? "{\"error\":\"invalid_grant\"}"
                    : "{\"access_token\":\"test-access-" + (refresh ? "refreshed" : "initial") + "\","
                    + "\"refresh_token\":\"test-refresh\",\"token_type\":\"Bearer\",\"expires_in\":"
                    + (refresh ? 3600 : expiresIn) + ",\"scope\":\"" + grantedScope + "\"}";
            request.sendResponseHeaders(refresh && failRefresh ? 400 : 200, body.length());
            try (var output = request.getResponseBody()) { output.write(body.getBytes(StandardCharsets.UTF_8)); }
        });
        provider.createContext("/userinfo", request -> {
            assertEquals("Bearer test-access-initial", request.getRequestHeaders().getFirst("Authorization"));
            byte[] body = "{\"sub\":\"teacher-123\",\"email\":\"teacher@example.com\",\"email_verified\":true,\"name\":\"Cô Hoa\"}".getBytes(StandardCharsets.UTF_8);
            request.sendResponseHeaders(200, body.length);
            try (var output = request.getResponseBody()) { output.write(body); }
        });
        provider.start();
        String base = "http://127.0.0.1:" + provider.getAddress().getPort();
        oauth = new GoogleOAuthService("test-desktop-client", "test-client-secret", http,
                URI.create(base + "/token"), URI.create(base + "/userinfo"));
    }

    @AfterEach
    void close() { oauth.close(); provider.stop(0); }

    @Test
    void exchangesCodeWithPkceAndKeepsTokensOutOfFrontendResponse() throws Exception {
        Map<String, Object> flow = oauth.start("teacher@example.com");
        Map<String, String> auth = query(URI.create((String) flow.get("authorizationUrl")).getRawQuery());
        assertEquals("S256", auth.get("code_challenge_method"));
        assertTrue(auth.get("scope").contains(GoogleOAuthService.MEET_SCOPE));
        assertEquals("PENDING", oauth.status((String) flow.get("flowId")).get("status"));
        assertEquals(200, callback(auth, "state=" + auth.get("state") + "&code=test-code").statusCode());
        String hash = Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256")
                .digest(lastExchange.get("code_verifier").getBytes(StandardCharsets.US_ASCII)));
        assertEquals(auth.get("code_challenge"), hash);
        assertEquals(auth.get("redirect_uri"), lastExchange.get("redirect_uri"));
        assertEquals("test-desktop-client", lastExchange.get("client_id"));
        Map<String, Object> connected = oauth.status((String) flow.get("flowId"));
        assertEquals("CONNECTED", connected.get("status"));
        assertFalse(connected.toString().contains("test-access"));
        assertFalse(connected.toString().contains("test-refresh"));
        assertEquals("Cô Hoa", ((Map<?, ?>) connected.get("user")).get("name"));
        String sessionId = (String) connected.get("sessionId");
        assertEquals("test-access-initial", oauth.accessToken(sessionId));
        oauth.disconnect(sessionId);
        assertThrows(IllegalStateException.class, () -> oauth.accessToken(sessionId));
    }

    @Test
    void wrongStateAndCallbackReplayNeverExchangeAnotherCode() throws Exception {
        Map<String, Object> flow = oauth.start(null);
        Map<String, String> auth = query(URI.create((String) flow.get("authorizationUrl")).getRawQuery());
        assertEquals(400, callback(auth, "state=wrong-state&code=code").statusCode());
        assertEquals(0, exchanges.get());
        assertEquals("PENDING", oauth.status((String) flow.get("flowId")).get("status"));
        assertEquals(200, callback(auth, "state=" + auth.get("state") + "&code=code").statusCode());
        assertEquals(400, callback(auth, "state=" + auth.get("state") + "&code=code").statusCode());
        assertEquals(1, exchanges.get());
    }

    @Test
    void cancellationAndProviderDenialCannotCreateSessions() throws Exception {
        Map<String, Object> cancelled = oauth.start(null);
        Map<String, String> auth = query(URI.create((String) cancelled.get("authorizationUrl")).getRawQuery());
        oauth.cancel((String) cancelled.get("flowId"));
        assertEquals(400, callback(auth, "state=" + auth.get("state") + "&code=code").statusCode());
        assertEquals(0, exchanges.get());
        Map<String, Object> denied = oauth.start(null);
        auth = query(URI.create((String) denied.get("authorizationUrl")).getRawQuery());
        callback(auth, "state=" + auth.get("state") + "&error=access_denied");
        assertEquals("ERROR", oauth.status((String) denied.get("flowId")).get("status"));
        assertEquals(0, exchanges.get());
    }

    @Test
    void missingMeetConsentIsNotReportedAsConnected() throws Exception {
        grantedScope = "openid email profile";
        Map<String, Object> flow = authorize();
        Map<String, Object> result = oauth.status((String) flow.get("flowId"));
        assertEquals("ERROR", result.get("status"));
        assertFalse(result.containsKey("sessionId"));
    }

    @Test
    void expiredAccessTokenRefreshesOnceAndRevokedGrantRequiresReconnect() throws Exception {
        expiresIn = 1;
        Map<String, Object> flow = authorize();
        String sessionId = (String) oauth.status((String) flow.get("flowId")).get("sessionId");
        assertEquals("test-access-refreshed", oauth.accessToken(sessionId));
        assertEquals("test-access-refreshed", oauth.accessToken(sessionId));
        assertEquals(1, refreshes.get());
        failRefresh = true;
        flow = authorize();
        String revokedId = (String) oauth.status((String) flow.get("flowId")).get("sessionId");
        assertThrows(IllegalStateException.class, () -> oauth.accessToken(revokedId));
        assertThrows(IllegalStateException.class, () -> oauth.accessToken(revokedId));
        assertEquals(2, refreshes.get());
    }

    @Test
    void absentConfigurationFailsWithoutStartingAFakeSession() {
        GoogleOAuthService unconfigured = new GoogleOAuthService("", "", http, URI.create("http://localhost/token"), URI.create("http://localhost/profile"));
        try { assertThrows(IllegalStateException.class, () -> unconfigured.start(null)); }
        finally { unconfigured.close(); }
    }

    private Map<String, Object> authorize() throws Exception {
        Map<String, Object> flow = oauth.start(null);
        Map<String, String> auth = query(URI.create((String) flow.get("authorizationUrl")).getRawQuery());
        callback(auth, "state=" + auth.get("state") + "&code=code");
        return flow;
    }

    private HttpResponse<String> callback(Map<String, String> auth, String params) throws Exception {
        return http.send(HttpRequest.newBuilder(URI.create(auth.get("redirect_uri") + "?" + params)).GET().build(), HttpResponse.BodyHandlers.ofString());
    }

    private static Map<String, String> query(String query) {
        Map<String, String> result = new HashMap<>();
        for (String pair : query.split("&")) {
            String[] parts = pair.split("=", 2);
            result.put(URLDecoder.decode(parts[0], StandardCharsets.UTF_8), URLDecoder.decode(parts[1], StandardCharsets.UTF_8));
        }
        return result;
    }
}
