package vn.teaching.integrations;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.converter.HttpMessageNotReadableException;
import java.util.Map;

@RestControllerAdvice(basePackages="vn.teaching.integrations")
public class GoogleIntegrationErrors {
    @ExceptionHandler(GoogleFailure.class)
    public ResponseEntity<?> google(GoogleFailure e) { return ResponseEntity.status(e.status).header("Cache-Control","no-store").body(Map.of("code",e.code,"message",e.getMessage())); }
    @ExceptionHandler({IllegalArgumentException.class,HttpMessageNotReadableException.class})
    public ResponseEntity<?> invalid(Exception e) { return ResponseEntity.badRequest().body(Map.of("code","INVALID_REQUEST","message","Dữ liệu gửi lên không hợp lệ.")); }
}
