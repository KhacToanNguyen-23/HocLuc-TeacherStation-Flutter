package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import vn.teaching.exam.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import static vn.teaching.preparation.PreparationStore.*;

/** Bounded local frame capture; no URL fetching or path supplied by the client. */
@RestController
@RequestMapping("/api/preparation")
public class PreparationEvidenceController {
    final PreparationStore store;final PreparationJobs jobs;final ExamAuth auth;
    public PreparationEvidenceController(PreparationStore store,PreparationJobs jobs,ExamAuth auth){this.store=store;this.jobs=jobs;this.auth=auth;}
    @PostMapping("/plannings/{plan}/sources/{source}/probe")
    public Object probe(@PathVariable String plan,@PathVariable String source,@RequestHeader(value="Authorization",required=false)String token)throws Exception {
        String owner=auth.authenticate(token).id();JsonObject asset=owned(plan,source,owner);duration(asset);
        return store.gson.fromJson(store.publicAsset(store.asset(source,owner)),Object.class);
    }
    JsonObject owned(String plan,String source,String owner) {
        store.state(plan,owner);JsonObject asset=store.asset(source,owner);
        if(!str(asset,"planId").equals(plan)||!str(asset,"kind").equals("source"))throw ExamException.bad("Chọn nguồn thuộc bài.");return asset;
    }
    double duration(JsonObject asset)throws Exception {
        if(asset.has("durationSeconds"))return PreparationEvidence.number(asset,"durationSeconds");
        if(!str(asset,"mimeType").startsWith("audio/")&&!str(asset,"mimeType").startsWith("video/"))throw ExamException.bad("Chọn nguồn audio/video.");
        String configured=str(jobs.config(),"ffmpegPath");Path ffmpeg=Path.of(configured);
        if(configured.isBlank()||!Files.isRegularFile(ffmpeg))throw ExamException.bad("Chọn FFmpeg trong Cài đặt.");
        Path probe=ffmpeg.resolveSibling(System.getProperty("os.name").toLowerCase().contains("win")?"ffprobe.exe":"ffprobe");
        if(!Files.isRegularFile(probe))throw ExamException.bad("Cần FFprobe cạnh FFmpeg để kiểm thời lượng nguồn.");
        Path output=Files.createTempFile(store.root,"probe-",".txt");
        try {
            run(List.of(probe.toString(),"-v","error","-show_entries","format=duration","-of","default=noprint_wrappers=1:nokey=1",store.assetPath(asset).toString()),output);
            double seconds;try{seconds=Double.parseDouble(Files.readString(output).trim());}catch(Exception error){throw ExamException.bad("Không đọc được thời lượng nguồn.");}
            if(!Double.isFinite(seconds)||seconds<=0)throw ExamException.bad("Thời lượng nguồn không hợp lệ.");
            synchronized(store){JsonObject current=store.asset(str(asset,"id"),str(asset,"owner"));if(!Files.isRegularFile(store.assetPath(current)))throw ExamException.missing();current.addProperty("durationSeconds",seconds);store.write(store.root.resolve("assets").resolve(str(current,"id")+".json"),current);}
            return seconds;
        }finally{Files.deleteIfExists(output);}
    }
    @PostMapping("/plannings/{plan}/frames")
    public Object frame(@PathVariable String plan,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body)throws Exception {
        String owner=auth.authenticate(token).id();JsonObject input=store.gson.toJsonTree(body).getAsJsonObject();
        JsonObject asset=store.asset(str(input,"sourceAssetId"),owner);store.state(plan,owner);
        if(!str(asset,"planId").equals(plan)||!str(asset,"kind").equals("source")||!str(asset,"mimeType").equals("video/mp4"))throw ExamException.bad("Chọn video nguồn của bài.");
        double second=PreparationEvidence.number(input,"second");if(second<0||second>7200)throw ExamException.bad("Mốc ảnh phải nằm trong 0–7200 giây.");
        String configured=str(jobs.config(),"ffmpegPath");Path ffmpeg=Path.of(configured);
        if(configured.isBlank()||!Files.isRegularFile(ffmpeg))throw ExamException.bad("Chọn FFmpeg trong Cài đặt.");
        double sourceDuration=duration(asset);
        if(second>=sourceDuration)throw ExamException.bad("Mốc ảnh vượt thời lượng video.");
        Path work=Files.createTempDirectory(store.root,"frame-");
        try {
            Path image=work.resolve("frame.png");
            run(List.of(ffmpeg.toString(),"-hide_banner","-loglevel","error","-nostdin","-ss",Double.toString(second),"-i",store.assetPath(asset).toString(),"-frames:v","1","-vf","scale=1280:720:force_original_aspect_ratio=decrease","-threads","1","-y",image.toString()),work.resolve("ffmpeg.log"));
            if(!Files.isRegularFile(image)||Files.size(image)>10_000_000)throw ExamException.bad("Không trích được ảnh hợp lệ.");
            PreparationMediaValidation.check(image,"image/png");
            JsonObject result=store.register(plan,owner,image,"Frame "+second+"s.png","image/png","source",integer(store.document(plan,owner),"revision",0));
            return store.gson.fromJson(result,Object.class);
        }finally{try(var paths=Files.walk(work)){for(Path file:paths.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(file);}}
    }
    void run(List<String> arguments,Path log)throws Exception {
        Process process=new ProcessBuilder(arguments).redirectErrorStream(true).redirectOutput(log.toFile()).start();
        try {
            if(!process.waitFor(25,TimeUnit.SECONDS)){jobs.kill(process);process.waitFor(5,TimeUnit.SECONDS);throw ExamException.bad("Trích ảnh quá thời gian; chọn video/đoạn ngắn hơn.");}
        }catch(InterruptedException error){jobs.kill(process);try{process.waitFor(5,TimeUnit.SECONDS);}catch(InterruptedException ignored){}Thread.currentThread().interrupt();throw error;}
        if(process.exitValue()!=0)throw ExamException.bad("Không xử lý được video nguồn. Kiểm tra FFmpeg và file.");
    }
}
