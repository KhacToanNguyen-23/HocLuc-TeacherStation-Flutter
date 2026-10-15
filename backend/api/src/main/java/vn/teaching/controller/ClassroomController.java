package vn.teaching.controller;

import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.model.Classroom;
import vn.teaching.service.ClassroomService;

import java.util.Map;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/classroom")
public class ClassroomController {
    @ExceptionHandler(ResponseStatusException.class)
    public ResponseEntity<?> sessionConflict(ResponseStatusException error) {
        return ResponseEntity.status(error.getStatusCode()).body(Map.of("message",error.getReason()==null?"Không mở được buổi học.":error.getReason()));
    }
    private final ClassroomService classroomService;

    public ClassroomController(ClassroomService classroomService) {
        this.classroomService = classroomService;
    }

    @PostMapping("/create")
    public ResponseEntity<Classroom> handleCreate(@RequestBody(required = false) Map<String, Object> req) {
        String directUrl = req != null && req.get("directUrl") != null ? req.get("directUrl").toString() : null;
        String token = req != null && req.get("accessToken") != null ? req.get("accessToken").toString() : null;
        String title = req != null && req.get("title") != null ? req.get("title").toString() : null;
        String teacherId = req != null && req.get("teacherId") != null ? req.get("teacherId").toString() : null;

        Classroom classroom = classroomService.createClassroom(directUrl, token, title, teacherId);
        return ResponseEntity.ok(classroom);
    }

    @GetMapping
    public ResponseEntity<String> handleGet() {
        JsonObject active = classroomService.getActiveClassroom();
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(active != null ? active.toString() : "{}");
    }

    @GetMapping("/active")
    public ResponseEntity<String> handleGetActive() {
        JsonObject active = classroomService.getActiveClassroom();
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(active != null ? active.toString() : "{}");
    }

    @PostMapping("/end")
    public ResponseEntity<Map<String, Object>> handleEnd(@RequestBody(required = false) Map<String, Object> req) {
        String classroomId = req != null && req.get("classroomId") != null ? req.get("classroomId").toString() : null;
        boolean ok = classroomService.endClassroom(classroomId);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @GetMapping("/history")
    public ResponseEntity<String> handleGetHistory(@RequestParam(required = false) String teacherId) {
        JsonArray history = classroomService.getClassroomHistory(teacherId);
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(history != null ? history.toString() : "[]");
    }

    @PostMapping("/leave")
    public ResponseEntity<Map<String, Object>> handleLeave() {
        boolean ok = classroomService.leaveClassroom();
        return ResponseEntity.ok(Map.of("success", ok));
    }
}
