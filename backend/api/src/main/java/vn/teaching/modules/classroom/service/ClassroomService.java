package vn.teaching.modules.classroom.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.teaching.modules.classroom.model.Classroom;
import vn.teaching.modules.classroom.repository.ClassroomRepository;
import vn.teaching.modules.classroom.repository.FileClassroomRepository;

import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Service
public class ClassroomService {
    private static final Logger log = LoggerFactory.getLogger(ClassroomService.class);
    private final ClassroomRepository repository;
    private final GoogleMeetService googleMeetService;
    private final Gson gson;

    @Autowired
    public ClassroomService(ClassroomRepository repository, Gson gson) {
        this.repository = repository;
        this.gson = gson;
        this.googleMeetService = new GoogleMeetService();
    }

    public ClassroomService(Path dataDirectory, Gson gson) {
        this(new FileClassroomRepository(dataDirectory, gson), gson);
    }

    public Classroom createClassroom(String directUrl, String accessToken, String title, String teacherId) {
        long startedAt = System.nanoTime();
        synchronized (repository.getLock()) {
            long sessionStartedAt = System.currentTimeMillis();
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

            if ((meetUrl == null || meetUrl.isBlank()) && accessToken != null && !accessToken.isBlank()) {
                meetUrl = googleMeetService.createOfficialMeetRoom(accessToken, title);
            }

            if (meetUrl != null && !meetUrl.isBlank()) {
                Classroom classroom = new Classroom(true, meetUrl, "ONGOING");
                classroom.setId("cls_" + UUID.randomUUID().toString().substring(0, 8));
                classroom.setTitle(title != null && !title.isBlank() ? title : "Phòng học trực tuyến");
                classroom.setTeacherId(teacherId != null && !teacherId.isBlank() ? teacherId : "teacher_default");
                classroom.setStartedAt(sessionStartedAt);

                if (!saveOrUpdateClassroom(classroom)) {
                    return Classroom.error("Chưa lưu được buổi học vào bộ nhớ.");
                }
                if (!repository.setActiveClassroom(classroom)) {
                    List<Classroom> rollback = repository.loadAllClassrooms();
                    rollback.removeIf(c -> classroom.getId().equals(c.getId()));
                    repository.saveAllClassrooms(rollback);
                    return Classroom.error("Chưa lưu được phòng học đang mở.");
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
        return repository.getActiveClassroom();
    }

    public boolean endClassroom(String classroomId) {
        return endClassroom(classroomId, null);
    }

    public boolean endClassroom(String classroomId, JsonObject content) {
        long startedAt = System.nanoTime();
        synchronized (repository.getLock()) {
            try {
                JsonObject active = getActiveClassroom();
                List<Classroom> list = repository.loadAllClassrooms();
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
                    repository.clearActiveClassroom();
                    return true;
                }
                if (!"ONGOING".equalsIgnoreCase(target.getStatus()) ||
                        !active.has("status") || !"ONGOING".equalsIgnoreCase(active.get("status").getAsString())) return false;

                target.setStatus("COMPLETED");
                long now = System.currentTimeMillis();
                target.setEndedAt(now);
                long start = target.getStartedAt() > 0 ? target.getStartedAt() : target.getCreatedAt();
                long elapsedMs = Math.max(0, now - start);
                int duration = (int) Math.round((double) elapsedMs / 60000.0);
                target.setDurationMinutes(duration);

                if (content != null) {
                    if (!repository.saveClassroomContent(target.getId(), content)) {
                        log.warn("[classroom] Failed to persist lesson content snapshot | id={}", target.getId());
                        return false;
                    }
                    target.setHasContent(true);
                    if (content.has("pages") && content.get("pages").isJsonArray()) {
                        target.setPageCount(content.getAsJsonArray("pages").size());
                    }
                }

                if (!repository.saveAllClassrooms(list)) {
                    return false;
                }

                repository.clearActiveClassroom();
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
        return repository.getClassroomContent(id);
    }

    public boolean leaveClassroom() {
        return true;
    }

    public JsonArray getClassroomHistory(String teacherId) {
        synchronized (repository.getLock()) {
            JsonArray arr = new JsonArray();
            try {
                JsonObject active = getActiveClassroom();
                String activeId = active.has("id") ? active.get("id").getAsString() : null;

                List<Classroom> list = repository.loadAllClassrooms();
                boolean updated = false;
                for (Classroom c : list) {
                    if ("ONGOING".equalsIgnoreCase(c.getStatus()) && (activeId == null || !activeId.equals(c.getId()))) {
                        c.setStatus("COMPLETED");
                        if (c.getEndedAt() == null || c.getEndedAt() <= 0) {
                            c.setEndedAt(System.currentTimeMillis());
                            long start = c.getStartedAt() > 0 ? c.getStartedAt() : c.getCreatedAt();
                            long elapsedMs = Math.max(0, c.getEndedAt() - start);
                            c.setDurationMinutes((int) Math.round((double) elapsedMs / 60000.0));
                        }
                        c.setHasContent(repository.getClassroomContent(c.getId()) != null);
                        updated = true;
                    }

                    if ("COMPLETED".equalsIgnoreCase(c.getStatus())) {
                        if (teacherId == null || teacherId.isBlank() || teacherId.equals(c.getTeacherId())) {
                            arr.add(gson.toJsonTree(c));
                        }
                    }
                }
                if (updated) {
                    repository.saveAllClassrooms(list);
                }
            } catch (Exception e) {
                log.warn("[classroom] Failed to read history | cause={}", e.getClass().getSimpleName());
            }
            return arr;
        }
    }

    public boolean deleteClassroomHistory(String classroomId) {
        if (classroomId == null || classroomId.isBlank()) return false;
        synchronized (repository.getLock()) {
            try {
                List<Classroom> list = repository.loadAllClassrooms();
                boolean removed = list.removeIf(c -> classroomId.equals(c.getId()));
                if (removed) {
                    if (!repository.saveAllClassrooms(list)) {
                        return false;
                    }
                    repository.deleteClassroomContent(classroomId);
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
        synchronized (repository.getLock()) {
            try {
                List<Classroom> list = repository.loadAllClassrooms();
                List<Classroom> remaining = new ArrayList<>();
                List<String> deletedContentIds = new ArrayList<>();
                for (Classroom c : list) {
                    boolean matchesTeacher = teacherId == null || teacherId.isBlank() || teacherId.equals(c.getTeacherId());
                    if ("COMPLETED".equalsIgnoreCase(c.getStatus()) && matchesTeacher) {
                        deletedContentIds.add(c.getId());
                    } else {
                        remaining.add(c);
                    }
                }
                if (!repository.saveAllClassrooms(remaining)) {
                    return false;
                }
                for (String id : deletedContentIds) {
                    repository.deleteClassroomContent(id);
                }
                log.info("[classroom] All history cleared | remaining={}", remaining.size());
                return true;
            } catch (Exception e) {
                log.warn("[classroom] Failed to clear history | cause={}", e.getClass().getSimpleName());
                return false;
            }
        }
    }

    private boolean saveOrUpdateClassroom(Classroom classroom) {
        List<Classroom> list = repository.loadAllClassrooms();
        list.removeIf(c -> c.getId() != null && c.getId().equals(classroom.getId()));
        list.add(0, classroom);
        return repository.saveAllClassrooms(list);
    }
}

