package vn.teaching.modules.classroom.controller;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.modules.classroom.model.Classroom;
import vn.teaching.modules.classroom.service.ClassroomService;

import java.util.Map;

@RestController
@RequestMapping("/api/classroom")
public class ClassroomController {
    private static final Logger log = LoggerFactory.getLogger(ClassroomController.class);

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
        if (!classroom.isSuccess()) {
            return ResponseEntity.badRequest().body(classroom);
        }
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
        JsonObject content = null;
        if (req != null && req.get("content") != null) {
            try {
                content = JsonParser.parseString(new Gson().toJson(req.get("content"))).getAsJsonObject();
            } catch (Exception e) {
                log.warn("[classroom] Failed to parse content JSON | cause={}", e.getMessage());
            }
        }
        boolean ok = classroomService.endClassroom(classroomId, content);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @GetMapping("/{id}/content")
    public ResponseEntity<String> handleGetContent(@PathVariable String id) {
        JsonObject content = classroomService.getClassroomContent(id);
        if (content == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(content.toString());
    }

    @GetMapping("/history")
    public ResponseEntity<String> handleGetHistory(@RequestParam(required = false) String teacherId) {
        JsonArray history = classroomService.getClassroomHistory(teacherId);
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(history != null ? history.toString() : "[]");
    }

    @DeleteMapping("/history/{id}")
    public ResponseEntity<Map<String, Object>> handleDeleteHistory(@PathVariable String id) {
        boolean ok = classroomService.deleteClassroomHistory(id);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @DeleteMapping("/history")
    public ResponseEntity<Map<String, Object>> handleClearHistory(@RequestParam(required = false) String teacherId) {
        boolean ok = classroomService.clearAllClassroomHistory(teacherId);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @PostMapping("/leave")
    public ResponseEntity<Map<String, Object>> handleLeave() {
        boolean ok = classroomService.leaveClassroom();
        return ResponseEntity.ok(Map.of("success", ok));
    }
}

