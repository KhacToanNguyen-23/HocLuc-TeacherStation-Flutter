package vn.teaching.controller;

import com.google.gson.JsonObject;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.model.Classroom;
import vn.teaching.service.ClassroomService;

import java.util.Map;

@RestController
@RequestMapping("/api/classroom")
public class ClassroomController {
    private final ClassroomService classroomService;

    public ClassroomController(ClassroomService classroomService) {
        this.classroomService = classroomService;
    }

    @PostMapping("/create")
    public ResponseEntity<Classroom> handleCreate(@RequestBody(required = false) Map<String, Object> req) {
        String directUrl = req != null && req.get("directUrl") != null ? req.get("directUrl").toString() : null;
        String token = req != null && req.get("accessToken") != null ? req.get("accessToken").toString() : null;
        String title = req != null && req.get("title") != null ? req.get("title").toString() : null;

        Classroom classroom = classroomService.createClassroom(directUrl, token, title);
        return ResponseEntity.ok(classroom);
    }

    @GetMapping
    public ResponseEntity<String> handleGet() {
        JsonObject active = classroomService.getActiveClassroom();
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(active != null ? active.toString() : "{}");
    }

    @PostMapping("/leave")
    public ResponseEntity<Map<String, Object>> handleLeave() {
        boolean ok = classroomService.leaveClassroom();
        return ResponseEntity.ok(Map.of("success", ok));
    }
}
