package vn.teaching.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.model.AuthResponse;
import vn.teaching.model.LoginRequest;
import vn.teaching.model.OtpAuthRequest;
import vn.teaching.model.RegisterRequest;
import vn.teaching.service.AuthService;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> handleLogin(@RequestBody LoginRequest req) {
        if (req == null || req.getIdentifier() == null || req.getIdentifier().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email."));
        }
        if (req.getPassword() == null || req.getPassword().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Vui lòng nhập mật khẩu."));
        }
        AuthResponse response = authService.login(req.getIdentifier(), req.getPassword());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> handleRegister(@RequestBody RegisterRequest req) {
        if (req == null || req.getTarget() == null || req.getTarget().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email."));
        }
        if (req.getOtp() == null || req.getOtp().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Vui lòng nhập mã xác thực OTP."));
        }
        if (req.getPassword() == null || req.getPassword().trim().length() < 6) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Mật khẩu phải có ít nhất 6 ký tự."));
        }
        AuthResponse response = authService.register(req.getTarget(), req.getOtp(), req.getPassword());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/send")
    public ResponseEntity<AuthResponse> handleSendOtp(@RequestBody OtpAuthRequest req) {
        if (req == null || req.getTarget() == null || req.getTarget().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email."));
        }
        AuthResponse response = authService.sendOtp(req.getTarget());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }

    @PostMapping("/otp/verify")
    public ResponseEntity<AuthResponse> handleVerifyOtp(@RequestBody OtpAuthRequest req) {
        if (req == null || req.getTarget() == null || req.getOtp() == null) {
            return ResponseEntity.badRequest().body(AuthResponse.error("Dữ liệu xác thực OTP không đầy đủ."));
        }
        AuthResponse response = authService.verifyOtp(req.getTarget(), req.getOtp(), req.getName(), req.getType());
        if (!response.isSuccess()) {
            return ResponseEntity.badRequest().body(response);
        }
        return ResponseEntity.ok(response);
    }
}
