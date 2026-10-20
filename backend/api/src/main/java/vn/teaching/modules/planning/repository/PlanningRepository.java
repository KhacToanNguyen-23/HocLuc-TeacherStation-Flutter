package vn.teaching.modules.planning.repository;

import com.google.gson.JsonObject;
import vn.teaching.modules.planning.model.Planning;

import java.util.List;

public interface PlanningRepository {
    List<Planning> findAll();
    boolean saveAll(List<Planning> plannings);
    JsonObject findContentById(String id);
    boolean saveContent(String id, JsonObject content);
    boolean deleteContentById(String id);
    boolean copyContentToClassroom(String planningId, String classroomId);
    boolean cloneToActiveLesson(String planningId);
}

