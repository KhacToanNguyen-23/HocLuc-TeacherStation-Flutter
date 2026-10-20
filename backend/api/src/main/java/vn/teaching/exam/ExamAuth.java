package vn.teaching.exam;

import jakarta.annotation.PostConstruct;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.util.*;

import static vn.teaching.exam.ExamModels.Account;
import static vn.teaching.exam.ExamRepository.id;
import static vn.teaching.exam.ExamRepository.now;

@Service
public class ExamAuth {
    private final ExamRepository repo;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder(12);
    private final String adminEmail;
    private final String adminPassword;
    private final Set<String> googleAdmins;

    public ExamAuth(
            ExamRepository repo,
            @Value("${exam.admin.email:}") String email,
            @Value("${exam.admin.password:}") String password,
            @Value("${app.auth.admin-emails:}") String adminEmails
    ) {
        this.repo = repo;
        this.adminEmail = email;
        this.adminPassword = password;
        this.googleAdmins = new HashSet<>();
        for (String address : adminEmails.split(",")) {
            if (!address.isBlank()) {
                googleAdmins.add(normalize(address));
            }
        }
    }

    @PostConstruct
    void provisionAdmin() {
        if (!adminEmail.isBlank() && !adminPassword.isBlank()) {
            var existing = repo.jdbc().queryForList(
                    "SELECT id, role, password_hash FROM exam_platform.accounts WHERE email = ?",
                    normalize(adminEmail)
            );
            if (existing.isEmpty()) {
                create(adminEmail, adminPassword, "Quản trị nguồn đề", "ADMIN");
            } else {
                var account = existing.get(0);
                if (!"ADMIN".equals(account.get("role"))) {
                    throw new IllegalStateException("Configured admin email belongs to a teacher; choose a separate admin email.");
                }
                if (adminPassword.length() < 10 || adminPassword.getBytes(StandardCharsets.UTF_8).length > 72) {
                    throw new IllegalStateException("Admin password must be 10–72 bytes.");
                }
                if (!encoder.matches(adminPassword, String.valueOf(account.get("password_hash")))) {
                    repo.jdbc().update(
                            "UPDATE exam_platform.accounts SET password_hash = ? WHERE id = ?",
                            encoder.encode(adminPassword),
                            account.get("id")
                    );
                    repo.jdbc().update(
                            "DELETE FROM exam_platform.auth_sessions WHERE account_id = ?",
                            account.get("id")
                    );
                }
            }
        }
    }

    private String normalize(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    public static String digest(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    @Transactional
    public Map<String, Object> register(String email, String password, String name) {
        if (password == null || password.length() < 10) {
            throw ExamException.bad("Mật khẩu cần ít nhất 10 ký tự.");
        }
        Account account = create(email, password, name, "TEACHER");
        return session(account);
    }

    /**
     * Reuses the existing app's password form and six-character validation.
     */
    @Transactional
    public Map<String, Object> registerApp(String email, String password, String name) {
        return session(create(email, password, name, "TEACHER"));
    }

    private Account create(String email, String password, String name, String role) {
        if (email == null || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+") || email.length() > 254) {
            throw ExamException.bad("Email không hợp lệ.");
        }
        if (password == null || password.length() < 6 || password.getBytes(StandardCharsets.UTF_8).length > 72) {
            throw ExamException.bad("Mật khẩu cần ít nhất 6 ký tự và tối đa 72 byte.");
        }
        if (name == null || name.isBlank() || name.length() > 200) {
            throw ExamException.bad("Tên giáo viên bắt buộc, tối đa 200 ký tự.");
        }
        Integer count = repo.jdbc().queryForObject(
                "SELECT COUNT(*) FROM exam_platform.accounts WHERE email = ?",
                Integer.class,
                normalize(email)
        );
        if (count != null && count > 0) {
            throw ExamException.conflict("Email đã được đăng ký.");
        }

        Account account = new Account(id(), normalize(email), name.trim(), role);
        repo.jdbc().update(
                "INSERT INTO exam_platform.accounts VALUES (?, ?, ?, ?, ?, ?)",
                account.id(),
                account.email(),
                account.name(),
                encoder.encode(password),
                role,
                now()
        );
        return account;
    }

    public Map<String, Object> login(String email, String password) {
        var rows = repo.jdbc().queryForList(
                "SELECT * FROM exam_platform.accounts WHERE email = ?",
                email == null ? "" : normalize(email)
        );
        if (rows.isEmpty() || password == null || !encoder.matches(password, String.valueOf(rows.get(0).get("password_hash")))) {
            throw new ExamException(HttpStatus.UNAUTHORIZED, "LOGIN_FAILED", "Email hoặc mật khẩu không đúng.", List.of());
        }
        var row = rows.get(0);
        return session(new Account((String) row.get("id"), (String) row.get("email"), (String) row.get("name"), (String) row.get("role")));
    }

    @Transactional
    public synchronized Map<String, Object> google(String subject, String email, String name) {
        SourceService.required(subject, "Google subject");
        if (email == null || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) {
            throw ExamException.bad("Google chưa trả về email đã xác minh.");
        }
        String address = normalize(email);
        var linked = repo.jdbc().queryForList(
                "SELECT a.* FROM exam_platform.accounts a JOIN exam_platform.external_identities i ON a.id = i.account_id WHERE i.provider = 'GOOGLE' AND i.subject = ?",
                subject
        );
        Account account;
        if (!linked.isEmpty()) {
            var row = linked.get(0);
            account = new Account((String) row.get("id"), (String) row.get("email"), (String) row.get("name"), (String) row.get("role"));
        } else {
            var existing = repo.jdbc().queryForList(
                    "SELECT * FROM exam_platform.accounts WHERE email = ?",
                    address
            );
            if (existing.isEmpty()) {
                account = create(address, UUID.randomUUID().toString(), name == null || name.isBlank() ? address : name, "TEACHER");
            } else {
                var row = existing.get(0);
                account = new Account((String) row.get("id"), (String) row.get("email"), (String) row.get("name"), (String) row.get("role"));
            }
            repo.jdbc().update(
                    "INSERT INTO exam_platform.external_identities VALUES ('GOOGLE', ?, ?)",
                    subject,
                    account.id()
            );
        }

        // Role grants come only from server configuration and Google's verified identity.
        if (googleAdmins.contains(address) && account.email().equals(address) && !account.role().equals("ADMIN")) {
            repo.jdbc().update("UPDATE exam_platform.accounts SET role = 'ADMIN' WHERE id = ?", account.id());
            account = new Account(account.id(), account.email(), account.name(), "ADMIN");
        }
        return session(account);
    }

    /**
     * Local app profiles never claim an OAuth/password identity or its admin grants.
     */
    @Transactional
    public synchronized Map<String, Object> localWebview(String email, String name) {
        if (email == null || email.length() > 254 || !email.matches("[^\\s@]+@[^\\s@]+\\.[^\\s@]+")) {
            throw ExamException.bad("Email giáo viên không hợp lệ.");
        }
        String address = normalize(email);
        var linked = repo.jdbc().queryForList(
                "SELECT a.* FROM exam_platform.accounts a JOIN exam_platform.external_identities i ON a.id = i.account_id WHERE i.provider = 'APP_WEBVIEW' AND i.subject = ?",
                address
        );
        Account account;
        if (linked.isEmpty()) {
            String localEmail = "webview-" + digest(address.getBytes(StandardCharsets.UTF_8)) + "@app.hocluc.local";
            account = create(localEmail, UUID.randomUUID().toString(), name == null || name.isBlank() ? address : name, "TEACHER");
            repo.jdbc().update(
                    "INSERT INTO exam_platform.external_identities VALUES ('APP_WEBVIEW', ?, ?)",
                    address,
                    account.id()
            );
        } else {
            var row = linked.get(0);
            account = new Account((String) row.get("id"), (String) row.get("email"), (String) row.get("name"), "TEACHER");
            // Local profiles are always teachers, including if a database was edited manually.
            repo.jdbc().update("UPDATE exam_platform.accounts SET role = 'TEACHER' WHERE id = ?", account.id());
        }
        return session(account);
    }

    private Map<String, Object> session(Account account) {
        byte[] random = new byte[32];
        new SecureRandom().nextBytes(random);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(random);
        long expires = System.currentTimeMillis() + 8 * 60 * 60 * 1000;

        repo.jdbc().update("DELETE FROM exam_platform.auth_sessions WHERE expires_at < ?", System.currentTimeMillis());
        repo.jdbc().update(
                "INSERT INTO exam_platform.auth_sessions VALUES (?, ?, ?)",
                digest(token.getBytes(StandardCharsets.UTF_8)),
                account.id(),
                expires
        );
        return Map.of("token", token, "user", account, "expiresAt", expires);
    }

    public Account authenticate(String header) {
        if (header == null || !header.startsWith("Bearer ")) {
            throw unauthorized();
        }
        var rows = repo.jdbc().queryForList(
                "SELECT a.* FROM exam_platform.accounts a JOIN exam_platform.auth_sessions s ON a.id = s.account_id WHERE s.token_hash = ? AND s.expires_at > ?",
                digest(header.substring(7).getBytes(StandardCharsets.UTF_8)),
                System.currentTimeMillis()
        );
        if (rows.isEmpty()) {
            throw unauthorized();
        }
        var row = rows.get(0);
        return new Account((String) row.get("id"), (String) row.get("email"), (String) row.get("name"), (String) row.get("role"));
    }

    private ExamException unauthorized() {
        return new ExamException(HttpStatus.UNAUTHORIZED, "SESSION_REQUIRED", "Vui lòng đăng nhập tài khoản giáo viên.", List.of());
    }

    public Account current(HttpServletRequest request) {
        return (Account) request.getAttribute("examAccount");
    }

    public void logout(String header) {
        repo.jdbc().update(
                "DELETE FROM exam_platform.auth_sessions WHERE token_hash = ?",
                digest(header.substring(7).getBytes(StandardCharsets.UTF_8))
        );
    }
}
