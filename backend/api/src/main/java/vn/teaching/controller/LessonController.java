package vn.teaching.controller;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.service.StorageService;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api")
public class LessonController {
    private final StorageService storageService;

    public LessonController(StorageService storageService) {
        this.storageService = storageService;
    }

    @GetMapping("/lesson")
    public ResponseEntity<String> getLesson() throws IOException {
        JsonObject data = storageService.readDocument("lesson");
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(data != null ? data.toString() : "{}");
    }

    @PutMapping("/lesson")
    public ResponseEntity<?> saveLesson(@RequestBody String body) throws IOException {
        return saveDocument("lesson", body);
    }

    @GetMapping("/config")
    public ResponseEntity<String> getConfig() throws IOException {
        JsonObject data = storageService.readDocument("config");
        return ResponseEntity.ok()
                .header("Content-Type", "application/json; charset=utf-8")
                .body(data != null ? data.toString() : "{}");
    }

    @PutMapping("/config")
    public ResponseEntity<?> saveConfig(@RequestBody String body) throws IOException {
        return saveDocument("config", body);
    }

    private ResponseEntity<?> saveDocument(String path, String body) throws IOException {
        if (body == null || body.length() > 2_000_000) {
            return ResponseEntity.badRequest().body(Map.of("error", "Document too large"));
        }
        JsonElement parsed = JsonParser.parseString(body);
        if (!parsed.isJsonObject()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Expected JSON object"));
        }
        storageService.saveDocument(path, parsed.getAsJsonObject());
        return ResponseEntity.ok(Map.of("saved", true));
    }
}
