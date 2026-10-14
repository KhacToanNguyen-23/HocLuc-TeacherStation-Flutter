package vn.teaching.controller;

import org.springframework.web.bind.annotation.*;
import vn.teaching.service.GoogleOAuthService;
import java.util.Map;

/** Protected by the companion token, unlike the legacy local login endpoints. */
@RestController
@RequestMapping("/api/google/oauth")
public class GoogleOAuthController {
    private final GoogleOAuthService googleOAuthService;
    public GoogleOAuthController(GoogleOAuthService googleOAuthService) { this.googleOAuthService = googleOAuthService; }

    @PostMapping("/start")
    public Map<String, Object> start(@RequestBody Map<String, String> body) {
        try { return googleOAuthService.start(body.get("loginHint")); }
        catch (IllegalStateException e) { return Map.of("success", false, "error", e.getMessage()); }
    }

    @PostMapping("/status")
    public Map<String, Object> status(@RequestBody Map<String, String> body) {
        return googleOAuthService.status(body.get("flowId"));
    }

    @PostMapping("/cancel")
    public Map<String, Object> cancel(@RequestBody Map<String, String> body) {
        googleOAuthService.cancel(body.get("flowId"));
        return Map.of("success", true);
    }

    @PostMapping("/disconnect")
    public Map<String, Object> disconnect(@RequestBody Map<String, String> body) {
        googleOAuthService.disconnect(body.get("sessionId"));
        return Map.of("success", true);
    }
}
