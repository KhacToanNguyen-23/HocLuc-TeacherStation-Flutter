package vn.teaching.preparation;

import com.google.gson.*;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.TimeUnit;
import static vn.teaching.preparation.PreparationStore.*;

/** Durable capture ownership. Never signals a PID without matching its start time and output argument. */
final class PreparationRecordingJournal {
    final PreparationStore store;
    PreparationRecordingJournal(PreparationStore store){this.store=store;}
    Path path(String plan,String id){checkId(plan);checkId(id);return store.root.resolve(plan).resolve("recordings").resolve(id+".json");}
    void save(String id,PreparationRecording.Capture capture,String kind)throws Exception{
        JsonObject row=new JsonObject();row.addProperty("id",id);row.addProperty("planId",capture.plan());row.addProperty("owner",capture.owner());
        row.addProperty("kind",kind);row.addProperty("mimeType",capture.mime());row.addProperty("createdAt",Instant.now().toString());
        row.addProperty("pid",capture.process().pid());
        row.addProperty("processStartedAt",capture.process().info().startInstant().orElseThrow().toString());
        row.addProperty("command",capture.process().info().command().orElseThrow());store.write(path(capture.plan(),id),row);
    }
    List<JsonObject> list(String plan,String owner)throws Exception{
        store.state(plan,owner);Path folder=store.root.resolve(plan).resolve("recordings");if(!Files.isDirectory(folder))return List.of();
        List<JsonObject> rows=new ArrayList<>();try(var paths=Files.list(folder)){
            for(Path file:paths.filter(p->p.getFileName().toString().endsWith(".json")).toList()){
                JsonObject row=store.read(file);String id=str(row,"id");checkId(id);
                if(!file.equals(path(plan,id))||!str(row,"planId").equals(plan)||!str(row,"owner").equals(owner))continue;
                if(!Set.of("screen","microphone").contains(str(row,"kind")))continue;
                rows.add(row);
            }
        }return rows;
    }
    Path media(JsonObject row){String ext=str(row,"kind").equals("screen")?".mp4":".wav";return path(str(row,"planId"),str(row,"id")).resolveSibling(str(row,"id")+ext);}
    void stopOrphan(JsonObject row)throws Exception{
        long pid=row.has("pid")?row.get("pid").getAsLong():-1;
        if(pid<=0)return;
        Optional<ProcessHandle> found=ProcessHandle.of(pid);if(found.isEmpty()||!found.get().isAlive())return;
        ProcessHandle handle=found.get();var info=handle.info();
        if(!info.startInstant().map(Instant::toString).orElse("").equals(str(row,"processStartedAt")))return; // PID reused.
        if(!info.command().orElse("").equals(str(row,"command"))||
           Arrays.stream(info.arguments().orElse(new String[0])).noneMatch(a->a.equals(media(row).toString())))
            throw ExamException.conflict("Không xác minh được tiến trình ghi cũ. Bản thu vẫn được giữ để khôi phục.");
        handle.destroy();try{handle.onExit().get(10,TimeUnit.SECONDS);}catch(java.util.concurrent.TimeoutException e){
            handle.destroyForcibly();handle.onExit().get(5,TimeUnit.SECONDS);
        }
    }
    void remove(String plan,String id)throws Exception{Files.deleteIfExists(path(plan,id));}
}
