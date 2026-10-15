package vn.teaching.service;

import com.google.gson.Gson;
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
}
