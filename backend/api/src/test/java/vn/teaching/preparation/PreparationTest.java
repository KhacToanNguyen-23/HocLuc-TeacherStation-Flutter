package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.service.PlanningService;
import vn.teaching.exam.*;
import vn.teaching.integrations.*;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PreparationTest {
    @TempDir Path dir;PlanningService planning;PreparationStore store;String plan;
    @BeforeEach void setup()throws Exception{planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","General",null).getId();store=new PreparationStore(dir,new Gson(),planning);}
    @Test void ownerClaimSurvivesRestartAndDeniesOtherTeacher()throws Exception{
        store.document(plan,"teacher-a");PreparationStore reloaded=new PreparationStore(dir,new Gson(),planning);
        assertThrows(ExamException.class,()->reloaded.document(plan,"teacher-b"));assertEquals(0,reloaded.document(plan,"teacher-a").get("revision").getAsInt());
    }
    @Test void optimisticRevisionAndLegacySavePreservePreparation(){
        JsonObject doc=store.document(plan,"a");JsonObject section=new JsonObject();section.addProperty("id","section-1");section.addProperty("body","Student text");section.addProperty("teacherNotes","PRIVATE_SENTINEL");doc.getAsJsonArray("sections").add(section);
        store.update(plan,"a",0,doc);assertThrows(ExamException.class,()->store.update(plan,"a",0,doc));
        JsonObject legacy=new JsonObject();legacy.addProperty("notes","legacy notes");legacy.add("pages",new JsonArray());planning.saveOrUpdatePlanning(plan,"Renamed","General",legacy);
        JsonObject saved=store.document(plan,"a");assertEquals(1,saved.get("revision").getAsInt());assertEquals("Student text",saved.getAsJsonArray("sections").get(0).getAsJsonObject().get("body").getAsString());
    }
    @Test void assetOwnershipAndBytesStayOnDisk()throws Exception{
        Path input=dir.resolve("source.wav");Files.write(input,new byte[]{1,2,3});JsonObject asset=store.register(plan,"a",input,"voice.wav","audio/wav","source",0);
        assertFalse(asset.has("path"));assertFalse(asset.has("owner"));assertThrows(ExamException.class,()->store.asset(asset.get("id").getAsString(),"b"));
        assertArrayEquals(new byte[]{1,2,3},Files.readAllBytes(store.assetPath(store.asset(asset.get("id").getAsString(),"a"))));
        assertThrows(ExamException.class,()->store.asset("../state","a"));
    }
    @Test void duplicateCopiesOwnedSceneAssetsAndRestoreCreatesNewRevision()throws Exception{
        Path image=dir.resolve("image.png");Files.write(image,new byte[]{1,2,3});JsonObject asset=store.register(plan,"a",image,"image.png","image/png","source",0),doc=store.document(plan,"a"),scene=new JsonObject();scene.addProperty("id","scene-1");scene.addProperty("imageAssetId",asset.get("id").getAsString());scene.addProperty("text","Original");doc.getAsJsonArray("scenes").add(scene);store.update(plan,"a",0,doc);
        JsonObject copy=store.duplicate(plan,"a");String copiedPlan=copy.get("planningId").getAsString(),copiedAsset=copy.getAsJsonArray("scenes").get(0).getAsJsonObject().get("imageAssetId").getAsString();assertNotEquals(asset.get("id").getAsString(),copiedAsset);assertEquals(copiedPlan,store.asset(copiedAsset,"a").get("planId").getAsString());
        JsonObject changed=store.document(plan,"a");changed.getAsJsonArray("scenes").get(0).getAsJsonObject().addProperty("text","Changed");store.update(plan,"a",1,changed);
        JsonObject restored=store.restore(plan,"a",1,2);assertEquals(3,restored.get("revision").getAsInt());assertEquals("Original",restored.getAsJsonArray("scenes").get(0).getAsJsonObject().get("text").getAsString());assertEquals(3,store.revisions(plan,"a").size());
    }
    @Test void pdfIsStudentProjection()throws Exception{
        JsonObject doc=store.document(plan,"a");JsonObject section=new JsonObject();section.addProperty("title","Visible title");section.addProperty("body","Visible lesson");section.addProperty("teacherNotes","PRIVATE_SENTINEL");doc.getAsJsonArray("sections").add(section);
        JsonObject output=PreparationPdf.generate(doc,dir);Path pdf=Path.of(output.getAsJsonArray("artifacts").get(0).getAsJsonObject().get("path").getAsString());
        try(var loaded=org.apache.pdfbox.Loader.loadPDF(pdf.toFile())){String text=new org.apache.pdfbox.text.PDFTextStripper().getText(loaded);assertTrue(text.contains("Visible lesson"));assertFalse(text.contains("PRIVATE_SENTINEL"));}
    }
    @Test void interruptedJobsBecomeExplicitlyRetryableFailure()throws Exception{
        JsonObject state=store.state(plan,"a"),job=new JsonObject();job.addProperty("id","interrupted");job.addProperty("status","running");state.getAsJsonArray("jobs").add(job);store.saveState(plan,state);
        PreparationJobs jobs=new PreparationJobs(store,dir);try{assertEquals("failed",jobs.locate("interrupted","a").get("status").getAsString());assertThrows(ExamException.class,()->jobs.locate("interrupted","b"));}finally{jobs.close();}
    }
    @Test void uncertainPublicationReconcilesInsteadOfPostingAgain()throws Exception{
        var account=new ExamModels.Account("a","teacher@example.test","Teacher","TEACHER");var gateway=mock(GoogleGateway.class);var connections=mock(GoogleConnectionService.class);var drive=mock(PreparationDrive.class);var repo=mock(ExamRepository.class);
        when(connections.access(account.email())).thenReturn("secret");when(gateway.call(eq("GET"),contains("/drive/v3/files?"),eq("secret"),isNull())).thenReturn(Map.of("files",List.of()));
        when(drive.upload(anyString(),any(),anyString(),anyString(),anyString())).thenReturn("drive-file");
        when(gateway.call(eq("POST"),contains("courseWorkMaterials"),eq("secret"),any())).thenThrow(new IllegalStateException("lost response"));
        when(gateway.call(eq("GET"),contains("courseWorkMaterials?"),eq("secret"),isNull())).thenReturn(Map.of("courseWorkMaterial",List.of(Map.of("id","remote-material","description","[HocLuc:request-1]","alternateLink","https://classroom.google.com/test"))));
        Path file=dir.resolve("student.pdf");Files.writeString(file,"student-only");JsonObject asset=store.register(plan,"a",file,"student.pdf","application/pdf","pdf",0),request=new JsonObject();request.addProperty("revision",0);request.addProperty("requestId","request-1");request.addProperty("courseId","course-1");request.addProperty("title","Lesson");JsonArray ids=new JsonArray();ids.add(asset.get("id"));request.add("artifactIds",ids);
        PreparationPublishing publishing=new PreparationPublishing(store,repo,connections,gateway,drive);
        assertEquals("uncertain",publishing.publish(plan,account,account.email(),request).get("status").getAsString());
        JsonObject reopened=request.deepCopy();reopened.addProperty("requestId","new-sheet-request");reopened.addProperty("title","  LESSON  ");
        ExamException conflict=assertThrows(ExamException.class,()->publishing.publish(plan,account,account.email(),reopened));assertEquals("PUBLICATION_RECONCILIATION_REQUIRED",conflict.code);assertTrue(conflict.getMessage().contains("request-1"));assertEquals(409,conflict.status.value());
        JsonObject edited=store.document(plan,"a");edited.addProperty("title","Edited after lost response");store.update(plan,"a",0,edited);
        JsonObject reconciled=publishing.publish(plan,account,account.email(),request);assertEquals("published",reconciled.get("status").getAsString());assertEquals("remote-material",reconciled.get("materialId").getAsString());
        assertEquals(1,store.document(plan,"a").get("revision").getAsInt());
        verify(gateway,times(1)).call(eq("POST"),contains("courseWorkMaterials"),eq("secret"),any());verify(drive,times(1)).upload(anyString(),any(),anyString(),anyString(),anyString());
    }
    @Test void cancelQueuedThenRetryDoesNotExecuteTwoRunnables()throws Exception{
        PreparationJobs jobs=new PreparationJobs(store,dir);var release=new java.util.concurrent.CountDownLatch(1);jobs.worker.submit(()->{try{release.await();}catch(InterruptedException e){Thread.currentThread().interrupt();}});
        try{JsonObject input=new JsonObject();input.addProperty("kind","export_pdf");input.addProperty("revision",0);String id=jobs.start(plan,"a",input).get("id").getAsString();jobs.cancel(id,"a");jobs.retry(id,"a");release.countDown();jobs.worker.submit(()->{}).get(20,java.util.concurrent.TimeUnit.SECONDS);
            assertEquals("succeeded",jobs.locate(id,"a").get("status").getAsString());assertEquals(1,store.document(plan,"a").getAsJsonArray("artifacts").size());
            JsonObject snapshot=jobs.find(plan,"a",id).getAsJsonObject("request").getAsJsonObject("document");for(String key:List.of("jobs","sources","artifacts","publications"))assertFalse(snapshot.has(key));assertFalse(store.document(plan,"a").getAsJsonArray("jobs").get(0).getAsJsonObject().has("request"));
        }finally{release.countDown();jobs.close();}
    }
    @Test void driveKeysAreScopedAndMissingMaterialIdsNeverMeanPublished(){
        assertNotEquals(PreparationPublishing.driveKey("plan-a","a","same",0),PreparationPublishing.driveKey("plan-b","a","same",0));
        assertNotEquals(PreparationPublishing.driveKey("plan-a","a","same",0),PreparationPublishing.driveKey("plan-a","b","same",0));
        assertThrows(IllegalStateException.class,()->PreparationPublishing.remoteId(Map.of()));assertThrows(IllegalStateException.class,()->PreparationPublishing.remoteId(Map.of("id","")));
        assertEquals("real-id",PreparationPublishing.remoteId(Map.of("id","real-id")));
        JsonArray first=new JsonArray(),second=new JsonArray();first.add("a");first.add("b");second.add("b");second.add("a");assertTrue(PreparationPublishing.sameFiles(first,second));
    }
    @Test void classroomCoursesFollowPageTokens(){
        var account=new ExamModels.Account("a","teacher@example.test","Teacher","TEACHER");GoogleGateway gateway=mock(GoogleGateway.class);GoogleConnectionService connections=mock(GoogleConnectionService.class);when(connections.access(account.email())).thenReturn("token");
        when(gateway.call(eq("GET"),contains("/courses?"),eq("token"),isNull())).thenReturn(Map.of("courses",List.of(Map.of("id","first")),"nextPageToken","next page"),Map.of("courses",List.of(Map.of("id","second"))));
        var publisher=new PreparationPublishing(store,mock(ExamRepository.class),connections,gateway,mock(PreparationDrive.class));Object result=publisher.courses(account,account.email());assertEquals(2,((List<?>)((Map<?,?>)result).get("courses")).size());verify(gateway).call(eq("GET"),contains("pageToken=next+page"),eq("token"),isNull());
    }
    @Test void jobViewExposesSafeTargetsAndLiveProgressWithoutPrivateRequest()throws Exception{
        PreparationJobs jobs=new PreparationJobs(store,dir);try{JsonObject state=store.state(plan,"a"),job=new JsonObject(),request=new JsonObject();job.addProperty("id","progress-job");job.addProperty("status","running");request.addProperty("sourceId","source-1");request.addProperty("sceneId","scene-1");request.addProperty("text","PRIVATE_INPUT");job.add("request",request);state.getAsJsonArray("jobs").add(job);store.saveState(plan,state);
            JsonObject progress=new JsonObject();progress.addProperty("ratio",.37);progress.addProperty("stage","transcribing");store.write(store.root.resolve(plan).resolve("jobs/progress-job/progress.json"),progress);
            JsonObject view=jobs.locate("progress-job","a");assertEquals("source-1",view.get("sourceId").getAsString());assertEquals("scene-1",view.get("sceneId").getAsString());assertEquals(37,view.get("progress").getAsInt());assertEquals("transcribing",view.get("stage").getAsString());assertFalse(view.has("request"));assertFalse(view.toString().contains("PRIVATE_INPUT"));
        }finally{jobs.close();}
    }
    @Test void concurrentJobAndPublicationUpdatesPreserveBothStateArrays()throws Exception{
        PreparationJobs jobs=new PreparationJobs(store,dir);JsonObject state=store.state(plan,"a"),job=new JsonObject(),publication=new JsonObject();job.addProperty("id","shared-job");job.addProperty("status","queued");publication.addProperty("requestId","shared-publish");publication.addProperty("status","uploading");state.getAsJsonArray("jobs").add(job);state.getAsJsonArray("publications").add(publication);store.saveState(plan,state);
        var publisher=new PreparationPublishing(store,mock(ExamRepository.class),mock(GoogleConnectionService.class),mock(GoogleGateway.class),mock(PreparationDrive.class));var pool=java.util.concurrent.Executors.newFixedThreadPool(2);var start=new java.util.concurrent.CountDownLatch(1);
        try{var a=pool.submit(()->{try{start.await();for(int i=0;i<25;i++){final int step=i;jobs.change(plan,"a","shared-job",j->j.addProperty("progress",step));}}catch(InterruptedException e){throw new RuntimeException(e);}});
            var b=pool.submit(()->{try{start.await();for(int i=0;i<25;i++){JsonObject next=publication.deepCopy();next.addProperty("step",i);publisher.saveJournal(plan,"a",next);}}catch(InterruptedException e){throw new RuntimeException(e);}});start.countDown();a.get(20,java.util.concurrent.TimeUnit.SECONDS);b.get(20,java.util.concurrent.TimeUnit.SECONDS);
            JsonObject finalState=store.state(plan,"a");assertEquals(24,finalState.getAsJsonArray("jobs").get(0).getAsJsonObject().get("progress").getAsInt());assertEquals(24,finalState.getAsJsonArray("publications").get(0).getAsJsonObject().get("step").getAsInt());
        }finally{pool.shutdownNow();jobs.close();}
    }
}
