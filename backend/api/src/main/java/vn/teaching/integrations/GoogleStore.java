package vn.teaching.integrations;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.security.SecureRandom;
import java.util.*;

@Repository
public class GoogleStore {
    private final JdbcTemplate jdbc;
    private final ObjectMapper json;
    private final byte[] key;
    public GoogleStore(JdbcTemplate jdbc, ObjectMapper json, @Value("${app.integrations.google.encryption-key:}") String encoded) {
        this.jdbc = jdbc; this.json = json;
        byte[] decoded;
        try { decoded = Base64.getDecoder().decode(encoded); } catch (IllegalArgumentException e) { decoded = new byte[0]; }
        key = decoded.length == 32 ? decoded : new byte[0];
    }
    public boolean configured() { return key.length == 32; }
    public void saveConnection(String subject, String email, Map<String, Object> credentials) {
        String sealed = seal(write(credentials));
        if (jdbc.update("UPDATE exam_platform.google_connections SET email=?, credentials=? WHERE subject=?", email, sealed, subject) == 0)
            jdbc.update("INSERT INTO exam_platform.google_connections(subject,email,credentials) VALUES(?,?,?)", subject, email, sealed);
    }
    public Map<String, Object> credentials(String subject) {
        var found = jdbc.query("SELECT credentials FROM exam_platform.google_connections WHERE subject=?", (r,n) -> r.getString(1), subject);
        if (found.isEmpty()) throw new GoogleFailure(401, "CONNECT_GOOGLE", "Vui lòng kết nối Google.");
        return read(open(found.get(0)));
    }
    public Optional<String> subject(String email) {
        return jdbc.query("SELECT subject FROM exam_platform.google_connections WHERE email=?", (r,n) -> r.getString(1), email).stream().findFirst();
    }
    public void disconnect(String subject) { jdbc.update("DELETE FROM exam_platform.google_connections WHERE subject=?", subject); }
    public List<Map<String, Object>> courses(String subject) {
        return jdbc.query("SELECT data FROM exam_platform.google_courses WHERE subject=? ORDER BY id", (r,n) -> read(r.getString(1)), subject);
    }
    public Map<String, Object> course(String subject, String id) {
        return jdbc.query("SELECT data FROM exam_platform.google_courses WHERE subject=? AND id=?", (r,n) -> read(r.getString(1)), subject, id)
            .stream().findFirst().orElseThrow(() -> new GoogleFailure(404, "COURSE_NOT_FOUND", "Không tìm thấy lớp của tài khoản này."));
    }
    public void saveCourse(String subject, Map<String, Object> course) {
        String id = course.get("id").toString(), data = write(course);
        if (jdbc.update("UPDATE exam_platform.google_courses SET data=? WHERE id=? AND subject=?", data, id, subject) == 0)
            jdbc.update("INSERT INTO exam_platform.google_courses(id,subject,data) VALUES(?,?,?)", id, subject, data);
    }
    public void deleteCourse(String subject, String id) {
        if (jdbc.update("DELETE FROM exam_platform.google_courses WHERE subject=? AND id=?", subject, id) == 0)
            throw new GoogleFailure(404, "COURSE_NOT_FOUND", "Không tìm thấy lớp của tài khoản này.");
    }
    String write(Object value) { try { return json.writeValueAsString(value); } catch (Exception e) { throw new IllegalStateException("Cannot save Google connection", e); } }
    @SuppressWarnings("unchecked") Map<String, Object> read(String value) {
        try { return json.readValue(value, LinkedHashMap.class); } catch (Exception e) { throw new IllegalStateException("Invalid Google connection data", e); }
    }
    private String seal(String value) {
        requireKey();
        try {
            byte[] nonce = new byte[12]; new SecureRandom().nextBytes(nonce);
            Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.ENCRYPT_MODE, new SecretKeySpec(key,"AES"), new GCMParameterSpec(128,nonce));
            return Base64.getEncoder().encodeToString(nonce) + "." + Base64.getEncoder().encodeToString(cipher.doFinal(value.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (Exception e) { throw new IllegalStateException("Cannot protect Google credentials", e); }
    }
    private String open(String value) {
        requireKey();
        try {
            String[] parts = value.split("\\."); Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
            cipher.init(Cipher.DECRYPT_MODE,new SecretKeySpec(key,"AES"),new GCMParameterSpec(128,Base64.getDecoder().decode(parts[0])));
            return new String(cipher.doFinal(Base64.getDecoder().decode(parts[1])),java.nio.charset.StandardCharsets.UTF_8);
        } catch (Exception e) { throw new GoogleFailure(503,"GOOGLE_KEY_CHANGED","Không đọc được kết nối Google. Kiểm tra khóa lưu trữ của ứng dụng."); }
    }
    private void requireKey() { if (!configured()) throw new GoogleFailure(503,"GOOGLE_NOT_CONFIGURED","Ứng dụng chưa được cấu hình kết nối Google. Liên hệ người cài đặt HocLuc."); }
}
