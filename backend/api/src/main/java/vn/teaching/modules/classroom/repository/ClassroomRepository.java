package vn.teaching.modules.classroom.repository;

import com.google.gson.JsonObject;
import vn.teaching.modules.classroom.model.Classroom;

import java.util.List;

public interface ClassroomRepository {
    Object getLock();
    JsonObject getActiveClassroom();
    boolean setActiveClassroom(Classroom classroom);
    boolean clearActiveClassroom();
    List<Classroom> loadAllClassrooms();
    boolean saveAllClassrooms(List<Classroom> classrooms);
    JsonObject getClassroomContent(String id);
    boolean saveClassroomContent(String id, JsonObject content);
    boolean deleteClassroomContent(String id);
}

