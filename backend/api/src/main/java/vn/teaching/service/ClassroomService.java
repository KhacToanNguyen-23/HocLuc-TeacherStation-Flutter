package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.stereotype.Service;
import vn.teaching.model.Classroom;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

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

    public Classroom createClassroom(String directUrl, String accessToken, String title) {
        String meetUrl = directUrl;

        // Nếu chưa có link trực tiếp mà có token Google, gọi GoogleMeetService
        if ((meetUrl == null || meetUrl.isBlank()) && accessToken != null && !accessToken.isBlank()) {
            meetUrl = googleMeetService.createOfficialMeetRoom(accessToken, title);
        }

        if (meetUrl != null && !meetUrl.isBlank()) {
            Classroom classroom = new Classroom(true, meetUrl, "ready");
            saveClassroom(classroom);
            return classroom;
        }

        return Classroom.error("Chưa có đường dẫn Meet hoặc cần token ủy quyền Google");
    }

    public JsonObject getActiveClassroom() {
        Path file = dataDirectory.resolve("classroom.json");
        synchronized (fileLock) {
            try {
                if (Files.exists(file)) {
                    return JsonParser.parseString(Files.readString(file, StandardCharsets.UTF_8)).getAsJsonObject();
                }
            } catch (Exception ignored) {}
            return new JsonObject();
        }
    }

    public boolean leaveClassroom() {
        Path file = dataDirectory.resolve("classroom.json");
        synchronized (fileLock) {
            try {
                if (Files.exists(file)) {
                    Files.delete(file);
                }
                return true;
            } catch (Exception e) {
                return false;
            }
        }
    }

    private void saveClassroom(Classroom classroom) {
        Path file = dataDirectory.resolve("classroom.json");
        synchronized (fileLock) {
            try {
                Files.writeString(file, gson.toJson(classroom), StandardCharsets.UTF_8);
            } catch (Exception e) {
                System.err.println("[ClassroomService] Failed to save classroom state: " + e.getMessage());
            }
        }
    }
}
