package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import com.google.gson.reflect.TypeToken;
import org.springframework.stereotype.Service;
import vn.teaching.model.Classroom;

import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

@Service
public class ClassroomService {
    private static final Logger log = LoggerFactory.getLogger(ClassroomService.class);
    private final Path dataDirectory;
    private final Path classroomsDir;
    private final GoogleMeetService googleMeetService;
    private final Object fileLock = new Object();
    private final Gson gson;

    public ClassroomService(Path dataDirectory, Gson gson) {
        this.dataDirectory = dataDirectory;
        this.classroomsDir = dataDirectory.resolve("classrooms");
        this.gson = gson;
        this.googleMeetService = new GoogleMeetService();
        try {
            java.nio.file.Files.createDirectories(this.classroomsDir);
        } catch (Exception ignored) {}
    }

    public Classroom createClassroom(String directUrl, String accessToken, String title, String teacherId) {
        long startedAt = System.nanoTime();
        synchronized (fileLock) {
        JsonObject active = getActiveClassroom();
        if (active.has("status") && "ONGOING".equals(active.get("status").getAsString())) {
            String owner = teacherId != null && !teacherId.isBlank() ? teacherId : "teacher_default";
            if (directUrl != null && active.has("meetingUrl") && directUrl.equals(active.get("meetingUrl").getAsString())
                    && active.has("teacherId") && owner.equals(active.get("teacherId").getAsString())) {
                return gson.fromJson(active, Classroom.class);
            }
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Đang có buổi học khác. Kết thúc buổi hiện tại trước khi chuyển lớp.");
        }
        String meetUrl = directUrl;

        // Nếu chưa có link trực tiếp mà có token Google, gọi GoogleMeetService
        if ((meetUrl == null || meetUrl.isBlank()) && accessToken != null && !accessToken.isBlank()) {
            meetUrl = googleMeetService.createOfficialMeetRoom(accessToken, title);
        }

        if (meetUrl != null && !meetUrl.isBlank()) {
            Classroom classroom = new Classroom(true, meetUrl, "ONGOING");
            classroom.setId("cls_" + UUID.randomUUID().toString().substring(0, 8));
            classroom.setTitle(title != null && !title.isBlank() ? title : "Phòng học trực tuyến");
            classroom.setTeacherId(teacherId != null && !teacherId.isBlank() ? teacherId : "teacher_default");
            classroom.setStartedAt(System.currentTimeMillis());

            if (!saveOrUpdateClassroom(classroom)) {
                return Classroom.error("ChÆ°a lÆ°u Ä‘Æ°á»£c buá»•i há»c vÃ o bá»™ nhá»›.");
            }
            if (!setActiveClassroom(classroom)) {
                List<Classroom> rollback = loadAllClassrooms();
                rollback.removeIf(c -> classroom.getId().equals(c.getId()));
                saveAllClassrooms(rollback);
                return Classroom.error("ChÆ°a lÆ°u Ä‘Æ°á»£c phÃ²ng há»c Ä‘ang má»Ÿ.");
            }
            log.info("[classroom] Started | duration_ms={}", (System.nanoTime() - startedAt) / 1_000_000);
            return classroom;
        }

        return Classroom.error("Chưa có đường dẫn Meet hoặc cần token ủy quyền Google");
        }
    }

    public Classroom createClassroom(String directUrl, String accessToken, String title) {
        return createClassroom(directUrl, accessToken, title, null);
    }

    public JsonObject getActiveClassroom() {
        Path file = dataDirectory.resolve("active_classroom.json");
        synchronized (fileLock) {
            try {
                if (Files.exists(file)) {
                    String content = Files.readString(file, StandardCharsets.UTF_8);
                    if (!content.isBlank()) {
                        return JsonParser.parseString(content).getAsJsonObject();
                    }
                }
            } catch (Exception e) {
                log.warn("[classroom] Failed to read active classroom | cause={}", e.getClass().getSimpleName());
            }
            return new JsonObject();
        }
    }

    public boolean endClassroom(String classroomId) {
        return endClassroom(classroomId, null);
    }

    public boolean endClassroom(String classroomId, JsonObject content) {
        long startedAt = System.nanoTime();
        synchronized (fileLock) {
            try {
                JsonObject active = getActiveClassroom();
                List<Classroom> list = loadAllClassrooms();
                if (!active.has("id")) {
                    return classroomId != null && list.stream().anyMatch(c ->
                            classroomId.equals(c.getId()) && "COMPLETED".equalsIgnoreCase(c.getStatus()));
                }
                String activeId = active.get("id").getAsString();
                if (classroomId != null && !classroomId.equals(activeId)) return false;
                Classroom target = null;
                for (Classroom c : list) {
                    if (activeId.equals(c.getId())) {
                        target = c;
                        break;
                    }
                }

                if (target == null) return false;

                if ("COMPLETED".equalsIgnoreCase(target.getStatus())) {
                    Files.deleteIfExists(dataDirectory.resolve("active_classroom.json"));
                    return true;
                }
                if (!"ONGOING".equalsIgnoreCase(target.getStatus()) ||
                        !active.has("status") || !"ONGOING".equalsIgnoreCase(active.get("status").getAsString())) return false;

                target.setStatus("COMPLETED");
                long now = System.currentTimeMillis();
                target.setEndedAt(now);
                long start = target.getStartedAt() > 0 ? target.getStartedAt() : target.getCreatedAt();
                int duration = (int) Math.max(1, (now - start) / 60000);
                target.setDurationMinutes(duration);

                // Save snapshot of lesson content (slides, strokes, notes) if provided
                if (content != null) {
                    try {
                        Path contentFile = classroomsDir.resolve(target.getId() + ".json");
                        Files.writeString(contentFile, gson.toJson(content), StandardCharsets.UTF_8);
                        target.setHasContent(true);
                        if (content.has("pages") && content.get("pages").isJsonArray()) {
                            target.setPageCount(content.getAsJsonArray("pages").size());
                        }
                    } catch (Exception e) {
                        log.warn("[classroom] Failed to persist lesson content snapshot | id={} cause={}",
                                target.getId(), e.getClass().getSimpleName());
                        return false;
                    }
                }

                if (!saveAllClassrooms(list)) {
                    return false;
                }

                // Keep active state until the completed record is durably saved.
                Path activeFile = dataDirectory.resolve("active_classroom.json");
                Files.deleteIfExists(activeFile);
                log.info("[classroom] Ended | duration_ms={}", (System.nanoTime() - startedAt) / 1_000_000);
                return true;
            } catch (Exception e) {
                log.error("[classroom] Failed to end | duration_ms={} cause={}",
                        (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }

    public JsonObject getClassroomContent(String id) {
        synchronized (fileLock) {
            try {
                Path contentPath = classroomsDir.resolve(id + ".json");
                if (Files.exists(contentPath)) {
                    String json = Files.readString(contentPath, StandardCharsets.UTF_8);
                    return JsonParser.parseString(json).getAsJsonObject();
                }
            } catch (Exception e) {
                log.warn("[classroom] Failed to read classroom content | id={} cause={}", id, e.getClass().getSimpleName());
            }
            return null;
        }
    }

    public boolean leaveClassroom() {
        // Tương thích ngược: chỉ đóng tạm thời phiên hiện tại, không xóa dữ liệu phòng
        return true;
    }

    public JsonArray getClassroomHistory(String teacherId) {
        synchronized (fileLock) {
            JsonArray arr = new JsonArray();
            try {
                JsonObject active = getActiveClassroom();
                String activeId = active.has("id") ? active.get("id").getAsString() : null;

                List<Classroom> list = loadAllClassrooms();
                boolean updated = false;
                for (Classroom c : list) {
                    // Tự động thu hồi / hoàn tất các buổi học cũ bị kẹt trạng thái ONGOING mà không còn là active
                    if ("ONGOING".equalsIgnoreCase(c.getStatus()) && (activeId == null || !activeId.equals(c.getId()))) {
                        c.setStatus("COMPLETED");
                        if (c.getEndedAt() == null || c.getEndedAt() <= 0) {
                            c.setEndedAt(System.currentTimeMillis());
                            long start = c.getStartedAt() > 0 ? c.getStartedAt() : c.getCreatedAt();
                            c.setDurationMinutes((int) Math.max(1, (c.getEndedAt() - start) / 60000));
                        }
                        Path contentFile = classroomsDir.resolve(c.getId() + ".json");
                        c.setHasContent(Files.exists(contentFile));
                        updated = true;
                    }

                    if ("COMPLETED".equalsIgnoreCase(c.getStatus())) {
                        if (teacherId == null || teacherId.isBlank() || teacherId.equals(c.getTeacherId())) {
                            arr.add(gson.toJsonTree(c));
                        }
                    }
                }
                if (updated) {
                    saveAllClassrooms(list);
                }
            } catch (Exception e) {
                log.warn("[classroom] Failed to read history | cause={}", e.getClass().getSimpleName());
            }
            return arr;
        }
    }

    public boolean deleteClassroomHistory(String classroomId) {
        if (classroomId == null || classroomId.isBlank()) return false;
        synchronized (fileLock) {
            try {
                List<Classroom> list = loadAllClassrooms();
                boolean removed = list.removeIf(c -> classroomId.equals(c.getId()));
                if (removed) {
                    saveAllClassrooms(list);
                    Path contentFile = classroomsDir.resolve(classroomId + ".json");
                    try {
                        Files.deleteIfExists(contentFile);
                    } catch (Exception ignored) {}
                    log.info("[classroom] History deleted | id={}", classroomId);
                    return true;
                }
            } catch (Exception e) {
                log.warn("[classroom] Failed to delete history | id={} cause={}", classroomId, e.getClass().getSimpleName());
            }
            return false;
        }
    }

    public boolean clearAllClassroomHistory(String teacherId) {
        synchronized (fileLock) {
            try {
                List<Classroom> list = loadAllClassrooms();
                List<Classroom> remaining = new ArrayList<>();
                for (Classroom c : list) {
                    boolean matchesTeacher = teacherId == null || teacherId.isBlank() || teacherId.equals(c.getTeacherId());
                    if ("COMPLETED".equalsIgnoreCase(c.getStatus()) && matchesTeacher) {
                        Path contentFile = classroomsDir.resolve(c.getId() + ".json");
                        try {
                            Files.deleteIfExists(contentFile);
                        } catch (Exception ignored) {}
                    } else {
                        remaining.add(c);
                    }
                }
                saveAllClassrooms(remaining);
                log.info("[classroom] All history cleared | remaining={}", remaining.size());
                return true;
            } catch (Exception e) {
                log.warn("[classroom] Failed to clear history | cause={}", e.getClass().getSimpleName());
                return false;
            }
        }
    }

    private boolean setActiveClassroom(Classroom classroom) {
        Path file = dataDirectory.resolve("active_classroom.json");
        synchronized (fileLock) {
            try {
                Files.writeString(file, gson.toJson(classroom), StandardCharsets.UTF_8);
                return true;
            } catch (Exception e) {
                log.error("[classroom] Failed to save active classroom | cause={}",
                        e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }

    private boolean saveOrUpdateClassroom(Classroom classroom) {
        synchronized (fileLock) {
            List<Classroom> list = loadAllClassrooms();
            list.removeIf(c -> c.getId() != null && c.getId().equals(classroom.getId()));
            list.add(0, classroom);
            return saveAllClassrooms(list);
        }
    }

    private List<Classroom> loadAllClassrooms() {
        Path file = dataDirectory.resolve("classrooms.json");
        try {
            if (Files.exists(file)) {
                String content = Files.readString(file, StandardCharsets.UTF_8);
                if (!content.isBlank()) {
                    Type listType = new TypeToken<ArrayList<Classroom>>(){}.getType();
                    List<Classroom> result = gson.fromJson(content, listType);
                    if (result != null) return result;
                }
            }
        } catch (Exception e) {
            log.warn("[classroom] Failed to read classroom list | cause={}", e.getClass().getSimpleName());
        }
        return new ArrayList<>();
    }

    private boolean saveAllClassrooms(List<Classroom> list) {
        Path file = dataDirectory.resolve("classrooms.json");
        try {
            Files.writeString(file, gson.toJson(list), StandardCharsets.UTF_8);
            return true;
        } catch (Exception e) {
            log.error("[classroom] Failed to save classroom list | cause={}", e.getClass().getSimpleName(), e);
            return false;
        }
    }
}
