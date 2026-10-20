package vn.teaching.modules.planning.service;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import vn.teaching.modules.planning.model.Planning;
import vn.teaching.modules.planning.repository.FilePlanningRepository;
import vn.teaching.modules.planning.repository.PlanningRepository;

import java.io.IOException;
import java.nio.file.Path;
import java.util.List;

@Service
public class PlanningService {
    private static final Logger log = LoggerFactory.getLogger(PlanningService.class);
    private final PlanningRepository repository;

    @Autowired
    public PlanningService(PlanningRepository repository) {
        this.repository = repository;
    }

    public PlanningService(Path dataDirectory, com.google.gson.Gson gson) throws IOException {
        this(new FilePlanningRepository(dataDirectory, gson));
    }

    public List<Planning> getAllPlannings() {
        return repository.findAll();
    }

    public JsonObject getPlanningContent(String id) {
        return repository.findContentById(id);
    }

    public Planning saveOrUpdatePlanning(String id, String title, String subject, JsonObject content) {
        long startedAt = System.nanoTime();
        try {
            List<Planning> list = repository.findAll();
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
            if (target == null) {
                target = new Planning();
                target.setCreatedAt(now);
                list.add(0, target);
            }

            if (title != null && !title.isBlank()) {
                target.setTitle(title);
            }
            if (subject != null && !subject.isBlank()) {
                target.setSubject(subject);
            }
            target.setUpdatedAt(now);

            int pageCount = 1;
            if (content != null) {
                if (content.has("pages")) {
                    JsonElement pagesEl = content.get("pages");
                    if (pagesEl.isJsonArray()) {
                        JsonArray pages = pagesEl.getAsJsonArray();
                        pageCount = Math.max(1, pages.size());
                    }
                }
            } else {
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
            target.setPageCount(pageCount);

            if (!repository.saveContent(target.getId(), content)) {
                log.error("[planning] Failed to write content | id={}", target.getId());
                return null;
            }

            if (!repository.saveAll(list)) {
                return null;
            }

            log.info("[planning] Saved | id={} title='{}' duration_ms={}",
                    target.getId(), target.getTitle(), (System.nanoTime() - startedAt) / 1_000_000);
            return target;
        } catch (Exception e) {
            log.error("[planning] Failed to save | duration_ms={} cause={}",
                    (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName(), e);
            return null;
        }
    }

    public boolean deletePlanning(String id) {
        if (id == null || id.isBlank()) return false;
        long startedAt = System.nanoTime();
        try {
            List<Planning> list = repository.findAll();
            boolean removed = list.removeIf(p -> id.equals(p.getId()));
            if (!removed) {
                log.warn("[planning] Not found to delete | id={}", id);
                return false;
            }

            if (!repository.saveAll(list)) {
                return false;
            }

            repository.deleteContentById(id);
            log.info("[planning] Deleted | id={} duration_ms={}", id, (System.nanoTime() - startedAt) / 1_000_000);
            return true;
        } catch (Exception e) {
            log.error("[planning] Failed to delete | id={} duration_ms={} cause={}",
                    id, (System.nanoTime() - startedAt) / 1_000_000, e.getClass().getSimpleName(), e);
            return false;
        }
    }

    public boolean cloneToClassroom(String planningId) {
        if (planningId == null || planningId.isBlank()) return false;
        return repository.cloneToActiveLesson(planningId);
    }

    public boolean copyPlanningToClassroom(String planningId, String classroomId) {
        if (planningId == null || planningId.isBlank() || classroomId == null || classroomId.isBlank()) {
            return false;
        }
        long startedAt = System.nanoTime();
        boolean copied = repository.copyContentToClassroom(planningId, classroomId);
        if (copied) {
            log.info("[planning] Cloned to classroom | from={} to={} duration_ms={}",
                    planningId, classroomId, (System.nanoTime() - startedAt) / 1_000_000);
        }
        return copied;
    }
}

