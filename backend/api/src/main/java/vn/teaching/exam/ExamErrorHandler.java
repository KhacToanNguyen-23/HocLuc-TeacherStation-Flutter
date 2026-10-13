package vn.teaching.exam;

import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MaxUploadSizeExceededException;
import java.util.*;

@RestControllerAdvice(basePackages="vn.teaching.exam")
public class ExamErrorHandler {
    @ExceptionHandler(ExamException.class)
    public ResponseEntity<?> domain(ExamException e) { return ResponseEntity.status(e.status).body(Map.of("code",e.code,"message",e.getMessage(),"details",e.details)); }
    @ExceptionHandler({HttpMessageNotReadableException.class,IllegalArgumentException.class})
    public ResponseEntity<?> invalid(Exception e) { return domain(ExamException.bad("Dữ liệu gửi lên không hợp lệ.")); }
    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<?> conflict(Exception e) { return domain(ExamException.conflict("Dữ liệu trùng hoặc liên kết không hợp lệ. Vui lòng tải lại.")); }
    @ExceptionHandler(MaxUploadSizeExceededException.class)
    public ResponseEntity<?> tooLarge(Exception e) { return domain(ExamException.bad("Mỗi PDF tối đa 30 MB.")); }
}
