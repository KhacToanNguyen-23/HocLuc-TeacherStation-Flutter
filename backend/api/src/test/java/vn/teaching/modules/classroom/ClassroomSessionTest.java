package vn.teaching.modules.classroom;

import com.google.gson.Gson;
import vn.teaching.modules.classroom.service.ClassroomService;
import vn.teaching.modules.classroom.model.Classroom;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.web.server.ResponseStatusException;
import java.nio.file.Path;
import java.nio.file.Files;
import java.util.concurrent.Executors;
import static org.junit.jupiter.api.Assertions.*;

class ClassroomSessionTest {
    @TempDir Path data;
    private final String roomA="https://meet.google.com/abc-defg-hij", roomB="https://meet.google.com/klm-nopq-rst";
    @Test void sameRoomRegistrationKeepsIdAndStartTimeAndOneHistoryEntry() throws Exception {
        var service=new ClassroomService(data,new Gson());
        var first=service.createClassroom(roomA,null,"Toán",null);
        var second=service.createClassroom(roomA,null,"Toán",null);
        assertEquals(first.getId(),second.getId());
        assertEquals(first.getStartedAt(),second.getStartedAt());
        var history=com.google.gson.JsonParser.parseString(Files.readString(data.resolve("classrooms.json"))).getAsJsonArray();
        assertEquals(1,history.size());
    }
    @Test void differentRoomCannotOverwriteRunningSession() {
        var service=new ClassroomService(data,new Gson());
        var first=service.createClassroom(roomA,null,"Toán",null);
        var error=assertThrows(ResponseStatusException.class,()->service.createClassroom(roomB,null,"Lý",null));
        assertEquals(409,error.getStatusCode().value());
        assertEquals(first.getId(),service.getActiveClassroom().get("id").getAsString());
    }
    @Test void staleEndCannotCloseTheNewSession() {
        var service=new ClassroomService(data,new Gson());
        var old=service.createClassroom(roomA,null,"Toán",null);
        assertTrue(service.endClassroom(old.getId()));
        var current=service.createClassroom(roomB,null,"Lý",null);
        assertFalse(service.endClassroom(old.getId()));
        assertEquals(current.getId(),service.getActiveClassroom().get("id").getAsString());
    }
    @Test void simultaneousSameRoomCreatesOneSession() throws Exception {
        var service=new ClassroomService(data,new Gson());
        var pool=Executors.newFixedThreadPool(2);
        try {
            var a=pool.submit(()->service.createClassroom(roomA,null,"Toán",null));
            var b=pool.submit(()->service.createClassroom(roomA,null,"Toán",null));
            assertEquals(a.get().getId(),b.get().getId());
            var history=com.google.gson.JsonParser.parseString(Files.readString(data.resolve("classrooms.json"))).getAsJsonArray();
            assertEquals(1,history.size());
        } finally { pool.shutdownNow(); }
    }

    @Test void classroomCreatesAndEndsWithContentSnapshot() {
        var service = new ClassroomService(data, new Gson());
        var room = service.createClassroom(roomA, null, "Lớp 12A1 · Bài 1", "gv_toan");
        assertNotNull(room.getId());
        assertEquals(roomA, room.getMeetingUrl());
        assertEquals("ONGOING", room.getStatus());

        var content = new com.google.gson.JsonObject();
        content.addProperty("title", "Lớp 12A1 · Bài 1");
        var pages = new com.google.gson.JsonArray();
        pages.add(new com.google.gson.JsonObject());
        content.add("pages", pages);

        assertTrue(service.endClassroom(room.getId(), content));
        var retrieved = service.getClassroomContent(room.getId());
        assertNotNull(retrieved);
        assertEquals("Lớp 12A1 · Bài 1", retrieved.get("title").getAsString());

        var history = service.getClassroomHistory("gv_toan");
        assertEquals(1, history.size());
        var first = history.get(0).getAsJsonObject();
        assertEquals("COMPLETED", first.get("status").getAsString());
        assertTrue(first.get("hasContent").getAsBoolean());
    }

    @Test void orphanedOngoingClassroomIsRecoveredIntoHistory() {
        var service = new ClassroomService(data, new Gson());
        var room = service.createClassroom(roomA, null, "Hóa Học", null);
        // Simulate app crash / abrupt exit removing active_classroom without calling endClassroom
        try {
            Files.deleteIfExists(data.resolve("active_classroom.json"));
        } catch (Exception ignored) {}

        var history = service.getClassroomHistory(null);
        assertEquals(1, history.size());
        var item = history.get(0).getAsJsonObject();
        assertEquals("COMPLETED", item.get("status").getAsString());
    }

    @Test void deleteClassroomHistoryRemovesEntryAndContent() throws Exception {
        var service = new ClassroomService(data, new Gson());
        var room = service.createClassroom(roomA, null, "Toán 12", "gv_toan");
        var content = new com.google.gson.JsonObject();
        content.addProperty("title", "Toán 12");
        service.endClassroom(room.getId(), content);

        assertEquals(1, service.getClassroomHistory("gv_toan").size());
        assertTrue(Files.exists(data.resolve("classrooms").resolve(room.getId() + ".json")));

        assertTrue(service.deleteClassroomHistory(room.getId()));
        assertEquals(0, service.getClassroomHistory("gv_toan").size());
        assertFalse(Files.exists(data.resolve("classrooms").resolve(room.getId() + ".json")));
    }

    @Test void clearAllClassroomHistoryClearsCompletedSessions() {
        var service = new ClassroomService(data, new Gson());
        var room1 = service.createClassroom(roomA, null, "Toán 12", "gv_toan");
        service.endClassroom(room1.getId());
        var room2 = service.createClassroom(roomB, null, "Lý 12", "gv_toan");
        service.endClassroom(room2.getId());

        assertEquals(2, service.getClassroomHistory("gv_toan").size());
        assertTrue(service.clearAllClassroomHistory("gv_toan"));
        assertEquals(0, service.getClassroomHistory("gv_toan").size());
    }
}

