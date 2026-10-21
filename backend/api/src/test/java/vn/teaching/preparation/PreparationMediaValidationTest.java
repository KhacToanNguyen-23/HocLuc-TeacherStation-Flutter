package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.service.PlanningService;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import static org.junit.jupiter.api.Assertions.*;

class PreparationMediaValidationTest {
    @TempDir Path dir;
    @Test void rejectsRenamedBinaryAndMalformedScripts()throws Exception{
        Path file=dir.resolve("source");Files.writeString(file,"PK fake ZIP");
        assertThrows(ExamException.class,()->PreparationMediaValidation.check(file,"video/mp4"));
        assertThrows(ExamException.class,()->PreparationMediaValidation.check(file,"application/pdf"));
        Files.write(file,new byte[]{(byte)255,(byte)255});assertThrows(ExamException.class,()->PreparationMediaValidation.check(file,"text/plain"));
        Files.write(file,new byte[]{65,0,66});assertThrows(ExamException.class,()->PreparationMediaValidation.check(file,"text/plain"));
        Files.write(file,new byte[1_000_001]);assertThrows(ExamException.class,()->PreparationMediaValidation.check(file,"text/plain"));
        Files.writeString(file,"Bài giảng tiếng Việt",StandardCharsets.UTF_8);assertDoesNotThrow(()->PreparationMediaValidation.check(file,"text/plain"));
    }
    @Test void sourceQuotaCannotBeBypassedByRegisteringDirectly()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());String plan=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();
        PreparationStore store=new PreparationStore(dir,new Gson(),planning);Path file=dir.resolve("source");Files.writeString(file,"media");
        JsonObject asset=store.register(plan,"owner",file,"source.wav","audio/wav","source",0),state=store.state(plan,"owner");
        state.getAsJsonArray("sources").get(0).getAsJsonObject().addProperty("size",1_000_000_000L);store.saveState(plan,state);
        assertThrows(ExamException.class,()->store.register(plan,"owner",file,"again.wav","audio/wav","source",0));
        assertEquals(1,store.document(plan,"owner").getAsJsonArray("sources").size());
        assertTrue(Files.exists(store.assetPath(store.asset(asset.get("id").getAsString(),"owner"))));
    }
}
