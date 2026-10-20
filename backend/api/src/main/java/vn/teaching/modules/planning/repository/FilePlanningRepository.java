package vn.teaching.modules.planning.repository;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Repository;
import vn.teaching.modules.planning.model.Planning;

import java.io.IOException;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

@Repository
public class FilePlanningRepository implements PlanningRepository {
    private static final Logger log = LoggerFactory.getLogger(FilePlanningRepository.class);
    private final Path dataDirectory;
    private final Path planningsDir;
    private final Path indexFile;
    private final Path classroomsDir;
    private final Object fileLock = new Object();
    private final Gson gson;

    public FilePlanningRepository(Path dataDirectory, Gson gson) {
        this.dataDirectory = dataDirectory;
        this.gson = gson;
        this.planningsDir = dataDirectory.resolve("plannings");
        this.indexFile = dataDirectory.resolve("plannings.json");
        this.classroomsDir = dataDirectory.resolve("classrooms");

        synchronized (fileLock) {
            try {
                Files.createDirectories(this.planningsDir);
                Files.createDirectories(this.classroomsDir);
                if (!Files.exists(this.indexFile)) {
                    Files.writeString(this.indexFile, "[]", StandardCharsets.UTF_8);
                }
            } catch (IOException e) {
                log.warn("[planning-repo] Could not initialize planning directories: {}", e.getMessage());
            }
        }
    }

    @Override
    public List<Planning> findAll() {
        synchronized (fileLock) {
            try {
                if (Files.exists(indexFile)) {
                    String json = Files.readString(indexFile, StandardCharsets.UTF_8);
                    Type listType = new TypeToken<ArrayList<Planning>>() {}.getType();
                    List<Planning> list = gson.fromJson(json, listType);
                    if (list != null) {
                        list.sort((a, b) -> Long.compare(b.getUpdatedAt(), a.getUpdatedAt()));
                        return list;
                    }
                }
            } catch (Exception e) {
                log.warn("[planning-repo] Failed to read index | cause={}", e.getClass().getSimpleName());
            }
            return new ArrayList<>();
        }
    }

    @Override
    public boolean saveAll(List<Planning> plannings) {
        synchronized (fileLock) {
            Path tmpFile = dataDirectory.resolve("plannings.json.tmp");
            try {
                String json = gson.toJson(plannings);
                Files.writeString(tmpFile, json, StandardCharsets.UTF_8);
                try {
                    Files.move(tmpFile, indexFile, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                } catch (AtomicMoveNotSupportedException e) {
                    Files.move(tmpFile, indexFile, StandardCopyOption.REPLACE_EXISTING);
                }
                return true;
            } catch (Exception e) {
                log.error("[planning-repo] Failed to write index | cause={}", e.getClass().getSimpleName(), e);
                try {
                    Files.deleteIfExists(tmpFile);
                } catch (Exception ignored) {}
                return false;
            }
        }
    }

    @Override
    public JsonObject findContentById(String id) {
        synchronized (fileLock) {
            try {
                Path contentPath = planningsDir.resolve(id + ".json");
                if (Files.exists(contentPath)) {
                    String json = Files.readString(contentPath, StandardCharsets.UTF_8);
                    return JsonParser.parseString(json).getAsJsonObject();
                }
            } catch (Exception e) {
                log.warn("[planning-repo] Failed to read content | id={} cause={}", id, e.getClass().getSimpleName());
            }
            return null;
        }
    }

    @Override
    public boolean saveContent(String id, JsonObject content) {
        synchronized (fileLock) {
            Path contentPath = planningsDir.resolve(id + ".json");
            Path tmpPath = planningsDir.resolve(id + ".json.tmp");
            try {
                Files.writeString(tmpPath, gson.toJson(content), StandardCharsets.UTF_8);
                try {
                    Files.move(tmpPath, contentPath, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING);
                } catch (AtomicMoveNotSupportedException e) {
                    Files.move(tmpPath, contentPath, StandardCopyOption.REPLACE_EXISTING);
                }
                return true;
            } catch (Exception e) {
                log.error("[planning-repo] Failed to write content | id={} cause={}", id, e.getClass().getSimpleName(), e);
                try {
                    Files.deleteIfExists(tmpPath);
                } catch (Exception ignored) {}
                return false;
            }
        }
    }

    @Override
    public boolean deleteContentById(String id) {
        synchronized (fileLock) {
            Path contentFile = planningsDir.resolve(id + ".json");
            try {
                return Files.deleteIfExists(contentFile);
            } catch (Exception e) {
                log.warn("[planning-repo] Content cleanup failed | id={} cause={}", id, e.getClass().getSimpleName());
                return false;
            }
        }
    }

    @Override
    public boolean copyContentToClassroom(String planningId, String classroomId) {
        synchronized (fileLock) {
            try {
                Path sourceFile = planningsDir.resolve(planningId + ".json");
                Path targetFile = classroomsDir.resolve(classroomId + ".json");
                if (!Files.exists(sourceFile)) {
                    log.warn("[planning-repo] Source planning content not found | id={}", planningId);
                    return false;
                }
                Files.copy(sourceFile, targetFile, StandardCopyOption.REPLACE_EXISTING);
                return true;
            } catch (Exception e) {
                log.error("[planning-repo] Failed to copy content to classroom | cause={}", e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }

    @Override
    public boolean cloneToActiveLesson(String planningId) {
        synchronized (fileLock) {
            try {
                Path planFile = planningsDir.resolve(planningId + ".json");
                if (!Files.exists(planFile)) {
                    log.warn("[planning-repo] Clone source missing | id={}", planningId);
                    return false;
                }
                Path lessonFile = dataDirectory.resolve("lesson.json");
                Files.copy(planFile, lessonFile, StandardCopyOption.REPLACE_EXISTING);
                return true;
            } catch (Exception e) {
                log.error("[planning-repo] Failed to clone to lesson.json | cause={}", e.getClass().getSimpleName(), e);
                return false;
            }
        }
    }
}

