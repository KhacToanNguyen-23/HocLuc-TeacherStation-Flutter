package vn.teaching.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;
import vn.teaching.integrations.GoogleFailure;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<Map<String, Object>> handleResponseStatusException(ResponseStatusException ex) {
        log.warn("[global] ResponseStatusException | status={} reason={}", ex.getStatusCode().value(), ex.getReason());
        Map<String, Object> body = new LinkedHashMap<>();
        String reason = ex.getReason() != null ? ex.getReason() : "Yêu cầu không thể xử lý.";
        body.put("success", false);
        body.put("status", ex.getStatusCode().value());
        body.put("message", reason);
        body.put("error", reason);
        return ResponseEntity.status(ex.getStatusCode()).body(body);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationException(MethodArgumentNotValidException ex) {
        List<String> details = new ArrayList<>();
        String firstMessage = "Dữ liệu yêu cầu không hợp lệ.";
        for (FieldError fieldError : ex.getBindingResult().getFieldErrors()) {
            String msg = fieldError.getDefaultMessage();
            if (msg != null && !msg.isBlank()) {
                details.add(msg);
                if ("Dữ liệu yêu cầu không hợp lệ.".equals(firstMessage)) {
                    firstMessage = msg;
                }
            }
        }
        log.warn("[global] Validation failed | firstError={}", firstMessage);
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", false);
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("message", firstMessage);
        body.put("error", firstMessage);
        body.put("details", details);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(GoogleFailure.class)
    public ResponseEntity<Map<String, Object>> handleGoogleFailure(GoogleFailure ex) {
        log.warn("[global] GoogleFailure | status={} code={} msg={}", ex.status, ex.code, ex.getMessage());
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", false);
        body.put("status", ex.status);
        body.put("code", ex.code);
        body.put("message", ex.getMessage());
        body.put("error", ex.getMessage());
        return ResponseEntity.status(ex.status).body(body);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgumentException(IllegalArgumentException ex) {
        log.warn("[global] IllegalArgumentException | msg={}", ex.getMessage());
        Map<String, Object> body = new LinkedHashMap<>();
        String msg = ex.getMessage() != null && !ex.getMessage().isBlank() ? ex.getMessage() : "Dữ liệu không hợp lệ.";
        body.put("success", false);
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("message", msg);
        body.put("error", msg);
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<Map<String, Object>> handleHttpMessageNotReadable(HttpMessageNotReadableException ex) {
        log.warn("[global] HttpMessageNotReadableException | cause={}", ex.getMessage());
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("success", false);
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("message", "Nội dung JSON gửi lên không đúng định dạng.");
        body.put("error", "Nội dung JSON gửi lên không đúng định dạng.");
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(body);
    }
}

