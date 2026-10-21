package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.*;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PreparationVariantsTest {
    @TempDir Path dir;
    PreparationStore store; PreparationVariants variants; ExamRepository repo; PreparationPublishing publishing;
    String plan; ExamModels.Account teacher=new ExamModels.Account("owner","teacher@example.test","Teacher","TEACHER");
    @BeforeEach void setup() throws Exception {
        PlanningService planning=new PlanningService(dir,new Gson());
        plan=planning.saveOrUpdatePlanning(null,"Original","Subject",null).getId();
        store=new PreparationStore(dir,new Gson(),planning); repo=mock(ExamRepository.class); publishing=mock(PreparationPublishing.class);
        variants=new PreparationVariants(store,repo,mock(ExamAuth.class),publishing);
        when(repo.require("classes","class-a",ExamModels.SchoolClass.class)).thenReturn(new ExamModels.SchoolClass("class-a","owner","Class A","now"));
    }
    JsonObject input() {
        JsonObject input=new JsonObject(); input.addProperty("expectedRevision",0); input.addProperty("classKind","local"); input.addProperty("classId","class-a"); input.addProperty("adaptationNotes","Use simpler examples"); return input;
    }
    @Test void copiedExportsStayStaleEvenWhenSourceArtifactWasCurrent()throws Exception{
        Path file=dir.resolve("export.pdf");Files.writeString(file,"export with original class/title");
        store.register(plan,"owner",file,"student.pdf","application/pdf","pdf",0);
        store.register(plan,"owner",file,"teacher.pdf","application/pdf","pdf",0,"teacher");
        store.register(plan,"owner",file,"old.mp4","video/mp4","video",-1);
        JsonObject copy=variants.create(plan,teacher,null,input());
        assertEquals(0,copy.get("revision").getAsInt());
        for(JsonElement raw:copy.getAsJsonArray("artifacts"))assertEquals(-1,raw.getAsJsonObject().get("revision").getAsInt());
        assertTrue(copy.getAsJsonArray("artifacts").get(1).getAsJsonObject().get("private").getAsBoolean());
        assertEquals(0,store.document(plan,"owner").getAsJsonArray("artifacts").get(0).getAsJsonObject().get("revision").getAsInt());
    }
    @Test void independentClassSnapshotKeepsProvenanceAndRemapsAssets() throws Exception {
        Path image=dir.resolve("image.png"); Files.write(image,new byte[]{1,2,3});
        JsonObject asset=store.register(plan,"owner",image,"image.png","image/png","source",0);
        JsonObject original=store.document(plan,"owner"),scene=new JsonObject(); scene.addProperty("id","scene-a"); scene.addProperty("text","Original text"); scene.addProperty("imageAssetId",asset.get("id").getAsString()); original.getAsJsonArray("scenes").add(scene);
        JsonObject section=new JsonObject(); section.addProperty("id","section-a"); section.addProperty("teacherNotes","PRIVATE_NOTE"); original.getAsJsonArray("sections").add(section);
        store.update(plan,"owner",0,original); JsonObject input=input(); input.addProperty("expectedRevision",1);
        JsonObject copy=variants.create(plan,teacher,null,input); String id=copy.get("planningId").getAsString();
        assertNotEquals(plan,id); assertEquals(0,copy.get("revision").getAsInt());
        assertEquals("Class A",copy.getAsJsonObject("variant").getAsJsonObject("targetClass").get("name").getAsString());
        assertEquals(1,copy.getAsJsonObject("variant").get("parentRevision").getAsInt());
        assertEquals("PRIVATE_NOTE",copy.getAsJsonArray("sections").get(0).getAsJsonObject().get("teacherNotes").getAsString());
        assertTrue(copy.getAsJsonArray("jobs").isEmpty()); assertTrue(copy.getAsJsonArray("publications").isEmpty());
        String newAsset=copy.getAsJsonArray("scenes").get(0).getAsJsonObject().get("imageAssetId").getAsString();
        assertNotEquals(asset.get("id").getAsString(),newAsset); assertEquals(id,store.asset(newAsset,"owner").get("planId").getAsString());
        copy.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("text","Adapted"); store.update(id,"owner",0,copy);
        assertEquals("Original text",store.document(plan,"owner").getAsJsonArray("scenes").get(0).getAsJsonObject().get("text").getAsString());
        assertEquals(1,variants.list(plan,"owner").size()); assertThrows(ExamException.class,()->variants.list(plan,"other"));
    }
    @Test void validatesClassOwnershipAndStaleRevisionBeforeCloning() {
        when(repo.require("classes","class-a",ExamModels.SchoolClass.class)).thenReturn(new ExamModels.SchoolClass("class-a","other","Class A","now"));
        assertThrows(ExamException.class,()->variants.create(plan,teacher,null,input()));
        JsonObject stale=input(); stale.addProperty("expectedRevision",3);
        assertThrows(ExamException.class,()->variants.create(plan,teacher,null,stale));
        assertEquals(1,store.planning.getAllPlannings().size());
    }
    @Test void googleTargetMustBeReturnedByTeachersOwnCourses() {
        when(publishing.courses(teacher,"teacher@example.test")).thenReturn(Map.of("courses",List.of(Map.of("id","google-1","name","English A"))));
        JsonObject input=input(); input.addProperty("classKind","google"); input.addProperty("classId","google-1");
        JsonObject copy=variants.create(plan,teacher,"teacher@example.test",input);
        assertEquals("google",copy.getAsJsonObject("variant").getAsJsonObject("targetClass").get("kind").getAsString());
        input.addProperty("classId","not-teachers-course"); assertThrows(ExamException.class,()->variants.create(plan,teacher,"teacher@example.test",input));
    }
    @Test void autosaveAndRestoreCannotForgeProvenanceOrChangeBoundClass() {
        JsonObject copy=variants.create(plan,teacher,null,input()); String id=copy.get("planningId").getAsString();
        copy.getAsJsonObject("variant").getAsJsonObject("targetClass").addProperty("id","forged");
        store.update(id,"owner",0,copy);
        assertEquals("class-a",store.document(id,"owner").getAsJsonObject("variant").getAsJsonObject("targetClass").get("id").getAsString());
        store.restore(id,"owner",0,1);
        assertEquals("class-a",store.document(id,"owner").getAsJsonObject("variant").getAsJsonObject("targetClass").get("id").getAsString());
        JsonObject plain=store.document(plan,"owner"); plain.add("variant",copy.get("variant")); store.update(plan,"owner",0,plain);
        assertFalse(store.document(plan,"owner").has("variant"));
    }
    @Test void failedAssetCopyLeavesOriginalAndNoOrphanVariant() throws Exception {
        Path source=dir.resolve("source.png"); Files.write(source,new byte[]{1,2,3});
        JsonObject asset=store.register(plan,"owner",source,"image.png","image/png","source",0);
        Files.delete(store.assetPath(store.asset(asset.get("id").getAsString(),"owner")));
        assertThrows(IllegalStateException.class,()->variants.create(plan,teacher,null,input()));
        assertEquals(1,store.planning.getAllPlannings().size());
        assertNotNull(store.planning.getPlanningContent(plan));
        try(var directories=Files.list(store.root)) {
            assertEquals(1,directories.filter(Files::isDirectory).filter(path->!path.getFileName().toString().equals("assets")).count());
        }
    }
}
