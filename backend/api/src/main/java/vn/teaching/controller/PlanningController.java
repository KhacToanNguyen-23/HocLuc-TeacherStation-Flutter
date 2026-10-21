package vn.teaching.controller;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.model.Planning;
import vn.teaching.service.PlanningService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/plannings")
public class PlanningController {
    private final PlanningService planningService;
    private final Gson gson;
    private final vn.teaching.preparation.PreparationStore preparation;
    private final vn.teaching.exam.ExamAuth auth;
    private final vn.teaching.preparation.PreparationRecording recording;

    public PlanningController(PlanningService planningService, Gson gson,vn.teaching.preparation.PreparationStore preparation,vn.teaching.exam.ExamAuth auth,vn.teaching.preparation.PreparationRecording recording) {
        this.planningService = planningService;
        this.gson = gson;
        this.preparation=preparation;this.auth=auth;this.recording=recording;
    }
    private String owner(String header){return header==null?"":auth.authenticate(header).id();}
    private void access(String id,String header){if(!preparation.legacyAllowed(id,owner(header)))throw vn.teaching.exam.ExamException.missing();}

    @GetMapping
    public ResponseEntity<List<Planning>> getAllPlannings(@RequestHeader(value="Authorization",required=false)String token) {
        String owner=owner(token);return ResponseEntity.ok(planningService.getAllPlannings().stream().filter(p->preparation.legacyAllowed(p.getId(),owner)).toList());
    }

    @GetMapping("/{id}")
    public ResponseEntity<String> getPlanningContent(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token) {
        access(id,token);
        JsonObject content = planningService.getPlanningContent(id);
        if (content == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(content.toString());
    }

    @PostMapping
    public ResponseEntity<?> createPlanning(@RequestBody String body,@RequestHeader(value="Authorization",required=false)String token) {
        String owner=owner(token);
        try {
            JsonObject req = JsonParser.parseString(body).getAsJsonObject();
            String title = req.has("title") && !req.get("title").isJsonNull() ? req.get("title").getAsString() : "Kế hoạch bài giảng mới";
            String subject = req.has("subject") && !req.get("subject").isJsonNull() ? req.get("subject").getAsString() : "Chung";
            JsonObject content = req.has("content") && req.get("content").isJsonObject() ? req.getAsJsonObject("content") : null;

            Planning planning = planningService.saveOrUpdatePlanning(null, title, subject, content);
            if (planning != null) {
                if(!owner.isBlank())preparation.claim(planning.getId(),owner);
                return ResponseEntity.ok(planning);
            }
            return ResponseEntity.badRequest().body(Map.of("error", "Không thể tạo kế hoạch bài giảng"));
        } catch (vn.teaching.exam.ExamException e) { throw e;
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Dữ liệu không hợp lệ: " + e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> updatePlanning(@PathVariable String id, @RequestBody String body,@RequestHeader(value="Authorization",required=false)String token) {
        access(id,token);
        try {
            JsonObject req = JsonParser.parseString(body).getAsJsonObject();
            String title = req.has("title") && !req.get("title").isJsonNull() ? req.get("title").getAsString() : null;
            String subject = req.has("subject") && !req.get("subject").isJsonNull() ? req.get("subject").getAsString() : null;
            JsonObject content = req.has("content") && req.get("content").isJsonObject() ? req.getAsJsonObject("content") : null;

            if(content!=null&&preparation.claimed(id))content.remove("preparation");

            Integer expected = req.has("expectedRevision") ? req.get("expectedRevision").getAsInt() : null;
            JsonObject planning = planningService.saveBoardResponse(id, title, subject, content, expected);
            if (planning != null) {
                // Gson trees must be written as JSON, not inspected as Jackson beans.
                return ResponseEntity.ok()
                        .header("Content-Type", "application/json; charset=utf-8")
                        .body(planning.toString());
            }
            return ResponseEntity.badRequest().body(Map.of("error", "Không thể cập nhật kế hoạch bài giảng"));
        } catch (vn.teaching.exam.ExamException e) { throw e;
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", "Dữ liệu không hợp lệ: " + e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Map<String, Object>> deletePlanning(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token) {
        access(id,token);
        if(preparation.claimed(id)&&(preparation.pending(id)||recording.pending(id)))throw vn.teaching.exam.ExamException.conflict("Hủy tác vụ và dừng bản ghi trước khi xóa bài.");
        boolean ok = planningService.deletePlanning(id);
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @PostMapping("/{id}/clone-to-classroom")
    public ResponseEntity<?> cloneToClassroom(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token) {
        access(id,token);
        JsonObject content = planningService.cloneContentToClassroom(id);
        JsonObject response = new JsonObject();
        response.addProperty("success", content != null);
        if (content != null) response.add("content", content);
        return ResponseEntity.ok().header("Content-Type", "application/json; charset=utf-8").body(response.toString());
    }
}
