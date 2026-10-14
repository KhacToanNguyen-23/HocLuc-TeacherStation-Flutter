package vn.teaching.exam;

import org.springframework.http.HttpStatus;

public class ExamException extends RuntimeException {
    public final HttpStatus status;
    public final String code;
    public final Object details;
    public ExamException(HttpStatus status, String code, String message, Object details) {
        super(message); this.status = status; this.code = code; this.details = details;
    }
    public static ExamException bad(String message) { return new ExamException(HttpStatus.BAD_REQUEST, "VALIDATION", message, java.util.List.of()); }
    public static ExamException missing() { return new ExamException(HttpStatus.NOT_FOUND, "NOT_FOUND", "Không tìm thấy dữ liệu trong tài khoản này.", java.util.List.of()); }
    public static ExamException conflict(String message) { return new ExamException(HttpStatus.CONFLICT, "CONFLICT", message, java.util.List.of()); }
}
