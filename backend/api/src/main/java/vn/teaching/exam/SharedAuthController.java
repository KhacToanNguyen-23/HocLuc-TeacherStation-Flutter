package vn.teaching.exam;

import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/auth")
public class SharedAuthController {
    private final ExamAuth auth;
    public SharedAuthController(ExamAuth auth) { this.auth=auth; }
    @GetMapping("/session") public Object session(@RequestHeader(value="Authorization",required=false) String header) { return auth.authenticate(header); }
    @PostMapping("/logout") public Object logout(@RequestHeader(value="Authorization",required=false) String header) { auth.authenticate(header); auth.logout(header); return Map.of("success",true); }
}
