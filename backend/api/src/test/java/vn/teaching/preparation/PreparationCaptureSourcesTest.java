package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.Test;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;

class PreparationCaptureSourcesTest {
    final JsonObject first=JsonParser.parseString("{\"source\":\"hwnd=123\",\"title\":\"Lesson\"}").getAsJsonObject();
    @Test void capturesExactHandleEvenWhenTitlesAreIdentical(){
        JsonObject second=first.deepCopy();second.addProperty("source","hwnd=456");
        assertEquals("hwnd=456",PreparationCaptureSources.resolve("hwnd=456","Lesson",List.of(first,second)));
        assertEquals("desktop",PreparationCaptureSources.resolve("desktop","",List.of()));
    }
    @Test void refusesClosedRenamedOrArbitrarySources(){
        assertThrows(RuntimeException.class,()->PreparationCaptureSources.resolve("hwnd=999","Lesson",List.of(first)));
        assertThrows(RuntimeException.class,()->PreparationCaptureSources.resolve("hwnd=123","Old title",List.of(first)));
        assertThrows(RuntimeException.class,()->PreparationCaptureSources.resolve("title=Anything","Lesson",List.of(first)));
        assertThrows(RuntimeException.class,()->PreparationCaptureSources.resolve("hwnd=123 & cmd","Lesson",List.of(first)));
    }
}
