package vn.teaching.modules.classroom.repository;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import vn.teaching.modules.classroom.model.Classroom;

import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;

@Repository
public class FileClassroomRepository implements ClassroomRepository {
    private static final Logger log = LoggerFactory.getLogger(FileClassroomRepository.class);
    private final Path dataDirectory;
    private final Path classroomsDir;
    private final Object fileLock = new Object();
    private final Gson gson;

    public FileClassroomRepository(Path dataDirectory, Gson gson) {
        this.dataDirectory = dataDirectory;
        this.classroomsDir = dataDirectory.resolve("classrooms");
        this.gson = gson;
        try {
            Files.createDirectories(this.classroomsDir);
        } catch (Exception e) {
            log.warn("[classroom-repo] Could not create classrooms dir: {}", e.getMessage());
        }
    }

    @Override
    public Object getLock() {
        return fileLock;
    }

    @Override
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
                log.warn("[classroom-repo] Failed to read active classroom | cause={}", e.getClass().getSimpleName());
            }
            return new JsonObject();
        }
    }

    @Override
    public boolean setActiveClassroom(Classroom classroom) {
        Path file = dataDirectory.resolve("active_classroom.json");
        synchronized (fileLock) {
            try {
                Files.writeString(file, gson.toJson(classroom), StandardCharsets.UTF_8);
                return true;
            } catch (Exception e) {
                log.error("[classroom-repo] Failed to save active classroom | cause={}",
                        e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }

    @Override
    public boolean clearActiveClassroom() {
        Path file = dataDirectory.resolve("active_classroom.json");
        synchronized (fileLock) {
            try {
                Files.deleteIfExists(file);
                return true;
            } catch (Exception e) {
                log.warn("[classroom-repo] Failed to delete active classroom file | cause={}", e.getClass().getSimpleName());
                return false;
            }
        }
    }

    @Override
    public List<Classroom> loadAllClassrooms() {
        Path file = dataDirectory.resolve("classrooms.json");
        synchronized (fileLock) {
            try {
                if (Files.exists(file)) {
                    String content = Files.readString(file, StandardCharsets.UTF_8);
                    if (!content.isBlank()) {
                        Type listType = new TypeToken<ArrayList<Classroom>>() {}.getType();
                        List<Classroom> result = gson.fromJson(content, listType);
                        if (result != null) return result;
                    }
                }
            } catch (Exception e) {
                log.warn("[classroom-repo] Failed to read classroom list | cause={}", e.getClass().getSimpleName());
            }
            return new ArrayList<>();
        }
    }

    @Override
    public boolean saveAllClassrooms(List<Classroom> list) {
        Path file = dataDirectory.resolve("classrooms.json");
        synchronized (fileLock) {
            try {
                Files.writeString(file, gson.toJson(list), StandardCharsets.UTF_8);
                return true;
            } catch (Exception e) {
                log.error("[classroom-repo] Failed to save classroom list | cause={}", e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }

    @Override
    public JsonObject getClassroomContent(String id) {
        synchronized (fileLock) {
            try {
                Path contentPath = classroomsDir.resolve(id + ".json");
                if (Files.exists(contentPath)) {
                    String json = Files.readString(contentPath, StandardCharsets.UTF_8);
                    return JsonParser.parseString(json).getAsJsonObject();
                }
            } catch (Exception e) {
                log.warn("[classroom-repo] Failed to read classroom content | id={} cause={}", id, e.getClass().getSimpleName());
            }
            return null;
        }
    }

    @Override
    public boolean saveClassroomContent(String id, JsonObject content) {
        synchronized (fileLock) {
            try {
                Path contentFile = classroomsDir.resolve(id + ".json");
                Files.writeString(contentFile, gson.toJson(content), StandardCharsets.UTF_8);
                return true;
            } catch (Exception e) {
                log.warn("[classroom-repo] Failed to write classroom content | id={} cause={}", id, e.getClass().getSimpleName());
                return false;
            }
        }
    }

    @Override
    public boolean deleteClassroomContent(String id) {
        synchronized (fileLock) {
            try {
                Path contentFile = classroomsDir.resolve(id + ".json");
                return Files.deleteIfExists(contentFile);
            } catch (Exception e) {
                log.warn("[classroom-repo] Failed to delete classroom content | id={} cause={}", id, e.getClass().getSimpleName());
                return false;
            }
        }
    }
}

