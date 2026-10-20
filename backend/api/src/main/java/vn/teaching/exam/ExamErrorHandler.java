package vn.teaching.exam;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.multipart.MaxUploadSizeExceededException;

import java.util.Map;

@RestControllerAdvice(basePackages = "vn.teaching.exam")
public class ExamErrorHandler {
    private static final Logger log = LoggerFactory.getLogger(ExamErrorHandler.class);

    @ExceptionHandler(ExamException.class)
    public ResponseEntity<?> domain(ExamException e) {
        log.warn("[exam] Domain error | status={} code={} msg={}", e.status, e.code, e.getMessage());
        return ResponseEntity.status(e.status).body(
                Map.of(
                        "code", e.code,
                        "message", e.getMessage(),
                        "details", e.details != null ? e.details : java.util.List.of()
                )
        );
    }

    @ExceptionHandler({HttpMessageNotReadableException.class, IllegalArgumentException.class})
    public ResponseEntity<?> invalid(Exception e) {
        log.warn("[exam] Invalid request | cause={}", e.getMessage());
        return domain(ExamException.bad("Dữ liệu gửi lên không hợp lệ."));
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<?> conflict(Exception e) {
        log.warn("[exam] Data conflict | cause={}", e.getMessage());
        return domain(ExamException.conflict("Dữ liệu trùng hoặc liên kết không hợp lệ. Vui lòng tải lại."));
    }

    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<?> tooLarge(Exception e) {
        log.warn("[exam] Upload limit exceeded | cause={}", e.getMessage());
        return domain(ExamException.bad("Mỗi PDF tối đa 30 MB."));
    }
}
