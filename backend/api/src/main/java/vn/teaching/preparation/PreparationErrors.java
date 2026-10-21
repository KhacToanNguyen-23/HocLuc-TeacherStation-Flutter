package vn.teaching.preparation;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import vn.teaching.exam.ExamException;
import java.util.Map;
@RestControllerAdvice(basePackages="vn.teaching.preparation",assignableTypes=vn.teaching.controller.PlanningController.class)
public class PreparationErrors {
    @ExceptionHandler(vn.teaching.integrations.GoogleFailure.class)public ResponseEntity<?> google(vn.teaching.integrations.GoogleFailure e){return ResponseEntity.status(e.status).body(Map.of("code",e.code,"message",e.getMessage()));}
    @ExceptionHandler(ExamException.class) public ResponseEntity<?> domain(ExamException e){return ResponseEntity.status(e.status).body(Map.of("code",e.code,"message",e.getMessage(),"details",e.details));}
    @ExceptionHandler({IllegalArgumentException.class,NullPointerException.class}) public ResponseEntity<?> bad(Exception e){return domain(ExamException.bad("Dữ liệu Soạn bài không hợp lệ."));}
    @ExceptionHandler(IllegalStateException.class)public ResponseEntity<?> unavailable(IllegalStateException e){return ResponseEntity.status(503).body(Map.of("message",e.getMessage()));}
}
