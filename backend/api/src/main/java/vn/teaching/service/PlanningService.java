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
                    JsonObject content = JsonParser.parseString(json).getAsJsonObject();
                    if (PlanningMigration.upgrade(content)) {
                        Path backup = contentPath.resolveSibling(contentPath.getFileName() + ".schema1.bak");
                        if (!Files.exists(backup)) Files.copy(contentPath, backup);
                        writeJsonSafely(contentPath, content);
                    }
                    return content;
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
                if (!content.has("preparation") && Files.exists(contentFile)) {
                    JsonObject previous = JsonParser.parseString(Files.readString(contentFile)).getAsJsonObject();
                    if (previous.has("preparation")) content.add("preparation", previous.get("preparation"));
                }
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

    /** All scopes share this physical file lock. */
    public Planning saveBoard(String id, String title, String subject, JsonObject incoming, Integer expected) {
        synchronized (fileLock) {
            JsonObject current = getPlanningContent(id);
            if (current == null) throw vn.teaching.exam.ExamException.missing();
            int revision = revision(current, "boardRevision");
            if (expected != null && revision != expected) {
                // A committed save can lose its HTTP acknowledgement. Only acknowledge
                // an identical immediate retry; never overwrite a newer board.
                if ((long) expected + 1 == revision && isCommittedBoardRetry(current, incoming)) {
                    Planning saved = getAllPlannings().stream().filter(p -> id.equals(p.getId())).findFirst().orElse(null);
                    if (saved != null && (title == null || title.isBlank() || title.equals(saved.getTitle()))
                            && (subject == null || subject.isBlank() || subject.equals(saved.getSubject()))) return saved;
                }
                throw vn.teaching.exam.ExamException.conflict("Bảng đã thay đổi. Tải lại trước khi lưu.");
            }
            if (incoming != null && incoming.has("preparationProjection"))
                throw vn.teaching.exam.ExamException.conflict("Bản trình chiếu phát sinh không thể ghi đè bảng gốc.");
            JsonObject merged = incoming == null ? current.deepCopy() : incoming.deepCopy();
            if (!merged.has("pageIds") && current.has("pageIds"))
                merged.add("pageIds",current.get("pageIds").deepCopy());
            merged.remove("preparation");
            if (current.has("preparation")) merged.add("preparation", current.get("preparation").deepCopy());
            if (merged.has("teacherCueUpdates")) {
                if (!merged.has("expectedPreparationRevision")) throw vn.teaching.exam.ExamException.bad("Thiếu phiên bản bài soạn.");
                JsonObject prep = current.has("preparation") ? current.getAsJsonObject("preparation").deepCopy() : new JsonObject();
                if (!current.has("preparation")) {
                    prep.addProperty("schemaVersion",1);
                    for(String key:List.of("title","subject"))
                        if(current.has(key))prep.add(key,current.get(key).deepCopy());
                    for(String key:List.of("sections","scenes","glossary"))prep.add(key,new JsonArray());
                }
                int prepRevision = revision(prep,"revision");
                if (merged.get("expectedPreparationRevision").getAsInt() != prepRevision)
                    throw vn.teaching.exam.ExamException.conflict("Ghi chú đã thay đổi. Tải lại trước khi lưu.");
                if (!merged.get("teacherCueUpdates").isJsonArray() || merged.get("teacherCueUpdates").toString().length()>500000)
                    throw vn.teaching.exam.ExamException.bad("Ghi chú giáo viên không hợp lệ.");
                prep.add("teacherCues",merged.get("teacherCueUpdates").deepCopy());
                TeacherCueSchema.validate(prep);
                prep.addProperty("revision",prepRevision+1); merged.add("preparation",prep);
            }
            merged.remove("teacherCueUpdates"); merged.remove("expectedPreparationRevision");
            merged.addProperty("boardRevision", revision + 1);
            PlanningMigration.upgrade(merged);
            if (current.has("preparation")) {
                JsonObject prep=current.getAsJsonObject("preparation");
                if(prep.has("title")) {title=prep.get("title").getAsString();merged.addProperty("title",title);}
                if(prep.has("subject")) {subject=prep.get("subject").getAsString();merged.addProperty("subject",subject);}
            }
            return saveOrUpdatePlanning(id, title, subject, merged);
        }
    }

    private static boolean isCommittedBoardRetry(JsonObject current, JsonObject incoming) {
        if (incoming == null || incoming.has("preparationProjection")) return false;
        JsonObject retry = incoming.deepCopy(), committed = current.deepCopy();
        if (retry.has("teacherCueUpdates")) {
            if (!retry.has("expectedPreparationRevision") || !current.has("preparation")) return false;
            JsonObject prep = current.getAsJsonObject("preparation");
            if (!retry.get("expectedPreparationRevision").isJsonPrimitive()
                    || !retry.get("expectedPreparationRevision").getAsJsonPrimitive().isNumber()) return false;
            if ((long) retry.get("expectedPreparationRevision").getAsInt() + 1 != revision(prep, "revision")
                    || !retry.get("teacherCueUpdates").equals(prep.get("teacherCues"))) return false;
        }
        for (String field : List.of("boardRevision", "planningSchemaVersion", "preparation",
                "teacherCueUpdates", "expectedPreparationRevision")) {
            retry.remove(field); committed.remove(field);
        }
        return retry.equals(committed);
    }

    public JsonObject saveBoardResponse(String id, String title, String subject, JsonObject incoming, Integer expected) {
        synchronized(fileLock) {
            Planning saved=saveBoard(id,title,subject,incoming,expected);
            if(saved==null)return null;
            JsonObject result=gson.toJsonTree(saved).getAsJsonObject();
            result.add("boardRevision",getPlanningContent(id).get("boardRevision").deepCopy());
            return result;
        }
    }

    public JsonObject mergePreparation(String id, int expected, JsonObject document) {
        synchronized (fileLock) {
            JsonObject current = getPlanningContent(id);
            if (current == null) throw vn.teaching.exam.ExamException.missing();
            JsonObject previous = current.has("preparation") ? current.getAsJsonObject("preparation") : new JsonObject();
            if (revision(previous, "revision") != expected)
                throw vn.teaching.exam.ExamException.conflict("Bài đã thay đổi. Tải lại trước khi lưu.");
            current.add("preparation", document.deepCopy());
            for(String field:List.of("title","subject"))if(document.has(field))current.add(field,document.get(field).deepCopy());
            if (saveOrUpdatePlanning(id, document.has("title") ? document.get("title").getAsString() : null,
                    document.has("subject") ? document.get("subject").getAsString() : null, current) == null)
                throw new IllegalStateException("Không lưu được bài.");
            return current.deepCopy();
        }
    }

    private static int revision(JsonObject value, String field) {
        return value.has(field) ? value.get(field).getAsInt() : 0;
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
        return cloneContentToClassroom(planningId) != null;
    }

    public JsonObject cloneContentToClassroom(String planningId) {
        synchronized (fileLock) {
            try {
                Path planFile = planningsDir.resolve(planningId + ".json");
                if (!Files.exists(planFile)) {
                    log.warn("[planning] Clone source missing");
                    return null;
                }
                JsonObject source = getPlanningContent(planningId);
                if (source == null) return null;
                JsonObject parsed = PreparationLiveProjection.project(source);
                parsed.remove("preparation");

                // Target is active lesson file
                Path lessonFile = dataDirectory.resolve("lesson.json");
                writeJsonSafely(lessonFile, parsed);
                return parsed.deepCopy();
            } catch (Exception e) {
                log.error("[planning] Failed to clone to classroom | cause={}", e.getClass().getSimpleName());
                return null;
            }
        }
    }

    private void writeJsonSafely(Path target, JsonElement element) throws IOException {
        Path temp = target.resolveSibling(target.getFileName() + ".tmp");
        String jsonStr = gson.toJson(element);
        Files.writeString(temp, jsonStr, StandardCharsets.UTF_8);
        try {
            Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
        } catch (AtomicMoveNotSupportedException unsupported) {
            Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
        } finally {
            Files.deleteIfExists(temp);
        }
    }
}
