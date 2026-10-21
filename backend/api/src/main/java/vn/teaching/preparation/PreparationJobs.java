package vn.teaching.preparation;

import com.google.gson.*;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import static vn.teaching.preparation.PreparationStore.*;

@Service
public class PreparationJobs {
    final PreparationStore store; final Path project;
    final ExecutorService worker=Executors.newSingleThreadExecutor(r->{Thread t=new Thread(r,"preparation-worker");t.setDaemon(true);return t;});
    final Map<String,Process> processes=new ConcurrentHashMap<>();
    final Set<String> executing=ConcurrentHashMap.newKeySet();
    PreparationAuthoringApi authoringApi=new PreparationAuthoringApi();
    public PreparationJobs(PreparationStore store,Path rootDirectory) throws Exception {
        this.store=store;this.project=rootDirectory;
        // A crashed process cannot be resumed blindly. Preserve its inputs/results for explicit retry.
        if(Files.exists(store.root)) try(var files=Files.walk(store.root,2)) { files.filter(p->p.getFileName().toString().equals("state.json")).forEach(p->{
            JsonObject s=store.read(p); if(s.has("jobs")) for(JsonElement e:s.getAsJsonArray("jobs")) {JsonObject j=e.getAsJsonObject();
                if(Set.of("queued","running").contains(str(j,"status"))) {j.addProperty("status","failed");j.addProperty("error","Ứng dụng đã dừng. Có thể thử lại từ dữ liệu đã lưu.");}}
            store.write(p,s);
        }); }
    }
    Path configPath(){return store.root.resolve("configuration.json");}
    JsonObject config(){return store.read(configPath());}
    String python(){String p=str(config(),"pythonPath");if(!p.isBlank())return p;p=System.getenv("HOC_LUC_AI_PYTHON");if(p!=null&&!p.isBlank())return p;
        Path win=project.resolve("backend/ai-runtime/.venv/Scripts/python.exe");return win.toString();}
    public Map<String,Object> capabilities(){
        Path script=project.resolve("backend/ai-runtime/preparation_worker.py");
        Map<String,Object> result=new LinkedHashMap<>();result.put("pythonReady",Files.isRegularFile(Path.of(python())));result.put("workerReady",Files.isRegularFile(script));
        JsonObject publicConfig=config().deepCopy();for(String key:new ArrayList<>(publicConfig.keySet()))if(key.toLowerCase(Locale.ROOT).matches(".*(apikey|api_key|token|secret).*"))publicConfig.remove(key);
        result.put("configuration",store.gson.fromJson(publicConfig,Object.class));result.put("kinds",List.of("transcribe","author","translate","speech","render","export_pdf"));
        try {Path log=Files.createTempFile(store.root,"capabilities-",".json");
            try{ProcessBuilder pb=new ProcessBuilder(python(),script.toString(),"--capabilities");pb.environment().put("HOC_LUC_PREPARATION_CONFIG",configPath().toString());pb.environment().remove("HOCLUC_AUTHORING_API_KEY");pb.redirectOutput(log.toFile());pb.redirectError(ProcessBuilder.Redirect.DISCARD);Process p=pb.start();
                if(!p.waitFor(25,TimeUnit.SECONDS)){kill(p);throw new IllegalStateException();}if(p.exitValue()==0)result.putAll(store.gson.fromJson(Files.readString(log),Map.class));else result.put("runtimeError","Runtime chưa sẵn sàng.");
            }finally{Files.deleteIfExists(log);}
        }catch(Exception e){result.put("runtimeError","Chọn Python runtime hợp lệ trong Cài đặt.");}
        // API authoring readiness does not depend on Python or installed speech weights.
        result.put("authoring",store.gson.fromJson(authoringApi.status(config()),Object.class));
        result.put("cloudEnabled",true);
        return result;
    }
    synchronized JsonObject configure(JsonObject input){
        JsonObject result=PreparationAuthoringApi.configure(input,config());for(String key:List.of("pythonPath","ffmpegPath","modelRoot")) if(input.has(key)) {
            String value=str(input,key);if(Set.of("pythonPath","ffmpegPath").contains(key)&&!Files.isRegularFile(Path.of(value))) throw ExamException.bad("Không tìm thấy file: "+key);
            if(key.equals("modelRoot")&&!Files.isDirectory(Path.of(value)))throw ExamException.bad("Không tìm thấy thư mục model.");
            result.addProperty(key,value);
        }store.write(configPath(),result);return result;
    }
    synchronized JsonObject start(String plan,String owner,JsonObject input) {
        JsonObject doc=store.document(plan,owner);int revision=integer(input,"revision",-1);
        if(revision!=integer(doc,"revision",0))throw ExamException.conflict("Lưu bài trước khi tạo tác vụ.");
        String audience=input.has("audience")?str(input,"audience"):"student";if(!Set.of("student","teacher").contains(audience))throw ExamException.bad("Bản xuất không hợp lệ.");
        String kind=str(input,"kind");if(!Set.of("transcribe","author","translate","speech","render","export_pdf").contains(kind))throw ExamException.bad("Tác vụ không hợp lệ.");
        boolean remoteAuthor=kind.equals("author")&&!str(input,"inputMode").equals("script");
        JsonObject authoringConfiguration=null;
        if(kind.equals("author")){
            String text=str(input,"text");if(text.isBlank()||text.length()>40_000)throw ExamException.bad("Nội dung soạn bài cần có 1–40000 ký tự.");
            if(!Set.of("script","prompt").contains(str(input,"inputMode")))throw ExamException.bad("Chọn script hoặc mô tả để soạn bài.");
        }
        if(remoteAuthor){
            if(!input.has("cloudConfirmed")||!input.get("cloudConfirmed").isJsonPrimitive()||!input.getAsJsonPrimitive("cloudConfirmed").isBoolean()||!input.get("cloudConfirmed").getAsBoolean())throw ExamException.bad("Xác nhận gửi đoạn nội dung đã chọn tới API soạn bài.");
            JsonObject selected=config();
            if(!str(input,"expectedAuthoringBaseUrl").equals(str(selected,"authoringBaseUrl"))||!str(input,"expectedAuthoringModel").equals(str(selected,"authoringModel")))throw ExamException.conflict("Cấu hình API đã đổi. Kiểm tra và xác nhận lại nơi nhận nội dung.");
            if(!authoringApi.status(selected).get("ready").getAsBoolean())throw ExamException.bad("API soạn bài chưa sẵn sàng. Kiểm tra endpoint/model, API key và hostname được phép trên backend.");
            authoringConfiguration=new JsonObject();for(String key:List.of("authoringProvider","authoringBaseUrl","authoringModel"))if(selected.has(key))authoringConfiguration.add(key,selected.get(key).deepCopy());
        }
        PreparationSceneLocks.requireEditableJob(doc,input,kind);
        JsonObject job=new JsonObject();String id=id();job.addProperty("id",id);job.addProperty("kind",kind);job.addProperty("status","queued");job.addProperty("revision",revision);job.addProperty("progress",0);job.addProperty("createdAt",java.time.Instant.now().toString());
        JsonObject snapshot=doc.deepCopy();for(String key:List.of("jobs","sources","artifacts","publications"))snapshot.remove(key);
        JsonObject request=new JsonObject();for(String key:List.of("kind","revision","sourceId","text","language","voice","start","end","inputMode","sceneId","audience"))if(input.has(key))request.add(key,input.get(key).deepCopy());request.add("document",snapshot);job.add("request",request);
        if(authoringConfiguration!=null){request.add("authoringConfiguration",authoringConfiguration);request.addProperty("cloudConfirmed",true);}
        synchronized(store){JsonObject state=store.state(plan,owner);state.getAsJsonArray("jobs").add(job);store.saveState(plan,state);}
        worker.submit(()->run(plan,owner,id));return publicJob(job);
    }
    JsonObject find(String plan,String owner,String id){for(JsonElement e:store.state(plan,owner).getAsJsonArray("jobs"))if(str(e.getAsJsonObject(),"id").equals(id))return e.getAsJsonObject();throw ExamException.missing();}
    JsonObject publicJob(JsonObject j){JsonObject copy=j.deepCopy();if(j.has("request"))for(String key:List.of("sceneId","inputMode","language","sourceId"))if(j.getAsJsonObject("request").has(key))copy.add(key,j.getAsJsonObject("request").get(key));copy.remove("request");return copy;}
    synchronized JsonObject locate(String id,String owner){checkId(id);try(var dirs=Files.list(store.root)){for(Path dir:dirs.filter(Files::isDirectory).toList()){
        if(!Files.exists(dir.resolve("state.json")))continue;JsonObject s=store.read(dir.resolve("state.json"));if(!str(s,"owner").equals(owner))continue;
        for(JsonElement e:s.getAsJsonArray("jobs"))if(str(e.getAsJsonObject(),"id").equals(id)){JsonObject j=publicJob(e.getAsJsonObject());j.addProperty("planId",dir.getFileName().toString());
            if(str(j,"status").equals("running")){JsonObject progress=store.read(dir.resolve("jobs").resolve(id).resolve("progress.json"));if(progress.has("ratio")){j.addProperty("progress",Math.min(99,progress.get("ratio").getAsDouble()*100));j.add("stage",progress.get("stage"));}}
            return j;}
    }}catch(java.io.IOException e){throw new IllegalStateException(e);}throw ExamException.missing();}
    synchronized void change(String plan,String owner,String id,java.util.function.Consumer<JsonObject> fn){synchronized(store){JsonObject s=store.state(plan,owner);for(JsonElement e:s.getAsJsonArray("jobs"))if(str(e.getAsJsonObject(),"id").equals(id))fn.accept(e.getAsJsonObject());store.saveState(plan,s);}}
    synchronized JsonObject cancel(String id,String owner){JsonObject j=locate(id,owner);String plan=str(j,"planId");
        if(Set.of("queued","running").contains(str(j,"status"))){change(plan,owner,id,x->x.addProperty("status","cancelled"));kill(processes.get(id));}return locate(id,owner);}
    synchronized JsonObject retry(String id,String owner){JsonObject j=locate(id,owner);if(!Set.of("failed","cancelled").contains(str(j,"status")))throw ExamException.conflict("Tác vụ chưa thể thử lại.");
        JsonObject existing=find(str(j,"planId"),owner,id).getAsJsonObject("request");
        if(str(j,"kind").equals("author")&&!str(existing,"inputMode").equals("script"))throw ExamException.conflict("Tạo yêu cầu soạn bài mới và xác nhận lại trước khi gọi API; không tự thử lại yêu cầu có thể tính phí.");
        if(executing.contains(id))throw ExamException.conflict("Đang dừng runtime. Thử lại sau một lát.");
        String plan=str(j,"planId");change(plan,owner,id,x->{x.addProperty("status","queued");x.addProperty("progress",0);x.remove("error");});
        worker.submit(()->run(plan,owner,id));return locate(id,owner);}
    void kill(Process p){if(p!=null){p.descendants().forEach(ProcessHandle::destroyForcibly);p.destroyForcibly();}}
    void run(String plan,String owner,String id){
        executing.add(id);
        try {
            JsonObject job; synchronized(this){job=find(plan,owner,id).deepCopy();if(!str(job,"status").equals("queued"))return;change(plan,owner,id,j->{j.addProperty("status","running");j.addProperty("progress",5);});}
            JsonObject req=job.getAsJsonObject("request"),doc=req.getAsJsonObject("document");Path work=store.root.resolve(plan).resolve("jobs").resolve(id);Files.createDirectories(work);
            JsonObject output;
            if(str(job,"kind").equals("export_pdf"))output=PreparationPdf.generate(doc,work,req.has("audience")?str(req,"audience"):"student",assetId->{JsonObject a=store.asset(assetId,owner);if(!str(a,"planId").equals(plan))throw ExamException.missing();if(!str(req,"audience").equals("teacher"))requireStudentAsset(a);return store.assetPath(a);});
            else if(str(job,"kind").equals("author")&&!str(req,"inputMode").equals("script")){
                if(!req.has("authoringConfiguration")||!req.has("cloudConfirmed")||!req.get("cloudConfirmed").getAsBoolean())throw ExamException.bad("Yêu cầu cũ chưa xác nhận API. Tạo yêu cầu mới trong app.");
                change(plan,owner,id,j->{j.addProperty("stage","authoring-api");j.addProperty("progress",10);});
                output=authoringApi.author(req,req.getAsJsonObject("authoringConfiguration"),()->str(find(plan,owner,id),"status").equals("cancelled"));
            }
            else {
                JsonObject workerInput=req.deepCopy();workerInput.remove("document");workerInput.addProperty("workspace",work.toAbsolutePath().toString());workerInput.add("scenes",doc.getAsJsonArray("scenes").deepCopy());workerInput.add("glossary",doc.getAsJsonArray("glossary").deepCopy());
                if(req.has("sceneId")){JsonArray selected=new JsonArray();for(JsonElement e:workerInput.getAsJsonArray("scenes"))if(str(e.getAsJsonObject(),"id").equals(str(req,"sceneId")))selected.add(e);if(selected.isEmpty())throw ExamException.bad("Không tìm thấy cảnh.");workerInput.add("scenes",selected);}
                if(req.has("sourceId")){JsonObject asset=store.asset(str(req,"sourceId"),owner);if(!str(asset,"planId").equals(plan))throw ExamException.missing();workerInput.addProperty("sourcePath",store.assetPath(asset).toString());}
                for(JsonElement scene:workerInput.getAsJsonArray("scenes")){JsonObject sc=scene.getAsJsonObject();sc.remove("imagePath");sc.remove("audioPath");if(str(sc,"template").equals("text"))sc.addProperty("template","slide");
                    for(String kind:List.of("image","audio"))if(sc.has(kind+"AssetId")&&!str(sc,kind+"AssetId").isBlank()){JsonObject a=store.asset(str(sc,kind+"AssetId"),owner);if(!str(a,"planId").equals(plan))throw ExamException.missing();requireStudentAsset(a);sc.addProperty(kind+"Path",store.assetPath(a).toString());}}
                workerInput.addProperty("cacheDirectory",store.root.resolve(plan).resolve("render-cache").toAbsolutePath().toString());
                JsonObject conf=config();if(conf.has("ffmpegPath"))workerInput.add("ffmpegPath",conf.get("ffmpegPath"));
                Path request=work.resolve("request.json"),result=work.resolve("result.json");store.write(request,workerInput);
                ProcessBuilder pb=new ProcessBuilder(python(),project.resolve("backend/ai-runtime/preparation_worker.py").toString(),"--request",request.toString(),"--output",result.toString());
                pb.environment().put("HOC_LUC_PREPARATION_CONFIG",configPath().toString());
                pb.environment().remove("HOCLUC_AUTHORING_API_KEY");
                pb.directory(project.toFile());pb.redirectErrorStream(true);pb.redirectOutput(work.resolve("worker.log").toFile());Process p=pb.start();processes.put(id,p);
                if(str(find(plan,owner,id),"status").equals("cancelled")){kill(p);return;}
                if(!p.waitFor(2,TimeUnit.HOURS)){kill(p);throw new IllegalStateException("Tác vụ vượt giới hạn 2 giờ.");}
                if(p.exitValue()!=0||!Files.isRegularFile(result)){JsonObject err=store.read(result);throw new IllegalStateException(str(err,"error").isBlank()?"Runtime không xử lý được. Kiểm tra cấu hình/model hoặc file nguồn.":str(err,"error"));}
                output=store.read(result);
            }
            if(str(find(plan,owner,id),"status").equals("cancelled"))return;
            if(str(job,"kind").equals("author"))PreparationEvidence.markAuthorDraft(output);
            JsonArray artifacts=new JsonArray();if(output.has("artifacts"))for(JsonElement e:output.getAsJsonArray("artifacts")){JsonObject a=e.getAsJsonObject();Path file=Path.of(str(a,"path")).toAbsolutePath().normalize();
                if(!file.startsWith(work.toAbsolutePath().normalize())||!Files.isRegularFile(file))throw new IllegalStateException("Runtime trả file không hợp lệ.");
                artifacts.add(store.register(plan,owner,file,str(a,"name"),str(a,"mimeType"),str(a,"kind"),integer(job,"revision",0),str(job,"kind").equals("export_pdf")&&str(req,"audience").equals("teacher")?"teacher":"student"));}
            output.add("artifacts",artifacts);synchronized(this){if(str(find(plan,owner,id),"status").equals("cancelled"))return;
                output.addProperty("stale",integer(store.document(plan,owner),"revision",0)!=integer(job,"revision",0));
                JsonObject result=output;change(plan,owner,id,j->{j.addProperty("status","succeeded");j.addProperty("progress",100);j.add("result",result);});}
        }catch(Exception e){synchronized(this){if(!str(find(plan,owner,id),"status").equals("cancelled"))change(plan,owner,id,j->{j.addProperty("status","failed");j.addProperty("error",e.getMessage()==null?"Tác vụ thất bại.":e.getMessage());});}}
        finally{processes.remove(id);executing.remove(id);}
    }
    static void requireStudentAsset(JsonObject a){if(str(a,"kind").equals("question_private")||str(a,"audience").equals("teacher")||(a.has("private")&&a.get("private").getAsBoolean()))throw ExamException.bad("Tài liệu riêng giáo viên không thể xuất vào bản học sinh.");}
    @PreDestroy public void close(){processes.values().forEach(this::kill);worker.shutdownNow();}
}
