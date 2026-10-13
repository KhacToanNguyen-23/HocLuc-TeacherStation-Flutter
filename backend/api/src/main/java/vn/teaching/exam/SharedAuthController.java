package vn.teaching.exam;

import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/auth")
public class SharedAuthController {
    private final ExamAuth auth; private final GoogleOAuthService google;
    public SharedAuthController(ExamAuth auth,GoogleOAuthService google) { this.auth=auth; this.google=google; }
    @GetMapping("/session") public Object session(@RequestHeader(value="Authorization",required=false) String header) { return auth.authenticate(header); }
    @PostMapping("/logout") public Object logout(@RequestHeader(value="Authorization",required=false) String header) { auth.authenticate(header); auth.logout(header); return Map.of("success",true); }
    @PostMapping("/google/start") public Object google() { return google.start(); }
    @PostMapping("/google/poll") public ResponseEntity<?> poll(@RequestBody Map<String,String> input) { return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(google.poll(input.get("state"),input.get("pollToken"))); }
    @GetMapping("/google/callback") public ResponseEntity<String> callback(@RequestParam String state,@RequestParam(required=false) String code,@RequestParam(required=false) String error) {
        google.callback(state,code,error);
        return ResponseEntity.ok().contentType(MediaType.parseMediaType("text/html;charset=UTF-8")).cacheControl(CacheControl.noStore()).header("Referrer-Policy","no-referrer").body("<!doctype html><html lang=vi><meta charset=utf-8><title>Mộc · Google</title><body><h2>Đã nhận phản hồi từ Google</h2><p>Quay lại app Mộc để tiếp tục. App sẽ hiển thị kết quả xác minh.</p></body></html>");
    }
}
