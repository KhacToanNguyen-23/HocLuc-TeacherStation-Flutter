package vn.teaching.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.stereotype.Service;
import vn.teaching.model.AuthResponse;

import java.security.SecureRandom;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AuthService {
    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom random = new SecureRandom();

    private static class OtpEntry {
        final String otp;
        final long createdAt;
        final long expiresAt;

        OtpEntry(String otp, long ttlMillis) {
            this.otp = otp;
            this.createdAt = System.currentTimeMillis();
            this.expiresAt = this.createdAt + ttlMillis;
        }

        boolean isExpired() {
            return System.currentTimeMillis() > expiresAt;
        }

        boolean canResend() {
            return System.currentTimeMillis() - createdAt >= 60000; // 60s cooldown
        }
    }

    private final Map<String, OtpEntry> otpStorage = new ConcurrentHashMap<>();
    private final Map<String, Map<String, Object>> userStorage = new ConcurrentHashMap<>();

    public AuthResponse sendOtp(String target) {
        if (target == null || target.trim().isEmpty()) {
            return AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email.");
        }
        String cleanTarget = target.trim().toLowerCase();

        OtpEntry existing = otpStorage.get(cleanTarget);
        if (existing != null && !existing.isExpired() && !existing.canResend()) {
            long remainingSec = 60 - ((System.currentTimeMillis() - existing.createdAt) / 1000);
            return AuthResponse.error("Vui lòng đợi " + Math.max(1, remainingSec) + " giây trước khi gửi lại mã OTP.");
        }

        // Generate 6-digit OTP
        String generatedOtp = String.valueOf(100000 + random.nextInt(900000));
        otpStorage.put(cleanTarget, new OtpEntry(generatedOtp, 5 * 60 * 1000)); // 5 mins TTL

        log.info("[AuthService] Generated OTP for {}: {} (Dev mock: 123456)", cleanTarget, generatedOtp);

        return new AuthResponse(
                true,
                "Mã OTP đã được gửi thành công đến " + target + " (Mã thử nghiệm Dev: 123456 hoặc " + generatedOtp + ")",
                null,
                Map.of("target", cleanTarget, "devOtp", generatedOtp)
        );
    }

    public AuthResponse verifyOtp(String target, String otp, String name, String type) {
        if (target == null || target.trim().isEmpty()) {
            return AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email.");
        }
        if (otp == null || otp.trim().isEmpty()) {
            return AuthResponse.error("Vui lòng nhập mã OTP 6 chữ số.");
        }

        String cleanTarget = target.trim().toLowerCase();
        String cleanOtp = otp.trim();

        // Check if OTP matches stored entry OR is dev bypass "123456"
        boolean isValid = false;
        if ("123456".equals(cleanOtp)) {
            isValid = true;
        } else {
            OtpEntry entry = otpStorage.get(cleanTarget);
            if (entry != null && !entry.isExpired() && entry.otp.equals(cleanOtp)) {
                isValid = true;
                otpStorage.remove(cleanTarget); // Consumed
            }
        }

        if (!isValid) {
            return AuthResponse.error("Mã OTP không chính xác hoặc đã hết hạn. Vui lòng thử lại.");
        }

        // Generate user session token
        String userToken = UUID.randomUUID().toString();
        String displayName = (name != null && !name.trim().isEmpty())
                ? name.trim()
                : (cleanTarget.contains("@") ? cleanTarget.split("@")[0] : "Thầy/Cô (" + cleanTarget + ")");

        Map<String, Object> userData = new HashMap<>();
        userData.put("id", UUID.randomUUID().toString());
        userData.put("name", displayName);
        if (cleanTarget.contains("@")) {
            userData.put("email", cleanTarget);
            userData.put("phone", "");
        } else {
            userData.put("phone", cleanTarget);
            userData.put("email", cleanTarget + "@hocluc.edu.vn");
        }
        userData.put("role", "teacher");
        userData.put("loginType", type != null ? type : "otp");

        userStorage.put(userToken, userData);

        log.info("[AuthService] Verified user {} successfully. Token granted.", cleanTarget);

        return new AuthResponse(
                true,
                "Đăng nhập thành công! Chào mừng " + displayName,
                userToken,
                userData
        );
    }

    private final vn.teaching.exam.ExamAuth sharedAuth;
    private final boolean devLoginEnabled;
    private final String devLoginEmail;
    private final String devLoginPassword;
    private final Environment environment;

    public AuthService(vn.teaching.exam.ExamAuth sharedAuth,
                       Environment environment,
                       @Value("${app.auth.dev-login.enabled:false}") boolean devLoginEnabled,
                       @Value("${exam.admin.email:}") String devLoginEmail,
                       @Value("${exam.admin.password:}") String devLoginPassword) {
        this.sharedAuth=sharedAuth;
        this.environment=environment;
        this.devLoginEnabled=devLoginEnabled;
        this.devLoginEmail=devLoginEmail;
        this.devLoginPassword=devLoginPassword;
    }

    public AuthResponse devLogin() {
        if (!environment.acceptsProfiles(Profiles.of("dev & !prod")) || !devLoginEnabled || devLoginEmail.isBlank()) {
            return AuthResponse.error("Đăng nhập dev chưa được bật ở môi trường này.");
        }
        try { return sharedResponse(sharedAuth.login(devLoginEmail, devLoginPassword), devLoginEmail); }
        catch (vn.teaching.exam.ExamException e) { return AuthResponse.error(e.getMessage()); }
    }

    private String accountEmail(String target) {
        String clean=target.trim().toLowerCase(java.util.Locale.ROOT);
        return clean.contains("@")?clean:clean+"@hocluc.edu.vn";
    }
    private AuthResponse sharedResponse(Map<String,Object> session,String target) {
        var account=(vn.teaching.exam.ExamModels.Account)session.get("user");
        Map<String,Object> user=new HashMap<>();
        user.put("id",account.id()); user.put("name",account.name()); user.put("role",account.role());
        user.put("email",target.contains("@")?account.email():""); user.put("phone",target.contains("@")?"":target.trim());
        return new AuthResponse(true,"Đăng nhập thành công",(String)session.get("token"),user);
    }

    public AuthResponse login(String identifier, String password) {
        if(identifier==null||identifier.isBlank()) return AuthResponse.error("Vui lòng cung cấp Email hoặc Số điện thoại.");
        try { return sharedResponse(sharedAuth.login(accountEmail(identifier),password),identifier); }
        catch(vn.teaching.exam.ExamException e) { return AuthResponse.error(e.getMessage()); }
    }

    public AuthResponse register(String target, String otp, String password) {
        if (target == null || target.trim().isEmpty()) {
            return AuthResponse.error("Vui lòng cung cấp Số điện thoại hoặc Email.");
        }
        if (otp == null || otp.trim().isEmpty()) {
            return AuthResponse.error("Vui lòng nhập mã xác thực OTP.");
        }
        if (password == null || password.trim().length() < 6) {
            return AuthResponse.error("Mật khẩu phải có ít nhất 6 ký tự.");
        }

        String cleanTarget = target.trim().toLowerCase();
        String cleanOtp = otp.trim();

        // Verify OTP
        boolean isValid = false;
        if ("123456".equals(cleanOtp)) {
            isValid = true;
        } else {
            OtpEntry entry = otpStorage.get(cleanTarget);
            if (entry != null && !entry.isExpired() && entry.otp.equals(cleanOtp)) {
                isValid = true;
                otpStorage.remove(cleanTarget);
            }
        }

        if (!isValid) {
            return AuthResponse.error("Mã xác thực OTP không chính xác hoặc đã hết hạn.");
        }

        String displayName=cleanTarget.contains("@")?cleanTarget.split("@")[0]:"Thầy/Cô ("+cleanTarget+")";
        try { return sharedResponse(sharedAuth.registerApp(accountEmail(cleanTarget),password,displayName),cleanTarget); }
        catch(vn.teaching.exam.ExamException e) { return AuthResponse.error(e.getMessage()); }
    }
}
