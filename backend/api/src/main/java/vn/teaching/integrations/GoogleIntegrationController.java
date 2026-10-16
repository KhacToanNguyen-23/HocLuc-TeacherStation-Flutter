package vn.teaching.integrations;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.net.URI;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/integrations/google")
public class GoogleIntegrationController {
    private final GoogleConnectionService connections;
    private final GoogleClassService classes;
    public GoogleIntegrationController(GoogleConnectionService connections,GoogleClassService classes) { this.connections=connections; this.classes=classes; }
    record Start(String email, Boolean forceConsent) { }
    record Poll(String state,String pollToken) { }
    record Create(String requestId,String title,String description,List<String> emails) { }
    record Invite(List<String> emails) { }
    record MeetAccess(String email, Boolean allowed) { }
    record Schedule(String requestId,String start,String end) { }
    record StartLesson(String requestId) { }
    @GetMapping("/status") public Object status(HttpServletRequest req) { local(req); return connections.status(req.getHeader("X-Google-Teacher-Email")); }
    @PostMapping("/connect") public Object connect(HttpServletRequest req,@RequestBody Start body) {
        local(req);
        return connections.start(body.email(),Boolean.TRUE.equals(body.forceConsent()));
    }
    @PostMapping("/poll") public Object poll(HttpServletRequest req,@RequestBody Poll body) { local(req); return connections.poll(body.state(),body.pollToken()); }
    @PostMapping("/disconnect") public Object disconnect(HttpServletRequest req) { connections.disconnect(email(req)); return Map.of("connected",false); }
    @GetMapping("/courses") public Object courses(HttpServletRequest req) { return Map.of("courses",classes.list(email(req))); }
    @PostMapping("/courses") public Object create(HttpServletRequest req,@RequestBody Create body) { return classes.create(email(req),body.requestId(),body.title(),body.description(),body.emails()); }
    @PostMapping("/courses/{id}/invite") public Object invite(HttpServletRequest req,@PathVariable String id,@RequestBody Invite body) { return classes.invite(email(req),id,body.emails()); }
    @PostMapping("/courses/{id}/sync") public Object sync(HttpServletRequest req,@PathVariable String id) { return classes.sync(email(req),id); }
    @PostMapping("/courses/{id}/invite-all-meet") public Object inviteAllToMeet(HttpServletRequest req,@PathVariable String id) { return classes.inviteAllToMeet(email(req),id); }
    @PostMapping("/courses/{id}/access") public Object access(HttpServletRequest req,@PathVariable String id,@RequestBody MeetAccess body) {
        if(body.allowed()==null) throw new IllegalArgumentException("allowed is required");
        return classes.setMeetAccess(email(req),id,body.email(),body.allowed());
    }
    @PostMapping("/courses/{id}/prepare") public Object prepare(HttpServletRequest req,@PathVariable String id) { return classes.prepare(email(req),id); }
    @PostMapping("/courses/{id}/start") public Object startLesson(HttpServletRequest req,@PathVariable String id,@RequestBody StartLesson body) { return classes.start(email(req),id,body.requestId()); }
    @PostMapping("/courses/{id}/schedule") public Object schedule(HttpServletRequest req,@PathVariable String id,@RequestBody Schedule body) { return classes.schedule(email(req),id,body.requestId(),body.start(),body.end()); }
    @GetMapping(value="/callback",produces="text/html;charset=UTF-8")
    public ResponseEntity<String> callback(HttpServletRequest req,@RequestParam(required=false) String state,@RequestParam(required=false) String code,@RequestParam(required=false) String error) {
        local(req);
        connections.callback(state,code,error);
        return ResponseEntity.ok().header("Cache-Control","no-store").header("Referrer-Policy","no-referrer")
            .header("Content-Security-Policy","default-src 'none'; style-src 'unsafe-inline'; frame-ancestors 'none'")
            .body("<!doctype html><html lang='vi'><meta charset='utf-8'><title>HocLuc</title><body style='font:18px system-ui;padding:48px'><h1>Đã nhận phản hồi Google</h1><p>Trở về HocLuc để xem kết quả kết nối. Bạn có thể đóng cửa sổ này.</p></body></html>");
    }
    private String email(HttpServletRequest req) { local(req); return GoogleConnectionService.normalizeEmail(req.getHeader("X-Google-Teacher-Email")); }
    static void local(HttpServletRequest req) {
        if(!loopback(req.getRemoteAddr()) || !loopback(req.getServerName())) throw new GoogleFailure(403,"LOCAL_ONLY","Kết nối Google chỉ dùng trong ứng dụng trên máy này.");
        String origin=req.getHeader("Origin");
        if(origin!=null) {
            try { var uri=URI.create(origin); if(!SetHolder.SCHEMES.contains(uri.getScheme()) || !loopback(uri.getHost())) throw new IllegalArgumentException(); }
            catch(Exception e) { throw new GoogleFailure(403,"LOCAL_ORIGIN","Nguồn truy cập không hợp lệ."); }
        }
    }
    private static boolean loopback(String host) { return "127.0.0.1".equals(host)||"localhost".equals(host)||"::1".equals(host)||"[::1]".equals(host)||"0:0:0:0:0:0:0:1".equals(host); }
    private static class SetHolder { static final java.util.Set<String> SCHEMES=java.util.Set.of("http","https"); }
}
