package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.ExamException;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import static org.junit.jupiter.api.Assertions.*;

class PreparationSectionReuseTest {
    @TempDir Path dir;
    PreparationStore store;PreparationSectionReuse reuse;String source,target;
    @BeforeEach void setup()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());source=planning.saveOrUpdatePlanning(null,"Source","Subject",null).getId();target=planning.saveOrUpdatePlanning(null,"Target","Subject",null).getId();store=new PreparationStore(dir,new Gson(),planning);reuse=new PreparationSectionReuse(store,null);
        JsonObject doc=store.document(source,"owner"),section=new JsonObject();section.addProperty("id","part-a");section.addProperty("title","Keep context");section.addProperty("body","Question");section.addProperty("teacherNotes","PRIVATE_ANSWER");doc.getAsJsonArray("sections").add(section);store.update(source,"owner",0,doc);store.document(target,"owner");
    }
    JsonObject input(){JsonObject input=new JsonObject();input.addProperty("sourcePlanningId",source);input.addProperty("sectionId","part-a");input.addProperty("sourceRevision",1);input.addProperty("expectedRevision",0);return input;}
    @Test void copiesIndependentlyAndRejectsStaleOrForeignSource()throws Exception{
        JsonObject copied=reuse.copy(target,"owner",input()),section=copied.getAsJsonArray("sections").get(0).getAsJsonObject();assertNotEquals("part-a",section.get("id").getAsString());assertEquals("PRIVATE_ANSWER",section.get("teacherNotes").getAsString());
        JsonObject bad=input();bad.addProperty("sourceRevision",0);bad.addProperty("expectedRevision",1);assertThrows(ExamException.class,()->reuse.copy(target,"owner",bad));assertThrows(ExamException.class,()->reuse.copy(target,"foreign",input()));assertEquals(1,store.document(source,"owner").get("revision").getAsInt());
    }
    @Test void remapsOwnedSourceReferenceAndRollsBackCopiedFilesOnSchemaFailure()throws Exception{
        Path image=dir.resolve("source.png");Files.write(image,new byte[]{1,2,3});JsonObject asset=store.register(source,"owner",image,"source.png","image/png","source",1);
        JsonObject doc=store.document(source,"owner"),section=doc.getAsJsonArray("sections").get(0).getAsJsonObject(),ref=new JsonObject();ref.addProperty("sourceAssetId",asset.get("id").getAsString());ref.addProperty("sourceRevision",1);JsonArray refs=new JsonArray();refs.add(ref);section.add("sourceRefs",refs);store.update(source,"owner",1,doc);
        JsonObject request=input();request.addProperty("sourceRevision",2);JsonObject copied=reuse.copy(target,"owner",request);JsonObject copiedRef=copied.getAsJsonArray("sections").get(0).getAsJsonObject().getAsJsonArray("sourceRefs").get(0).getAsJsonObject();String newId=copiedRef.get("sourceAssetId").getAsString();assertNotEquals(asset.get("id").getAsString(),newId);assertEquals(target,store.asset(newId,"owner").get("planId").getAsString());assertEquals(1,copiedRef.get("sourceRevision").getAsInt());
        JsonObject full=store.document(target,"owner");while(full.getAsJsonArray("sections").size()<200){JsonObject part=new JsonObject();part.addProperty("id","part-"+full.getAsJsonArray("sections").size());full.getAsJsonArray("sections").add(part);}store.update(target,"owner",1,full);
        byte[] state=Files.readAllBytes(store.root.resolve(target).resolve("state.json"));long files;try(var list=Files.list(store.root.resolve(target).resolve("assets"))){files=list.count();}request.addProperty("expectedRevision",2);assertThrows(ExamException.class,()->reuse.copy(target,"owner",request));assertArrayEquals(state,Files.readAllBytes(store.root.resolve(target).resolve("state.json")));try(var list=Files.list(store.root.resolve(target).resolve("assets"))){assertEquals(files,list.count());}
    }
    @Test void retainsTrustedDurationForCopiedTimedReferences()throws Exception{
        Path file=dir.resolve("source.mp4");Files.write(file,new byte[]{1,2,3});JsonObject registered=store.register(source,"owner",file,"source.mp4","video/mp4","source",1);JsonObject asset=store.asset(registered.get("id").getAsString(),"owner");asset.addProperty("durationSeconds",30.0);store.write(store.root.resolve("assets").resolve(asset.get("id").getAsString()+".json"),asset);
        JsonObject doc=store.document(source,"owner"),ref=new JsonObject();ref.addProperty("sourceAssetId",asset.get("id").getAsString());ref.addProperty("sourceRevision",1);ref.addProperty("start",5.0);ref.addProperty("end",12.0);JsonArray refs=new JsonArray();refs.add(ref);doc.getAsJsonArray("sections").get(0).getAsJsonObject().add("sourceRefs",refs);store.update(source,"owner",1,doc);
        JsonObject request=input();request.addProperty("sourceRevision",2);JsonObject copied=reuse.copy(target,"owner",request);JsonObject reference=copied.getAsJsonArray("sections").get(0).getAsJsonObject().getAsJsonArray("sourceRefs").get(0).getAsJsonObject();assertEquals(30.0,store.asset(reference.get("sourceAssetId").getAsString(),"owner").get("durationSeconds").getAsDouble());assertEquals(12.0,reference.get("end").getAsDouble());
    }
}
