package vn.teaching.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/bootstrap")
public class BootstrapController {
    private final String token;

    public BootstrapController(String companionToken) {
        this.token = companionToken;
    }

    @GetMapping
    public Map<String, Object> bootstrap() {
        return Map.of("token", token, "version", "0.1.0");
    }
}
