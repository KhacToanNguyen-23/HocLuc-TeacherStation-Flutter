package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.ExamException;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationEvidenceTest {
    @TempDir Path dir;PreparationStore store;String plan;JsonObject source;
    @BeforeEach void setup()throws Exception {
        PlanningService planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","Subject",null).getId();
        store=new PreparationStore(dir,new Gson(),planning);Path file=dir.resolve("source.mp4");Files.writeString(file,"fixture");
        source=store.register(plan,"owner",file,"source.mp4","video/mp4","source",0);
        JsonObject index=store.asset(source.get("id").getAsString(),"owner");index.addProperty("durationSeconds",60);store.write(store.root.resolve("assets").resolve(source.get("id").getAsString()+".json"),index);
    }
    JsonObject document() {
        JsonObject doc=store.document(plan,"owner"),item=new JsonObject();item.addProperty("id","section");item.addProperty("body","Public content");
        JsonObject ref=new JsonObject();ref.addProperty("sourceAssetId",source.get("id").getAsString());ref.addProperty("sourceRevision",0);ref.addProperty("start",12.5);ref.addProperty("end",15);
        JsonArray refs=new JsonArray();refs.add(ref);item.add("sourceRefs",refs);doc.getAsJsonArray("sections").add(item);return doc;
    }
    JsonObject ref(JsonObject doc){return doc.getAsJsonArray("sections").get(0).getAsJsonObject().getAsJsonArray("sourceRefs").get(0).getAsJsonObject();}
    @Test void savesOwnedVersionedRangeAndProtectsSourceFromDeletion(){JsonObject saved=store.update(plan,"owner",0,document());assertEquals(12.5,ref(saved).get("start").getAsDouble());assertTrue(PreparationAssetLifecycle.references(saved,source.get("id").getAsString()));}
    @Test void rejectsForgedRevisionInvalidRangeAndForeignSource()throws Exception {
        JsonObject doc=document();ref(doc).addProperty("sourceRevision",1);assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
        ref(doc).addProperty("sourceRevision",0);ref(doc).addProperty("end",12);assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
        ref(doc).addProperty("end",20);String another=store.planning.saveOrUpdatePlanning(null,"Other","Subject",null).getId();Path file=dir.resolve("another.mp4");Files.writeString(file,"fixture");JsonObject foreign=store.register(another,"owner",file,"foreign.mp4","video/mp4","source",0);
        ref(doc).addProperty("sourceAssetId",foreign.get("id").getAsString());assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
    }
    @Test void rejectsPrivateArtifactsAndNonNumericTimestamps()throws Exception {
        Path file=dir.resolve("answer.png");Files.writeString(file,"fixture");JsonObject privateAsset=store.register(plan,"owner",file,"answer.png","image/png","question_private",0);
        JsonObject doc=document();ref(doc).addProperty("sourceAssetId",privateAsset.get("id").getAsString());assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
        ref(doc).addProperty("sourceAssetId",source.get("id").getAsString());ref(doc).addProperty("start","12");assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
    }
    @Test void modelCannotInventVerifiedCitations(){JsonObject output=document();PreparationEvidence.markAuthorDraft(output);JsonObject section=output.getAsJsonArray("sections").get(0).getAsJsonObject();assertTrue(section.get("aiAdded").getAsBoolean());assertTrue(section.getAsJsonArray("sourceRefs").isEmpty());}
    @Test void manualScriptConversionIsNotLabelledAiWritten(){JsonObject output=document();output.addProperty("method","manual-script");PreparationEvidence.markAuthorDraft(output);assertFalse(output.getAsJsonArray("sections").get(0).getAsJsonObject().get("aiAdded").getAsBoolean());}
    @Test void rejectsRangeBeyondActualDurationAndUnknownDuration(){
        JsonObject doc=document();ref(doc).addProperty("end",61);assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
        JsonObject index=store.asset(source.get("id").getAsString(),"owner");index.remove("durationSeconds");store.write(store.root.resolve("assets").resolve(source.get("id").getAsString()+".json"),index);
        ref(doc).addProperty("end",20);assertThrows(ExamException.class,()->store.update(plan,"owner",0,doc));
    }
}
