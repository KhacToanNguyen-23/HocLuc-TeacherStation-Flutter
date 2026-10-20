package vn.teaching.modules.auth.controller;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.modules.auth.dto.AuthResponse;
import vn.teaching.modules.auth.dto.LoginRequest;
import vn.teaching.modules.auth.dto.OtpAuthRequest;
import vn.teaching.modules.auth.dto.RegisterRequest;
import vn.teaching.modules.auth.service.AuthService;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> handleLogin(@Valid @RequestBody LoginRequest req) {
        AuthResponse response = authService.login(req.getIdentifier(), req.getPassword());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/dev-login")
    public ResponseEntity<AuthResponse> handleDevLogin() {
        AuthResponse response = authService.devLogin();
        if (!response.isSuccess()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> handleRegister(@Valid @RequestBody RegisterRequest req) {
        AuthResponse response = authService.register(req.getTarget(), req.getOtp(), req.getPassword());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/send")
    public ResponseEntity<AuthResponse> handleSendOtp(@Valid @RequestBody OtpAuthRequest req) {
        AuthResponse response = authService.sendOtp(req.getTarget());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<AuthResponse> handleVerifyOtp(@Valid @RequestBody OtpAuthRequest req) {
        if (req.getOtp() == null || req.getOtp().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Dữ liệu xác thực OTP không đầy đủ."));
        }
        AuthResponse response = authService.verifyOtp(req.getTarget(), req.getOtp(), req.getName(), req.getType());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }
}

