package vn.teaching.preparation;

import com.google.gson.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import vn.teaching.exam.ExamException;
import vn.teaching.service.PlanningService;
import java.nio.file.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class PreparationRecordingRecoveryTest {
    @TempDir Path dir;
    PreparationStore store;PreparationJobs jobs;String plan;
    @BeforeEach void setup()throws Exception{
        PlanningService planning=new PlanningService(dir,new Gson());plan=planning.saveOrUpdatePlanning(null,"Lesson","Subject",null).getId();
        store=new PreparationStore(dir,new Gson(),planning);store.document(plan,"owner");jobs=mock(PreparationJobs.class);
    }
    Path pending(String id)throws Exception{
        Path folder=store.root.resolve(plan).resolve("recordings");Files.createDirectories(folder);
        Path audio=folder.resolve(id+".wav");Files.write(audio,new byte[128]);
        JsonObject row=new JsonObject();row.addProperty("id",id);row.addProperty("planId",plan);row.addProperty("owner","owner");row.addProperty("kind","microphone");row.addProperty("createdAt","2026-10-20");
        store.write(folder.resolve(id+".json"),row);return audio;
    }
    PreparationRecording recording(boolean fail){return new PreparationRecording(store,jobs){
        @Override Path remux(String id,Capture capture)throws Exception{
            if(fail)throw ExamException.bad("Simulated failed recovery");Path copy=capture.file().resolveSibling(id+"-recovered.wav");Files.copy(capture.file(),copy);return copy;
        }
    };}
    @Test void restartDiscoversPendingCaptureWithoutExposingPathsOrPid()throws Exception{
        pending("capture-one");PreparationRecording restarted=recording(false);
        assertTrue(restarted.pending(plan));String result=new Gson().toJson(restarted.list(plan,"owner"));
        assertTrue(result.contains("recoverable"));assertTrue(result.contains("capture-one"));assertFalse(result.contains("path"));assertFalse(result.contains("pid"));
        assertThrows(ExamException.class,()->restarted.list(plan,"other"));
    }
    @Test void recoveredSaveIsIndependentAndRetryDoesNotRegisterTwice()throws Exception{
        Path source=pending("capture-two");PreparationRecording restarted=recording(false);
        Object first=restarted.stop("capture-two","owner");assertNotNull(first);assertFalse(Files.exists(source));assertFalse(restarted.pending(plan));
        Object second=restarted.stop("capture-two","owner");assertEquals(new Gson().toJson(first),new Gson().toJson(second));
        assertEquals(1,store.document(plan,"owner").getAsJsonArray("sources").size());
        assertThrows(ExamException.class,()->restarted.stop("capture-two","other"));
    }
    @Test void failureKeepsOriginalAndAllowsExplicitDiscardAfterAnotherRestart()throws Exception{
        Path source=pending("capture-three");assertThrows(ExamException.class,()->recording(true).stop("capture-three","owner"));
        assertTrue(Files.exists(source));assertTrue(recording(false).pending(plan));assertEquals(0,store.document(plan,"owner").getAsJsonArray("sources").size());
        assertThrows(ExamException.class,()->recording(false).discard("capture-three","other"));assertTrue(Files.exists(source));
        recording(false).discard("capture-three","owner");assertFalse(Files.exists(source));assertFalse(recording(false).pending(plan));
    }
    @Test void reusedPidNeverSignalsUnrelatedProcess()throws Exception{
        pending("capture-four");PreparationRecordingJournal journal=new PreparationRecordingJournal(store);JsonObject row=store.read(journal.path(plan,"capture-four"));
        row.addProperty("pid",ProcessHandle.current().pid());row.addProperty("processStartedAt","1900-01-01T00:00:00Z");row.addProperty("command","unrelated");
        journal.stopOrphan(row);assertTrue(ProcessHandle.current().isAlive());
    }
    @Test void unverifiedLiveProcessFailsClosedAndRetainsCapture()throws Exception{
        Path source=pending("capture-five");PreparationRecordingJournal journal=new PreparationRecordingJournal(store);JsonObject row=store.read(journal.path(plan,"capture-five"));
        row.addProperty("pid",ProcessHandle.current().pid());row.addProperty("processStartedAt",ProcessHandle.current().info().startInstant().orElseThrow().toString());row.addProperty("command","wrong-command");
        store.write(journal.path(plan,"capture-five"),row);assertThrows(ExamException.class,()->recording(false).stop("capture-five","owner"));assertTrue(Files.exists(source));assertTrue(ProcessHandle.current().isAlive());
    }
}
