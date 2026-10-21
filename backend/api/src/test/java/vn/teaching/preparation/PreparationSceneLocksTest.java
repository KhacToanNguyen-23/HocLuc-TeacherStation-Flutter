package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.ExamException;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationSceneLocksTest {
    @TempDir Path dir;
    PreparationStore store; String plan;
    @BeforeEach void setup()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","Subject",null).getId();store=new PreparationStore(dir,new Gson(),planning);
        JsonObject doc=store.document(plan,"owner"),scene=new JsonObject();scene.addProperty("id","scene-a");scene.addProperty("title","Reviewed");scene.addProperty("narration","Keep this.");scene.addProperty("locked",true);doc.getAsJsonArray("scenes").add(scene);store.update(plan,"owner",0,doc);
    }
    @Test void rejectsChangesDeletionAndSimultaneousUnlockEdit(){
        JsonObject doc=store.document(plan,"owner");doc.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("narration","Stale job");assertThrows(ExamException.class,()->store.update(plan,"owner",1,doc));
        doc.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("locked",false);assertThrows(ExamException.class,()->store.update(plan,"owner",1,doc));
        doc.add("scenes",new JsonArray());assertThrows(ExamException.class,()->store.update(plan,"owner",1,doc));
        assertEquals(1,store.document(plan,"owner").get("revision").getAsInt());
    }
    @Test void explicitUnlockThenEditWorksAndCaptionsCanBeReviewedWhileLocked(){
        JsonObject doc=store.document(plan,"owner");JsonObject scene=doc.getAsJsonArray("scenes").get(0).getAsJsonObject();scene.addProperty("audioDuration",2.1);store.update(plan,"owner",1,doc);
        doc=store.document(plan,"owner");doc.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("locked",false);store.update(plan,"owner",2,doc);
        doc=store.document(plan,"owner");doc.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("narration","Teacher edit");assertEquals(4,store.update(plan,"owner",3,doc).get("revision").getAsInt());
    }
    @Test void rejectsInvalidFlagAndTargetedGenerationButAllowsRendering(){
        JsonObject doc=store.document(plan,"owner"),input=new JsonObject();input.addProperty("sceneId","scene-a");assertThrows(ExamException.class,()->PreparationSceneLocks.requireEditableJob(doc,input,"translate"));assertDoesNotThrow(()->PreparationSceneLocks.requireEditableJob(doc,input,"render"));
        doc.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("locked","true");assertThrows(ExamException.class,()->store.update(plan,"owner",1,doc));
    }
}
