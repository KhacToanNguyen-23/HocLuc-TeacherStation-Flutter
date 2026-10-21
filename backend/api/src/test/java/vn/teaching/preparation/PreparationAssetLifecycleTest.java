package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.service.PlanningService;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationAssetLifecycleTest {
    @TempDir Path dir;PreparationStore store;String plan;String id;PreparationAssetLifecycle lifecycle;
    @BeforeEach void setup()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();
        store=new PreparationStore(dir,new Gson(),planning);Path source=dir.resolve("source");Files.writeString(source,"media");
        id=store.register(plan,"owner",source,"voice.wav","audio/wav","source",0).get("id").getAsString();
        lifecycle=new PreparationAssetLifecycle(store,null);
    }
    @Test void deletesUnusedOwnedSourceBytesButNotOtherOwners()throws Exception{
        Path file=store.assetPath(store.asset(id,"owner"));assertThrows(ExamException.class,()->lifecycle.remove(id,"other"));
        lifecycle.remove(id,"owner");assertFalse(Files.exists(file));assertEquals(0,store.document(plan,"owner").getAsJsonArray("sources").size());
        assertThrows(ExamException.class,()->store.asset(id,"owner"));
    }
    @Test void protectsSourceUsedByRevisionEvenAfterRemovingCurrentReference(){
        JsonObject doc=store.document(plan,"owner");doc.addProperty("transcriptSourceId",id);store.update(plan,"owner",0,doc);
        doc=store.document(plan,"owner");doc.remove("transcriptSourceId");store.update(plan,"owner",1,doc);
        assertThrows(ExamException.class,()->lifecycle.remove(id,"owner"));
    }
    @Test void protectsJobAndPublicationInputs(){
        JsonObject state=store.state(plan,"owner"),job=JsonParser.parseString("{\"request\":{\"sourceId\":\""+id+"\"}}").getAsJsonObject();
        state.getAsJsonArray("jobs").add(job);store.saveState(plan,state);
        assertThrows(ExamException.class,()->lifecycle.remove(id,"owner"));
        state.getAsJsonArray("jobs").remove(0);JsonObject publication=new JsonObject();JsonArray ids=new JsonArray();ids.add(id);publication.add("artifactIds",ids);
        state.getAsJsonArray("publications").add(publication);store.saveState(plan,state);
        assertThrows(ExamException.class,()->lifecycle.remove(id,"owner"));
    }
}
