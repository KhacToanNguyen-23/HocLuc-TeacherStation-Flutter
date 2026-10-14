package vn.teaching.exam;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;

/** Compatibility with develop's app-owned WebView profile; not Google OAuth proof. */
@RestController
@RequestMapping("/api/auth/google/webview-session")
public class LocalWebviewSessionController {
    private final ExamAuth auth;
    private final String companionToken, serverAddress;
    private final boolean enabled;

    public LocalWebviewSessionController(ExamAuth auth, String companionToken,
            @Value("${server.address:}") String serverAddress,
            @Value("${app.auth.webview-local.enabled:true}") boolean enabled) {
        this.auth = auth;
        this.companionToken = companionToken;
        this.serverAddress = serverAddress;
        this.enabled = enabled;
    }

    @PostMapping
    public ResponseEntity<?> session(HttpServletRequest request, @RequestBody Map<String,String> input) {
        String proof = request.getHeader("X-Companion-Token");
        if (!enabled || !loopback(serverAddress) || !loopback(request.getLocalAddr())
                || !loopback(request.getRemoteAddr()) || !loopback(request.getServerName())
                || !localOrigin(request.getHeader("Origin"))
                || ("cross-site".equals(request.getHeader("Sec-Fetch-Site")) && request.getHeader("Origin") == null)
                || proof == null || !MessageDigest.isEqual(companionToken.getBytes(StandardCharsets.UTF_8), proof.getBytes(StandardCharsets.UTF_8))) {
            throw new ExamException(HttpStatus.FORBIDDEN, "LOCAL_APP_REQUIRED",
                    "Phiên WebView chỉ dùng được với app và backend trên máy này.", List.of());
        }
        return ResponseEntity.ok().cacheControl(CacheControl.noStore())
                .body(auth.localWebview(input.get("email"), input.get("name")));
    }

    private boolean localOrigin(String origin) {
        if (origin == null) return true; // Native desktop requests have no Origin.
        try {
            URI uri = URI.create(origin);
            return ("http".equals(uri.getScheme()) || "https".equals(uri.getScheme()))
                    && uri.getRawUserInfo() == null && loopback(uri.getHost());
        } catch (IllegalArgumentException e) { return false; }
    }

    private boolean loopback(String host) {
        return "127.0.0.1".equals(host) || "localhost".equalsIgnoreCase(host)
                || "::1".equals(host) || "[::1]".equals(host)
                || "0:0:0:0:0:0:0:1".equals(host);
    }
}
