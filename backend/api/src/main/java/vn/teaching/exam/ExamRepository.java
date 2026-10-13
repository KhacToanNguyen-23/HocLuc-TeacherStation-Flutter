package vn.teaching.exam;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.util.*;

@Repository
public class ExamRepository {
    private static final Set<String> TABLES = Set.of("pdf_sources", "processing_jobs", "question_assets", "question_groups", "questions", "question_reviews", "matrix_versions", "papers", "export_records", "classes", "students", "exam_sessions", "student_results", "import_jobs");
    private final JdbcTemplate jdbc;
    private final ObjectMapper mapper;
    public ExamRepository(JdbcTemplate jdbc, ObjectMapper mapper) { this.jdbc=jdbc; this.mapper=mapper; }
    public JdbcTemplate jdbc() { return jdbc; }
    private String table(String table) {
        if (!TABLES.contains(table)) throw new IllegalArgumentException("Unknown table");
        return "exam_platform." + table;
    }
    public String json(Object value) {
        try { return mapper.writeValueAsString(value); } catch (JsonProcessingException e) { throw new IllegalStateException(e); }
    }
    public <T> T parse(String json, Class<T> type) {
        try { return mapper.readValue(json, type); } catch (JsonProcessingException e) { throw new IllegalStateException("Stored document invalid", e); }
    }
    public <T> Optional<T> find(String table, String id, Class<T> type) {
        return jdbc.query("SELECT data FROM " + table(table) + " WHERE id=?", (rs,n)->parse(rs.getString(1),type),id).stream().findFirst();
    }
    public <T> T require(String table, String id, Class<T> type) { return find(table,id,type).orElseThrow(ExamException::missing); }
    public <T> List<T> all(String table, Class<T> type) {
        return jdbc.query("SELECT data FROM " + table(table) + " ORDER BY id",(rs,n)->parse(rs.getString(1),type));
    }
    public <T> List<T> owned(String table, String owner, Class<T> type) {
        return jdbc.query("SELECT data FROM " + table(table) + " WHERE teacher_id=? ORDER BY id",(rs,n)->parse(rs.getString(1),type),owner);
    }
    public void insert(String table, String id, Object value, Map<String,Object> columns) {
        LinkedHashMap<String,Object> row = new LinkedHashMap<>(); row.put("id",id); row.putAll(columns); row.put("data",json(value));
        if (row.keySet().stream().anyMatch(k->!k.matches("[a-z_]+"))) throw new IllegalArgumentException();
        jdbc.update("INSERT INTO " + table(table) + " (" + String.join(",",row.keySet()) + ") VALUES (" + String.join(",",Collections.nCopies(row.size(),"?")) + ")",row.values().toArray());
    }
    public void update(String table, String id, Object value) {
        if(jdbc.update("UPDATE " + table(table) + " SET data=? WHERE id=?",json(value),id)!=1) throw ExamException.missing();
    }
    public static String id() { return UUID.randomUUID().toString(); }
    public static String now() { return java.time.Instant.now().toString(); }
}
