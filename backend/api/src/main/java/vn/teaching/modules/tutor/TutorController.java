package vn.teaching.modules.tutor;

import com.fasterxml.jackson.databind.JsonNode;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

/** Existing /api/** companion interceptor remains authoritative; no auth exclusions. */
@RestController
@RequestMapping("/api/tutor")
public class TutorController {
    private final TutorService service;
    public TutorController(TutorService service) { this.service = service; }

    @PostMapping(value = "/answer", consumes = "application/json", produces = "application/json")
    public ResponseEntity<TutorService.Answer> answer(HttpServletRequest request) {
        if (!trusted(request)) return ResponseEntity.status(403).body(TutorService.review("forbidden_origin"));
        try { return ResponseEntity.ok(service.answer(read(request))); }
        catch (Exception e) { return ResponseEntity.badRequest().body(TutorService.review("invalid_request")); }
    }
    @PostMapping(value = "/test", consumes = "application/json", produces = "application/json")
    public ResponseEntity<?> test(HttpServletRequest request) {
        if (!trusted(request)) return ResponseEntity.status(403).body(Map.of("success", false, "reason", "forbidden_origin"));
        try {
            if (service.test(read(request))) return ResponseEntity.ok(Map.of("success", true));
            return ResponseEntity.status(502).body(Map.of("success", false, "reason", "provider_unavailable"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("success", false, "reason", "invalid_request"));
        }
    }
    // Route-local browser protection: native clients omit Origin. Forwarded headers are not trusted.
    private boolean trusted(HttpServletRequest request) {
        String remote = request.getRemoteAddr();
        if (remote == null || !(remote.matches("127\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}")
                || remote.equals("::1") || remote.equals("0:0:0:0:0:0:0:1"))) return false;
        // A rebinding domain can reach loopback and send a matching Origin: validate Host first.
        String serverName = request.getServerName();
        if (!loopbackHost(serverName)) return false;
        if (java.util.Collections.list(request.getHeaders("Origin")).size() > 1) return false;
        String origin = request.getHeader("Origin");
        if (origin == null) return true;
        try {
            var uri = java.net.URI.create(origin);
            int port = uri.getPort() == -1 ? ("https".equals(uri.getScheme()) ? 443 : 80) : uri.getPort();
            return uri.getHost() != null && uri.getRawUserInfo() == null && uri.getRawQuery() == null
                    && uri.getRawFragment() == null && uri.getRawPath().isEmpty()
                    && uri.getScheme().equalsIgnoreCase(request.getScheme())
                    && unbracket(uri.getHost()).equalsIgnoreCase(unbracket(serverName))
                    && port == request.getServerPort();
        } catch (Exception e) { return false; }
    }
    private static boolean loopbackHost(String host) {
        if (host == null) return false;
        if (host.equalsIgnoreCase("localhost")) return true;
        String literal = unbracket(host);
        if (literal.equals("::1") || literal.equals("0:0:0:0:0:0:0:1")) return true;
        if (!host.matches("127\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}")) return false;
        for (String octet : host.split("\\.")) {
            if (Integer.parseInt(octet) > 255) return false;
        }
        return true;
    }
    private static String unbracket(String host) {
        return host.startsWith("[") && host.endsWith("]") ? host.substring(1, host.length() - 1) : host;
    }
    private JsonNode read(HttpServletRequest request) throws Exception {
        TutorService.require(request.getContentLengthLong() <= TutorService.MAX_BODY);
        byte[] bytes = request.getInputStream().readNBytes(TutorService.MAX_BODY + 1);
        TutorService.require(bytes.length <= TutorService.MAX_BODY);
        return TutorService.JSON.readTree(bytes);
    }
}
