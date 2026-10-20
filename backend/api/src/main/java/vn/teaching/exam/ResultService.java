package vn.teaching.exam;

import org.apache.commons.csv.*;
import org.apache.poi.ss.usermodel.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.*;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;

import static vn.teaching.exam.ExamModels.*;
import static vn.teaching.exam.ExamRepository.id;
import static vn.teaching.exam.ExamRepository.now;

@Service
public class ResultService {
    public record ResultInput(String studentId, Map<String, String> answers, Double score, Integer correctCount) {}

    private final ExamRepository repo;
    private final PaperService papers;

    public ResultService(ExamRepository repo, PaperService papers) {
        this.repo = repo;
        this.papers = papers;
    }

    public SchoolClass ownedClass(String id, String teacher) {
        SchoolClass c = repo.require("classes", id, SchoolClass.class);
        if (!c.teacherId().equals(teacher)) {
            throw ExamException.missing();
        }
        return c;
    }

    public Student ownedStudent(String id, String teacher) {
        Student s = repo.require("students", id, Student.class);
        if (!s.teacherId().equals(teacher)) {
            throw ExamException.missing();
        }
        return s;
    }

    public Session ownedSession(String id, String teacher) {
        Session s = repo.require("exam_sessions", id, Session.class);
        if (!s.teacherId().equals(teacher)) {
            throw ExamException.missing();
        }
        return s;
    }

    @Transactional
    public SchoolClass createClass(String teacher, String name) {
        SourceService.required(name, "Tên lớp");
        SchoolClass c = new SchoolClass(id(), teacher, name.trim(), now());
        repo.insert("classes", c.id(), c, Map.of("teacher_id", teacher));
        return c;
    }

    @Transactional
    public Student createStudent(String teacher, String code, String name, String notes, String classId) {
        SourceService.required(code, "Mã học sinh");
        SourceService.required(name, "Họ tên");
        if (code.length() > 100) {
            throw ExamException.bad("Mã học sinh tối đa 100 ký tự.");
        }
        String timestamp = now();
        Student s = new Student(id(), teacher, code.trim(), name.trim(), notes == null ? "" : notes, timestamp, timestamp);
        repo.insert("students", s.id(), s, Map.of("teacher_id", teacher, "student_code", s.code()));
        if (classId != null && !classId.isBlank()) {
            member(classId, s.id(), teacher);
        }
        return s;
    }

    @Transactional
    public Student editStudent(String id, String teacher, String name, String notes) {
        Student old = ownedStudent(id, teacher);
        SourceService.required(name, "Họ tên");
        Student s = new Student(old.id(), teacher, old.code(), name, notes == null ? "" : notes, old.createdAt(), now());
        repo.update("students", id, s);
        return s;
    }

    @Transactional
    public void member(String classId, String studentId, String teacher) {
        ownedClass(classId, teacher);
        ownedStudent(studentId, teacher);
        Integer count = repo.jdbc().queryForObject(
                "SELECT COUNT(*) FROM exam_platform.class_memberships WHERE class_id = ? AND student_id = ?",
                Integer.class,
                classId,
                studentId
        );
        if (count != null && count == 0) {
            repo.jdbc().update("INSERT INTO exam_platform.class_memberships VALUES (?, ?)", classId, studentId);
        }
    }

    @Transactional
    public void transfer(String fromClass, String toClass, String studentId, String teacher) {
        ownedClass(fromClass, teacher);
        member(toClass, studentId, teacher);
        repo.jdbc().update(
                "DELETE FROM exam_platform.class_memberships WHERE class_id = ? AND student_id = ?",
                fromClass,
                studentId
        );
    }

    public List<Student> roster(String classId, String teacher) {
        ownedClass(classId, teacher);
        return repo.jdbc().query(
                "SELECT s.data FROM exam_platform.students s " +
                        "JOIN exam_platform.class_memberships m ON s.id = m.student_id " +
                        "WHERE m.class_id = ? AND s.teacher_id = ? ORDER BY s.student_code",
                (rs, n) -> repo.parse(rs.getString(1), Student.class),
                classId,
                teacher
        );
    }

    @Transactional
    public Session createSession(String teacher, String classId, String paperId, String title, String assessedAt) {
        ownedClass(classId, teacher);
        Paper p = papers.owned(paperId, teacher);
        if (!"PUBLISHED".equals(p.status())) {
            throw ExamException.bad("Chọn đề đã xuất bản.");
        }
        SourceService.required(title, "Tên lần kiểm tra");
        String timestamp = assessedAt == null || assessedAt.isBlank() ? now() : assessedAt;
        try {
            Instant.parse(timestamp);
        } catch (Exception e) {
            throw ExamException.bad("Ngày kiểm tra phải là thời gian ISO 8601.");
        }
        Session s = new Session(id(), teacher, classId, paperId, title, timestamp);
        repo.insert("exam_sessions", s.id(), s, Map.of(
                "teacher_id", teacher,
                "class_id", classId,
                "paper_id", paperId
        ));
        return s;
    }

    public static String normalizeAnswer(String value) {
        String text = value == null ? "" : value.strip().toLowerCase(Locale.ROOT).replaceAll("\\s+", " ");
        try {
            return new BigDecimal(text.replace(',', '.')).stripTrailingZeros().toPlainString();
        } catch (NumberFormatException e) {
            return text;
        }
    }

    public static boolean correct(Question q, String value) {
        if (value == null || value.isBlank()) {
            return false;
        }
        String answer = normalizeAnswer(value);
        return answer.equals(normalizeAnswer(q.answer()))
                || q.acceptedAnswers().stream().anyMatch(a -> answer.equals(normalizeAnswer(a)));
    }

    public Result validateResult(String teacher, Session session, ResultInput input) {
        ownedStudent(input.studentId(), teacher);
        Paper paper = papers.owned(session.paperId(), teacher);

        if (roster(session.classId(), teacher).stream().noneMatch(s -> s.id().equals(input.studentId()))) {
            throw ExamException.bad("Học sinh không có trong lớp của lần kiểm tra.");
        }
        if (repo.owned("student_results", teacher, Result.class).stream()
                .anyMatch(r -> r.sessionId().equals(session.id()) && r.studentId().equals(input.studentId()))) {
            throw ExamException.conflict("Học sinh đã có kết quả cho lần kiểm tra này.");
        }

        int total = paper.questions().size();
        Map<String, String> answers = input.answers();
        Integer count;
        double score;
        String level;

        if (answers != null) {
            if (input.score() != null || input.correctCount() != null) {
                throw ExamException.bad("Khi có đáp án chi tiết, hệ thống tự chấm điểm.");
            }
            if (answers.size() != total) {
                throw ExamException.bad("Cần đủ cột đáp án từng câu; ô trống biểu thị không trả lời.");
            }
            count = 0;
            for (int i = 1; i <= total; i++) {
                if (!answers.containsKey(String.valueOf(i)) || answers.get(String.valueOf(i)) == null) {
                    throw ExamException.bad("Thiếu câu " + i + ".");
                }
                String value = answers.get(String.valueOf(i));
                Question q = paper.questions().get(i - 1);
                if (value.length() > 200 || ("MCQ".equals(q.type()) && !value.isBlank() && !value.matches("[ABCDabcd]"))) {
                    throw ExamException.bad("Đáp án câu " + i + " không hợp lệ.");
                }
                if (correct(q, value)) {
                    count++;
                }
            }
            score = count * paper.matrix().pointsPerCorrect();
            level = "DETAILED";
            answers = Map.copyOf(answers);
        } else {
            count = input.correctCount();
            if (count != null && (count < 0 || count > total)) {
                throw ExamException.bad("Số câu đúng ngoài phạm vi đề.");
            }
            if (input.score() == null && count == null) {
                throw ExamException.bad("Nhập điểm tổng hoặc số câu đúng.");
            }
            score = input.score() == null ? count * paper.matrix().pointsPerCorrect() : input.score();
            if (!Double.isFinite(score) || score < 0 || score > total * paper.matrix().pointsPerCorrect()) {
                throw ExamException.bad("Điểm luyện tập ngoài phạm vi ma trận.");
            }
            if (count != null && Math.abs(score - count * paper.matrix().pointsPerCorrect()) > 0.000001) {
                throw ExamException.bad("Điểm và số câu đúng mâu thuẫn với chính sách chấm.");
            }
            level = "AGGREGATE";
            answers = Map.of();
        }

        return new Result(id(), teacher, session.id(), input.studentId(), level, score, count, total, answers, now());
    }

    @Transactional
    public Result record(String teacher, String sessionId, ResultInput input) {
        Session session = ownedSession(sessionId, teacher);
        Result r = validateResult(teacher, session, input);
        saveResult(r, session);
        return r;
    }

    private void saveResult(Result r, Session session) {
        repo.insert("student_results", r.id(), r, Map.of(
                "teacher_id", r.teacherId(),
                "session_id", r.sessionId(),
                "student_id", r.studentId(),
                "evidence_level", r.level()
        ));
        if ("DETAILED".equals(r.level())) {
            Paper p = papers.owned(session.paperId(), r.teacherId());
            for (int i = 1; i <= p.questions().size(); i++) {
                Question q = p.questions().get(i - 1);
                String answer = r.answers().get(String.valueOf(i));
                repo.jdbc().update(
                        "INSERT INTO exam_platform.answer_records VALUES (?, ?, ?, ?, ?)",
                        r.id(),
                        i,
                        q.id(),
                        answer,
                        correct(q, answer)
                );
            }
        }
    }

    public List<Map<String, String>> readSheet(MultipartFile file) throws IOException {
        if (file.isEmpty() || file.getSize() > 10 * 1024 * 1024) {
            throw ExamException.bad("Bảng dữ liệu cần 1 byte–10 MB.");
        }
        String filename = file.getOriginalFilename() == null ? "" : file.getOriginalFilename().toLowerCase(Locale.ROOT);
        List<Map<String, String>> rows = new ArrayList<>();

        if (filename.endsWith(".csv")) {
            String text = new String(file.getBytes(), StandardCharsets.UTF_8).replaceFirst("^\\uFEFF", "");
            try (CSVParser parser = CSVFormat.DEFAULT.builder()
                    .setHeader()
                    .setSkipHeaderRecord(true)
                    .setDuplicateHeaderMode(DuplicateHeaderMode.DISALLOW)
                    .setAllowMissingColumnNames(false)
                    .get()
                    .parse(new StringReader(text))) {
                for (CSVRecord record : parser) {
                    if (!record.isConsistent()) {
                        throw ExamException.bad("Số cột CSV không đồng nhất.");
                    }
                    rows.add(new LinkedHashMap<>(record.toMap()));
                    if (rows.size() > 5000) {
                        throw ExamException.bad("Tối đa 5000 dòng mỗi lần import.");
                    }
                }
            } catch (IllegalArgumentException | UncheckedIOException e) {
                throw ExamException.bad("CSV có tiêu đề trùng/rỗng hoặc định dạng không hợp lệ.");
            } catch (IOException e) {
                throw ExamException.bad("Không đọc được CSV.");
            }
        } else if (filename.endsWith(".xlsx")) {
            try (Workbook book = WorkbookFactory.create(file.getInputStream())) {
                Sheet sheet = book.getSheetAt(0);
                Row header = sheet.getRow(0);
                if (header == null || header.getLastCellNum() > 350) {
                    throw ExamException.bad("Tiêu đề bảng không hợp lệ.");
                }
                DataFormatter formatter = new DataFormatter(Locale.ROOT);
                List<String> headers = new ArrayList<>();
                for (int i = 0; i < header.getLastCellNum(); i++) {
                    String key = formatter.formatCellValue(header.getCell(i)).trim();
                    if (key.isBlank() || headers.contains(key)) {
                        throw ExamException.bad("Tiêu đề XLSX rỗng hoặc trùng.");
                    }
                    headers.add(key);
                }
                if (sheet.getLastRowNum() > 5000) {
                    throw ExamException.bad("Tối đa 5000 dòng.");
                }
                for (int i = 1; i <= sheet.getLastRowNum(); i++) {
                    Row row = sheet.getRow(i);
                    if (row == null) continue;
                    Map<String, String> data = new LinkedHashMap<>();
                    for (int j = 0; j < headers.size(); j++) {
                        Cell cell = row.getCell(j);
                        if (cell != null && cell.getCellType() == CellType.FORMULA) {
                            throw ExamException.bad("Hãy chuyển công thức Excel thành giá trị trước khi import.");
                        }
                        data.put(headers.get(j), formatter.formatCellValue(cell));
                    }
                    if (data.values().stream().anyMatch(v -> !v.isBlank())) {
                        rows.add(data);
                    }
                }
            } catch (IOException e) {
                throw ExamException.bad("Không đọc được XLSX.");
            }
        } else {
            throw ExamException.bad("Chỉ nhận CSV UTF-8 hoặc XLSX.");
        }

        if (rows.isEmpty()) {
            throw ExamException.bad("Không có dòng dữ liệu.");
        }
        return rows;
    }

    private ResultInput inputFromRow(String teacher, Session session, Map<String, String> row) {
        if (!session.paperId().equals(row.get("exam_id"))) {
            throw ExamException.bad("Mã đề không khớp lần kiểm tra.");
        }
        Student student = repo.owned("students", teacher, Student.class).stream()
                .filter(s -> s.code().equals(row.getOrDefault("student_code", "").trim()))
                .findFirst()
                .orElseThrow(() -> ExamException.bad("Không tìm thấy mã học sinh."));

        Paper p = papers.owned(session.paperId(), teacher);
        boolean detailed = row.keySet().stream().anyMatch(k -> k.startsWith("question_"));
        if (detailed) {
            Map<String, String> answers = new LinkedHashMap<>();
            for (int i = 1; i <= p.questions().size(); i++) {
                String key = "question_" + i;
                if (!row.containsKey(key)) {
                    throw ExamException.bad("Thiếu cột " + key);
                }
                answers.put(String.valueOf(i), row.get(key).strip());
            }
            if (row.keySet().stream().filter(k -> k.startsWith("question_")).count() != p.questions().size()) {
                throw ExamException.bad("Có cột câu hỏi ngoài mã đề.");
            }
            return new ResultInput(student.id(), answers, null, null);
        }
        try {
            String score = row.getOrDefault("score", "").trim();
            String count = row.getOrDefault("correct_count", "").trim();
            return new ResultInput(
                    student.id(),
                    null,
                    score.isBlank() ? null : Double.valueOf(score),
                    count.isBlank() ? null : Integer.valueOf(count)
            );
        } catch (NumberFormatException e) {
            throw ExamException.bad("Điểm/số câu đúng không phải số hợp lệ.");
        }
    }

    private List<String> validateRows(String teacher, String sessionId, String classId, String kind, List<Map<String, String>> rows) {
        List<String> errors = new ArrayList<>();
        Set<String> codes = new HashSet<>();
        Session session = sessionId == null ? null : ownedSession(sessionId, teacher);
        if (classId != null) {
            ownedClass(classId, teacher);
        }

        for (int i = 0; i < rows.size(); i++) {
            try {
                var row = rows.get(i);
                String code = row.getOrDefault("student_code", "").trim();
                SourceService.required(code, "student_code");
                if (!codes.add(code)) {
                    throw ExamException.bad("Mã học sinh trùng trong file.");
                }
                if ("ROSTER".equals(kind)) {
                    if (code.length() > 100) {
                        throw ExamException.bad("Mã học sinh quá dài.");
                    }
                    SourceService.required(row.get("full_name"), "full_name");
                    if (repo.owned("students", teacher, Student.class).stream().anyMatch(s -> s.code().equals(code))) {
                        throw ExamException.conflict("Mã học sinh đã tồn tại.");
                    }
                } else {
                    validateResult(teacher, session, inputFromRow(teacher, session, row));
                }
            } catch (ExamException e) {
                errors.add("Dòng " + (i + 2) + ": " + e.getMessage());
            }
        }
        return errors;
    }

    @Transactional
    public ImportJob preview(String teacher, String sessionId, String classId, String kind, MultipartFile file) throws IOException {
        List<Map<String, String>> rows = readSheet(file);
        List<String> errors = validateRows(teacher, sessionId, classId, kind, rows);
        ImportJob job = new ImportJob(id(), teacher, sessionId, classId, kind, rows, errors, System.currentTimeMillis() + 30 * 60 * 1000, false);
        Map<String, Object> cols = new HashMap<>();
        cols.put("teacher_id", teacher);
        cols.put("session_id", sessionId);
        repo.insert("import_jobs", job.id(), job, cols);
        return job;
    }

    @Transactional
    public Map<String, Object> commit(String teacher, String importId) {
        repo.jdbc().query(
                "SELECT id FROM exam_platform.import_jobs WHERE id = ? FOR UPDATE",
                (rs, n) -> rs.getString(1),
                importId
        );
        ImportJob job = repo.require("import_jobs", importId, ImportJob.class);
        if (!job.teacherId().equals(teacher)) {
            throw ExamException.missing();
        }
        if (job.committed()) {
            throw ExamException.conflict("Import này đã được ghi nhận.");
        }
        if (job.expiresAt() < System.currentTimeMillis()) {
            throw ExamException.conflict("Preview đã hết hạn; tạo preview mới.");
        }
        List<String> errors = validateRows(teacher, job.sessionId(), job.classId(), job.kind(), job.rows());
        if (!errors.isEmpty()) {
            throw new ExamException(HttpStatus.BAD_REQUEST, "IMPORT_INVALID", "Sửa lỗi và tải file mới trước khi ghi nhận.", errors);
        }
        Session session = job.sessionId() == null ? null : ownedSession(job.sessionId(), teacher);
        for (var row : job.rows()) {
            if ("ROSTER".equals(job.kind())) {
                createStudent(teacher, row.get("student_code"), row.get("full_name"), row.get("notes"), job.classId());
            } else {
                Result r = validateResult(teacher, session, inputFromRow(teacher, session, row));
                saveResult(r, session);
            }
        }
        repo.update("import_jobs", job.id(), new ImportJob(job.id(), teacher, job.sessionId(), job.classId(), job.kind(), job.rows(), List.of(), job.expiresAt(), true));
        return Map.of("committed", true, "rows", job.rows().size());
    }
}
