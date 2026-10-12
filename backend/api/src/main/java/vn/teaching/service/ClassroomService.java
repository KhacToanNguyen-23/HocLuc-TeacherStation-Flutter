package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
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

@Service
public class ClassroomService {
    private final Path dataDirectory;
    private final GoogleMeetService googleMeetService;
    private final Object fileLock = new Object();
    private final Gson gson;

    public ClassroomService(Path dataDirectory, Gson gson) {
        this.dataDirectory = dataDirectory;
        this.gson = gson;
        this.googleMeetService = new GoogleMeetService();
    }

    public Classroom createClassroom(String directUrl, String accessToken, String title, String teacherId) {
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

            saveOrUpdateClassroom(classroom);
            setActiveClassroom(classroom);
            return classroom;
        }

        return Classroom.error("Chưa có đường dẫn Meet hoặc cần token ủy quyền Google");
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
            } catch (Exception ignored) {}
            return new JsonObject();
        }
    }

    public boolean endClassroom(String classroomId) {
        synchronized (fileLock) {
            try {
                List<Classroom> list = loadAllClassrooms();
                Classroom target = null;
                for (Classroom c : list) {
                    if ((classroomId != null && classroomId.equals(c.getId())) ||
                        (classroomId == null && "ONGOING".equalsIgnoreCase(c.getStatus()))) {
                        target = c;
                        break;
                    }
                }

                if (target != null) {
                    target.setStatus("COMPLETED");
                    long now = System.currentTimeMillis();
                    target.setEndedAt(now);
                    long start = target.getStartedAt() > 0 ? target.getStartedAt() : target.getCreatedAt();
                    int duration = (int) Math.max(1, (now - start) / 60000);
                    target.setDurationMinutes(duration);
                    saveAllClassrooms(list);
                }

                // Xóa trạng thái active khi đã kết thúc hoàn toàn
                Path activeFile = dataDirectory.resolve("active_classroom.json");
                if (Files.exists(activeFile)) {
                    Files.delete(activeFile);
                }
                return true;
            } catch (Exception e) {
                System.err.println("[ClassroomService] Failed to end classroom: " + e.getMessage());
                return false;
            }
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
                List<Classroom> list = loadAllClassrooms();
                for (Classroom c : list) {
                    if ("COMPLETED".equalsIgnoreCase(c.getStatus())) {
                        if (teacherId == null || teacherId.isBlank() || teacherId.equals(c.getTeacherId())) {
                            arr.add(gson.toJsonTree(c));
                        }
                    }
                }
            } catch (Exception ignored) {}
            return arr;
        }
    }

    private void setActiveClassroom(Classroom classroom) {
        Path file = dataDirectory.resolve("active_classroom.json");
        synchronized (fileLock) {
            try {
                Files.writeString(file, gson.toJson(classroom), StandardCharsets.UTF_8);
            } catch (Exception e) {
                System.err.println("[ClassroomService] Failed to save active classroom: " + e.getMessage());
            }
        }
    }

    private void saveOrUpdateClassroom(Classroom classroom) {
        synchronized (fileLock) {
            List<Classroom> list = loadAllClassrooms();
            list.removeIf(c -> c.getId() != null && c.getId().equals(classroom.getId()));
            list.add(0, classroom);
            saveAllClassrooms(list);
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
        } catch (Exception ignored) {}
        return new ArrayList<>();
    }

    private void saveAllClassrooms(List<Classroom> list) {
        Path file = dataDirectory.resolve("classrooms.json");
        try {
            Files.writeString(file, gson.toJson(list), StandardCharsets.UTF_8);
        } catch (Exception e) {
            System.err.println("[ClassroomService] Failed to save classrooms list: " + e.getMessage());
        }
    }
}
