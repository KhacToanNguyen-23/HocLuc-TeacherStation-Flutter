package vn.teaching.modules.planning.controller;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.modules.planning.model.Planning;
import vn.teaching.modules.planning.service.PlanningService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/plannings")
public class PlanningController {
    private final PlanningService planningService;
    private final Gson gson;

    public PlanningController(PlanningService planningService, Gson gson) {
        this.planningService = planningService;
        this.gson = gson;
    }

    @GetMapping
    public ResponseEntity<List<Planning>> getAllPlannings() {
        return ResponseEntity.ok(planningService.getAllPlannings());
    }

    @GetMapping("/{id}")
    public ResponseEntity<String> getPlanningContent(@PathVariable String id) {
        JsonObject content = planningService.getPlanningContent(id);
        if (content == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(content.toString());
    }

    @PostMapping
    public ResponseEntity<?> createPlanning(@RequestBody String body) {
        try {
            JsonObject req = JsonParser.parseString(body).getAsJsonObject();
            String title = req.has("title") && !req.get("title").isJsonNull() ? req.get("title").getAsString() : "Kế hoạch bài giảng mới";
            String subject = req.has("subject") && !req.get("subject").isJsonNull() ? req.get("subject").getAsString() : "Chung";
            JsonObject content = req.has("content") && req.get("content").isJsonObject() ? req.getAsJsonObject("content") : null;

            Planning planning = planningService.saveOrUpdatePlanning(null, title, subject, content);
            if (planning != null) {
                return ResponseEntity.ok(planning);
            }
            return ResponseEntity.badRequest().body(Map.of("error", "Không thể tạo kế hoạch bài giảng"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Dữ liệu không hợp lệ: " + e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updatePlanning(@PathVariable String id, @RequestBody String body) {
        try {
            JsonObject req = JsonParser.parseString(body).getAsJsonObject();
            String title = req.has("title") && !req.get("title").isJsonNull() ? req.get("title").getAsString() : null;
            String subject = req.has("subject") && !req.get("subject").isJsonNull() ? req.get("subject").getAsString() : null;
            JsonObject content = req.has("content") && req.get("content").isJsonObject() ? req.getAsJsonObject("content") : null;

            Planning planning = planningService.saveOrUpdatePlanning(id, title, subject, content);
            if (planning != null) {
                return ResponseEntity.ok(planning);
            }
            return ResponseEntity.badRequest().body(Map.of("error", "Không thể cập nhật kế hoạch bài giảng"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Dữ liệu không hợp lệ: " + e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deletePlanning(@PathVariable String id) {
        boolean ok = planningService.deletePlanning(id);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @PostMapping("/{id}/clone-to-classroom")
    public ResponseEntity<Map<String, Object>> cloneToClassroom(@PathVariable String id) {
        boolean ok = planningService.cloneToClassroom(id);
        return ResponseEntity.ok(Map.of("success", ok));
    }
}

