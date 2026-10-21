package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.stereotype.Service;
import jakarta.annotation.PreDestroy;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Explicit Windows capture. No source is recorded until the teacher selects it. */
@Service
public class PreparationRecording {
    record Capture(String owner,String plan,Path file,Process process,String mime){}
    final PreparationStore store;final PreparationJobs jobs;final Map<String,Capture> active=new ConcurrentHashMap<>();
    final PreparationRecordingJournal journal;
    public PreparationRecording(PreparationStore store,PreparationJobs jobs){this.store=store;this.jobs=jobs;this.journal=new PreparationRecordingJournal(store);}
    public boolean pending(String plan){
        checkId(plan);
        if(active.values().stream().anyMatch(c->c.plan.equals(plan)))return true;
        Path folder=store.root.resolve(plan).resolve("recordings");
        if(!Files.isDirectory(folder))return false;
        try(var files=Files.list(folder)){return files.anyMatch(p->p.getFileName().toString().endsWith(".json"));}
        catch(Exception e){throw new IllegalStateException("Không kiểm tra được bản ghi chưa lưu.",e);}
    }
    public synchronized Object list(String plan,String owner)throws Exception{
        List<Map<String,Object>> result=new ArrayList<>();
        for(JsonObject row:journal.list(plan,owner)){
            String id=str(row,"id");Capture capture=active.get(id);
            String status=capture!=null&&capture.process!=null&&capture.process.isAlive()?"recording":"recoverable";
            result.add(Map.of("id",id,"kind",str(row,"kind"),"status",status,"createdAt",str(row,"createdAt"),"maxSeconds",1800));
        }return result;
    }
    Capture locate(String id,String owner)throws Exception{
        checkId(id);Capture capture=active.get(id);if(capture!=null){if(!capture.owner.equals(owner))throw ExamException.missing();return capture;}
        // Resolve via owned plans, never accept a client path or arbitrary PID.
        for(var plan:store.planning.getAllPlannings()){
            String planId=plan.getId();Path metadata=journal.path(planId,id);if(!Files.isRegularFile(metadata))continue;
            store.state(planId,owner);JsonObject row=store.read(metadata);
            if(!str(row,"owner").equals(owner)||!str(row,"planId").equals(planId)||!str(row,"id").equals(id))throw ExamException.missing();
            if(!Set.of("screen","microphone").contains(str(row,"kind")))throw ExamException.bad("Dữ liệu bản ghi không hợp lệ.");
            journal.stopOrphan(row);capture=new Capture(owner,planId,journal.media(row),null,str(row,"kind").equals("screen")?"video/mp4":"audio/wav");
            active.put(id,capture);return capture;
        }throw ExamException.missing();
    }
    String ffmpeg(){String path=str(jobs.config(),"ffmpegPath");if(path.isBlank()||!Files.isRegularFile(Path.of(path)))throw ExamException.bad("Chọn FFmpeg trong cài đặt để ghi nguồn.");return path;}
    public Object devices()throws Exception{
        if(!System.getProperty("os.name").toLowerCase().contains("win"))return Map.of("supported",false,"devices",List.of());
        Path log=Files.createTempFile(store.root,"devices-",".log");try{Process p=new ProcessBuilder(ffmpeg(),"-hide_banner","-list_devices","true","-f","dshow","-i","dummy").redirectErrorStream(true).redirectOutput(log.toFile()).start();if(!p.waitFor(12,TimeUnit.SECONDS))jobs.kill(p);
            List<String> audio=new ArrayList<>();for(String line:Files.readAllLines(log))if(line.contains("(audio)")){int a=line.indexOf('"'),b=line.lastIndexOf('"');if(a>=0&&b>a)audio.add(line.substring(a+1,b));}
            return Map.of("supported",true,"audioDevices",audio,"screenSources",List.of("desktop"),"windows",PreparationCaptureSources.windows(store.root));
        }finally{Files.deleteIfExists(log);}
    }
    public synchronized Object start(String plan,String owner,JsonObject input)throws Exception{
        store.state(plan,owner);if(!active.isEmpty())throw ExamException.conflict("Dừng bản ghi đang chạy trước.");
        PreparationMediaValidation.quota(store,plan,owner,48_000_000,true);
        if(!input.has("confirmed")||!input.get("confirmed").getAsBoolean())throw ExamException.bad("Xác nhận nguồn muốn ghi.");
        String kind=str(input,"kind"),device=str(input,"device"),screenAudio=str(input,"audioDevice");boolean screen=kind.equals("screen");if(!screen&&!kind.equals("microphone"))throw ExamException.bad("Chọn màn hình hoặc micro.");
        if(screenAudio.length()>300)throw ExamException.bad("Tên micro không hợp lệ.");
        if(!System.getProperty("os.name").toLowerCase().contains("win"))throw ExamException.bad("Ghi nguồn hiện hỗ trợ Windows.");
        if(!screen&&(device.isBlank()||device.length()>300))throw ExamException.bad("Chọn micro.");
        String id=id();Path path=store.root.resolve(plan).resolve("recordings").resolve(id+(screen?".mp4":".wav"));Files.createDirectories(path.getParent());
        if(Files.getFileStore(path.getParent()).getUsableSpace()<150_000_000)throw ExamException.bad("Cần ít nhất 150 MB trống để ghi và lưu nguồn.");
        List<String> args=new ArrayList<>(List.of(ffmpeg(),"-hide_banner","-y"));
        if(screen){String source=PreparationCaptureSources.resolve(str(input,"source"),str(input,"sourceTitle"),str(input,"source").equals("desktop")?List.of():PreparationCaptureSources.windows(store.root));args.addAll(List.of("-f","gdigrab","-framerate","25","-i",source));
            if(screenAudio.isBlank())args.add("-an");else args.addAll(List.of("-f","dshow","-i","audio="+screenAudio,"-map","0:v:0","-map","1:a:0","-c:a","aac","-ac","1","-ar","24000"));
            args.addAll(List.of("-c:v","libx264","-preset","ultrafast","-pix_fmt","yuv420p","-movflags","+frag_keyframe+empty_moov","-frag_duration","2000000"));}
        else args.addAll(List.of("-f","dshow","-i","audio="+device,"-ac","1","-ar","16000","-c:a","pcm_s16le"));
        // FFmpeg stops and writes its trailer at the byte limit; leave headroom
        // for packet/trailer overhead so accepted sources remain below 50 MB.
        args.addAll(List.of("-t","1800","-fs","48000000","-flush_packets","1",path.toString()));Process process=new ProcessBuilder(args).redirectErrorStream(true).redirectOutput(path.resolveSibling(id+".log").toFile()).start();
        Thread.sleep(300);if(!process.isAlive()){
            Files.deleteIfExists(path);Files.deleteIfExists(path.resolveSibling(id+".log"));
            throw ExamException.bad("Không mở được nguồn ghi. Kiểm tra quyền micro/màn hình.");
        }
        Capture capture=new Capture(owner,plan,path,process,screen?"video/mp4":"audio/wav");
        try{journal.save(id,capture,kind);active.put(id,capture);}catch(Exception e){jobs.kill(process);Files.deleteIfExists(path);Files.deleteIfExists(path.resolveSibling(id+".log"));throw e;}
        return Map.of("id",id,"status","recording","kind",kind,"maxSeconds",1800,"maxBytes",50_000_000,"screenHasAudio",screen&&!screenAudio.isBlank());
    }
    public synchronized Object stop(String id,String owner)throws Exception{
        checkId(id);
        for(var plan:store.planning.getAllPlannings()){
            Path statePath=store.root.resolve(plan.getId()).resolve("state.json");
            if(!str(store.read(statePath),"owner").equals(owner))continue;
            for(JsonElement e:store.state(plan.getId(),owner).getAsJsonArray("sources"))
                if(Set.of(id+".wav",id+".mp4").contains(str(e.getAsJsonObject(),"name"))){
                    if(Files.isRegularFile(journal.path(plan.getId(),id)))finish(id,locate(id,owner));
                    return store.gson.fromJson(e,Object.class);
                }
        }
        Capture capture=locate(id,owner);
        if(capture.process!=null&&capture.process.isAlive()){capture.process.getOutputStream().write("q\n".getBytes(java.nio.charset.StandardCharsets.US_ASCII));capture.process.getOutputStream().flush();if(!capture.process.waitFor(15,TimeUnit.SECONDS)){jobs.kill(capture.process);throw ExamException.bad("Không hoàn tất file ghi. Bản thu vẫn được giữ để thử khôi phục.");}}
            if(!Files.isRegularFile(capture.file)||Files.size(capture.file)==0)throw ExamException.bad("Bản ghi không hợp lệ. Có thể bỏ bản ghi này trong app.");
            if(Files.size(capture.file)>50_000_000)throw ExamException.bad("Bản ghi vượt 50 MB. Chọn thời lượng ngắn hơn.");
            // Idempotent retry after a response was lost or a cleanup failed.
            for(JsonElement e:store.state(capture.plan,owner).getAsJsonArray("sources"))if(str(e.getAsJsonObject(),"name").equals(capture.file.getFileName().toString())){
                finish(id,capture);return store.gson.fromJson(e,Object.class);
            }
            Path recovered=remux(id,capture);
            try{Object result=store.gson.fromJson(store.register(capture.plan,owner,recovered,capture.file.getFileName().toString(),capture.mime,"source",integer(store.document(capture.plan,owner),"revision",0)),Object.class);finish(id,capture);return result;}
            finally{Files.deleteIfExists(recovered);}
    }
    Path remux(String id,Capture capture)throws Exception{
        String ext=capture.mime.equals("video/mp4")?".mp4":".wav";
        Path file=capture.file.resolveSibling(id+"-recovered"+ext),log=capture.file.resolveSibling(id+"-recovery.log");
        try{Process p=new ProcessBuilder(ffmpeg(),"-hide_banner","-y","-i",capture.file.toString(),"-map","0","-c","copy",file.toString()).redirectErrorStream(true).redirectOutput(log.toFile()).start();
            if(!p.waitFor(60,TimeUnit.SECONDS)){jobs.kill(p);throw ExamException.bad("Khôi phục bản thu quá thời gian. Nguồn gốc vẫn được giữ.");}
            if(p.exitValue()!=0||!Files.isRegularFile(file)||Files.size(file)==0)throw ExamException.bad("Không khôi phục được bản thu. Nguồn gốc vẫn được giữ; có thể thử lại hoặc bỏ trong app.");
            PreparationMediaValidation.check(file,capture.mime);return file;
        }catch(Exception e){Files.deleteIfExists(file);throw e;}
    }
    void finish(String id,Capture capture)throws Exception{
        Files.deleteIfExists(capture.file);
        Files.deleteIfExists(capture.file.resolveSibling(id+".log"));Files.deleteIfExists(capture.file.resolveSibling(id+"-recovery.log"));
        journal.remove(capture.plan,id);active.remove(id);
    }
    public synchronized Object discard(String id,String owner)throws Exception{
        Capture capture=locate(id,owner);
        if(capture.process!=null&&capture.process.isAlive())jobs.kill(capture.process);
        finish(id,capture);return Map.of("id",id,"status","discarded");
    }
    @PreDestroy public synchronized void close(){for(Capture capture:active.values())if(capture.process!=null&&capture.process.isAlive())try{
        capture.process.getOutputStream().write("q\n".getBytes(java.nio.charset.StandardCharsets.US_ASCII));capture.process.getOutputStream().flush();
        if(!capture.process.waitFor(5,TimeUnit.SECONDS))jobs.kill(capture.process);
    }catch(Exception e){jobs.kill(capture.process);}active.clear();}
}
