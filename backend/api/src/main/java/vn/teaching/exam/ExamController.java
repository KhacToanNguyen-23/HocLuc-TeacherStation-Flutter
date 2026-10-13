package vn.teaching.exam;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.*;
import static vn.teaching.exam.ExamModels.*;

@RestController
@RequestMapping("/api/exams")
public class ExamController {
    private final ExamRepository repo;
    private final ExamAuth auth;
    public ExamController(ExamRepository repo,ExamAuth auth) { this.repo=repo;this.auth=auth; }
    private String teacher(HttpServletRequest request) { return auth.current(request).id(); }
    private String text(Map<String,?> map,String key) { Object v=map.get(key); return v==null?null:v.toString(); }
    private int integer(Map<String,?> map,String key) { try { return Integer.parseInt(String.valueOf(map.get(key))); } catch(Exception e) { throw ExamException.bad(key+" phải là số nguyên."); } }
    @GetMapping("/auth/me") public Object me(HttpServletRequest request) { return auth.current(request); }
    @PostMapping("/auth/logout") public Object logout(HttpServletRequest request) { auth.logout(request.getHeader("Authorization")); return Map.of("success",true); }
}
