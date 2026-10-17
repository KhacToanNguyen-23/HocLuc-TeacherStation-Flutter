package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vn.teaching.model.Planning;

import java.io.IOException;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

@Service
public class PlanningService {
    private static final Logger log = LoggerFactory.getLogger(PlanningService.class);
    private final Path dataDirectory;
    private final Path planningsDir;
    private final Path indexFile;
    private final Object fileLock = new Object();
    private final Gson gson;

    public PlanningService(Path dataDirectory, Gson gson) throws IOException {
        this.dataDirectory = dataDirectory;
        this.gson = gson;
        this.planningsDir = dataDirectory.resolve("plannings");
        this.indexFile = dataDirectory.resolve("plannings.json");

        synchronized (fileLock) {
            Files.createDirectories(this.planningsDir);
            if (!Files.exists(this.indexFile)) {
                Files.writeString(this.indexFile, "[]", StandardCharsets.UTF_8);
            }
        }
    }

    public List<Planning> getAllPlannings() {
        long startedAt = System.nanoTime();
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
                log.warn("[planning] Failed to read index | duration_ms={} cause={}",
                        (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName());
            }
            return new ArrayList<>();
        }
    }

    public JsonObject getPlanningContent(String id) {
        long startedAt = System.nanoTime();
        synchronized (fileLock) {
            try {
                Path contentPath = planningsDir.resolve(id + ".json");
                if (Files.exists(contentPath)) {
                    String json = Files.readString(contentPath, StandardCharsets.UTF_8);
                    return JsonParser.parseString(json).getAsJsonObject();
                }
            } catch (Exception e) {
                log.warn("[planning] Failed to read content | duration_ms={} cause={}",
                        (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName());
            }
            return null;
        }
    }

    public Planning saveOrUpdatePlanning(String id, String title, String subject, JsonObject content) {
        long startedAt = System.nanoTime();
        synchronized (fileLock) {
            try {
                List<Planning> list = getAllPlannings();
                Planning target = null;
                if (id != null && !id.isBlank()) {
                    for (Planning p : list) {
                        if (id.equals(p.getId())) {
                            target = p;
                            break;
                        }
                    }
                }

                long now = System.currentTimeMillis();
                int pageCount = 1;
                if (content != null && content.has("pages") && content.get("pages").isJsonArray()) {
                    pageCount = Math.max(1, content.getAsJsonArray("pages").size());
                }

                if (target == null) {
                    target = new Planning(title, subject);
                    if (id != null && !id.isBlank()) {
                        target.setId(id);
                    }
                    target.setCreatedAt(now);
                    target.setUpdatedAt(now);
                    target.setPageCount(pageCount);
                    list.add(0, target);
                } else {
                    if (title != null && !title.isBlank()) target.setTitle(title);
                    if (subject != null && !subject.isBlank()) target.setSubject(subject);
                    target.setPageCount(pageCount);
                    target.setUpdatedAt(now);
                }

                // If content is null, generate starter lesson payload
                if (content == null) {
                    content = new JsonObject();
                    content.addProperty("title", target.getTitle());
                    content.addProperty("subject", target.getSubject());
                    content.addProperty("notes", "");
                    content.addProperty("question", "");
                    content.addProperty("page", 0);
                    JsonArray pagesArr = new JsonArray();
                    pagesArr.add(new JsonArray());
                    content.add("pages", pagesArr);
                    JsonArray titlesArr = new JsonArray();
                    titlesArr.add("Trang 1");
                    content.add("pageTitles", titlesArr);
                    content.add("stickers", new JsonObject());
                    content.add("smartChalkAnnotations", new JsonObject());
                    content.add("pdfChalkAnnotations", new JsonObject());
                }

                // Write content file
                Path contentFile = planningsDir.resolve(target.getId() + ".json");
                writeJsonSafely(contentFile, content);

                // Write metadata index
                writeJsonSafely(indexFile, gson.toJsonTree(list));

                log.info("[planning] Saved | pages={} duration_ms={}", pageCount,
                        (System.nanoTime() - startedAt) / 1_000_000);
                return target;
            } catch (Exception e) {
                log.error("[planning] Failed to save | duration_ms={} cause={}",
                        (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName());
                return null;
            }
        }
    }

    public boolean deletePlanning(String id) {
        long startedAt = System.nanoTime();
        synchronized (fileLock) {
            try {
                List<Planning> list = getAllPlannings();
                boolean removed = list.removeIf(p -> id != null && id.equals(p.getId()));
                if (removed) {
                    writeJsonSafely(indexFile, gson.toJsonTree(list));
                    Path contentFile = planningsDir.resolve(id + ".json");
                    if (Files.exists(contentFile)) {
                        Files.delete(contentFile);
                    }
                    log.info("[planning] Deleted | duration_ms={}", (System.nanoTime() - startedAt) / 1_000_000);
                    return true;
                }
            } catch (Exception e) {
                log.error("[planning] Failed to delete | duration_ms={} cause={}",
                        (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName());
            }
            return false;
        }
    }

    public boolean cloneToClassroom(String planningId) {
        synchronized (fileLock) {
            try {
                Path planFile = planningsDir.resolve(planningId + ".json");
                if (!Files.exists(planFile)) {
                    log.warn("[planning] Clone source missing");
                    return false;
                }
                String content = Files.readString(planFile, StandardCharsets.UTF_8);
                JsonObject parsed = JsonParser.parseString(content).getAsJsonObject();

                // Target is active lesson file
                Path lessonFile = dataDirectory.resolve("lesson.json");
                writeJsonSafely(lessonFile, parsed);
                return true;
            } catch (Exception e) {
                log.error("[planning] Failed to clone to classroom | cause={}", e.getClass().getSimpleName());
                return false;
            }
        }
    }

    private void writeJsonSafely(Path target, JsonElement element) throws IOException {
        Path temp = target.resolveSibling(target.getFileName() + ".tmp");
        String jsonStr = gson.toJson(element);
        Files.writeString(temp, jsonStr, StandardCharsets.UTF_8);
        try {
            Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (Exception e1) {
            try {
                Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
            } catch (Exception e2) {
                // Windows lock fallback: direct overwrite
                Files.writeString(target, jsonStr, StandardCharsets.UTF_8);
                try {
                    Files.deleteIfExists(temp);
                } catch (Exception ignored) {}
            }
        }
    }
}
