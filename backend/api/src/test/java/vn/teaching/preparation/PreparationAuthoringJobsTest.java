package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.ExamException;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import java.util.function.BooleanSupplier;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PreparationAuthoringJobsTest {
    @TempDir Path dir;
    PreparationStore store;PreparationJobs jobs;PreparationAuthoringApi api;String plan;
    @BeforeEach void setup()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","Subject",null).getId();
        store=new PreparationStore(dir,new Gson(),planning);store.document(plan,"owner");jobs=new PreparationJobs(store,dir);api=mock(PreparationAuthoringApi.class);jobs.authoringApi=api;
        JsonObject ready=new JsonObject();ready.addProperty("ready",true);when(api.status(any())).thenReturn(ready);
        JsonObject config=new JsonObject();config.addProperty("authoringProvider","openai-compatible");config.addProperty("authoringBaseUrl","https://provider.example/v1");config.addProperty("authoringModel","chosen-model");config.addProperty("pythonPath",dir.resolve("not-installed.exe").toString());store.write(jobs.configPath(),config);
    }
    @AfterEach void close(){jobs.close();}
    JsonObject input(){JsonObject r=new JsonObject();r.addProperty("kind","author");r.addProperty("revision",0);r.addProperty("inputMode","prompt");r.addProperty("text","Explain the water cycle");r.addProperty("language","en");r.addProperty("cloudConfirmed",true);r.addProperty("expectedAuthoringBaseUrl","https://provider.example/v1");r.addProperty("expectedAuthoringModel","chosen-model");return r;}
    JsonObject output(){JsonObject o=new JsonObject();o.add("sections",new JsonArray());o.add("scenes",new JsonArray());o.addProperty("method","third-party-api");return o;}
    JsonObject finished(String id)throws Exception{long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(8);while(System.nanoTime()<deadline){JsonObject j=jobs.locate(id,"owner");if(!java.util.Set.of("queued","running").contains(PreparationStore.str(j,"status")))return j;Thread.sleep(20);}fail("Job did not finish");return null;}
    @Test void consentAndCurrentDestinationRequiredBeforeQueueing(){
        JsonObject r=input();r.remove("cloudConfirmed");assertThrows(ExamException.class,()->jobs.start(plan,"owner",r));
        r.addProperty("cloudConfirmed",true);r.addProperty("expectedAuthoringModel","old-model");assertThrows(ExamException.class,()->jobs.start(plan,"owner",r));
        assertEquals(0,store.document(plan,"owner").getAsJsonArray("jobs").size());verify(api,never()).author(any(),any(),any());
    }
    @Test void apiAuthoringDoesNotNeedPythonOrLocalOllama()throws Exception{
        when(api.author(any(),any(),any())).thenReturn(output());String id=PreparationStore.str(jobs.start(plan,"owner",input()),"id");
        assertEquals("succeeded",PreparationStore.str(finished(id),"status"));assertFalse(Files.exists(store.root.resolve(plan).resolve("jobs").resolve(id).resolve("request.json")));
        verify(api).author(any(),any(),any());
    }
    @Test void providerFailureIsSafeAndCannotBlindRetryPaidRequest()throws Exception{
        when(api.author(any(),any(),any())).thenThrow(new IllegalStateException("API AI từ chối yêu cầu."));String id=PreparationStore.str(jobs.start(plan,"owner",input()),"id");
        assertEquals("failed",PreparationStore.str(finished(id),"status"));assertThrows(ExamException.class,()->jobs.retry(id,"owner"));verify(api,times(1)).author(any(),any(),any());
    }
    @Test void queuedRequestRetainsTheDestinationTeacherApproved()throws Exception{
        CountDownLatch release=new CountDownLatch(1);jobs.worker.submit(()->{try{release.await(5,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();}});
        AtomicReference<JsonObject> used=new AtomicReference<>();when(api.author(any(),any(),any())).thenAnswer(call->{used.set(((JsonObject)call.getArgument(1)).deepCopy());return output();});
        String id=PreparationStore.str(jobs.start(plan,"owner",input()),"id");JsonObject changed=jobs.config();changed.addProperty("authoringBaseUrl","https://different.example/v1");changed.addProperty("authoringModel","different-model");store.write(jobs.configPath(),changed);release.countDown();
        assertEquals("succeeded",PreparationStore.str(finished(id),"status"));assertEquals("chosen-model",PreparationStore.str(used.get(),"authoringModel"));assertEquals("https://provider.example/v1",PreparationStore.str(used.get(),"authoringBaseUrl"));
    }
    @Test void cancelledRemoteRequestNeverAppliesOutput()throws Exception{
        CountDownLatch called=new CountDownLatch(1);when(api.author(any(),any(),any())).thenAnswer(call->{called.countDown();BooleanSupplier cancelled=call.getArgument(2);long end=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);while(!cancelled.getAsBoolean()&&System.nanoTime()<end)Thread.sleep(10);throw new CancellationException();});
        String id=PreparationStore.str(jobs.start(plan,"owner",input()),"id");assertTrue(called.await(5,TimeUnit.SECONDS));jobs.cancel(id,"owner");assertEquals("cancelled",PreparationStore.str(finished(id),"status"));assertFalse(jobs.locate(id,"owner").has("result"));
    }
}
