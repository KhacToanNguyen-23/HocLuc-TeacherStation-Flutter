package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.core.io.FileSystemResource;
import org.springframework.web.multipart.MultipartFile;
import vn.teaching.exam.*;
import java.nio.file.*;
import java.util.*;

@RestController
@RequestMapping("/api/preparation")
public class PreparationController {
    final ExamAuth auth;final PreparationStore store;final PreparationJobs jobs;final PreparationPublishing publishing;final PreparationRecording recording;final PreparationComponents components;
    public PreparationController(ExamAuth auth,PreparationStore store,PreparationJobs jobs,PreparationPublishing publishing,PreparationRecording recording,PreparationComponents components){this.auth=auth;this.store=store;this.jobs=jobs;this.publishing=publishing;this.recording=recording;this.components=components;}
    String owner(String header){return auth.authenticate(header).id();}
    JsonObject json(Map<String,Object> body){return store.gson.toJsonTree(body).getAsJsonObject();}
    Object result(JsonElement e){return store.gson.fromJson(e,Object.class);}
    @GetMapping("/plannings/{id}") public Object get(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(store.document(id,owner(token)));}
    @GetMapping("/plannings/{id}/revisions") public Object revisions(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(store.revisions(id,owner(token)));}
    @PostMapping("/plannings/{id}/restore")public Object restore(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body){JsonObject b=json(body);return result(store.restore(id,owner(token),PreparationStore.integer(b,"revision",-1),PreparationStore.integer(b,"expectedRevision",-1)));}
    @PostMapping("/plannings/{id}/duplicate") public Object duplicate(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(store.duplicate(id,owner(token)));}
    @PutMapping("/plannings/{id}") public Object update(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body){JsonObject b=json(body);return result(store.update(id,owner(token),PreparationStore.integer(b,"expectedRevision",-1),b.getAsJsonObject("document")));}
    @PostMapping("/plannings/{id}/sources") public Object upload(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestParam MultipartFile file)throws Exception{
        String teacher=owner(token);store.state(id,teacher);if(file.isEmpty()||file.getSize()>50_000_000)throw ExamException.bad("Nguồn tối đa 50 MB.");
        String name=file.getOriginalFilename()==null?"source":Path.of(file.getOriginalFilename().replace('\\','/')).getFileName().toString();
        String ext=name.contains(".")?name.substring(name.lastIndexOf('.')+1).toLowerCase(Locale.ROOT):"";
        String mime=switch(ext){case "mp4"->"video/mp4";case "wav"->"audio/wav";case "mp3"->"audio/mpeg";case "pdf"->"application/pdf";case "png"->"image/png";case "jpg","jpeg"->"image/jpeg";case "txt","md"->"text/plain";default->throw ExamException.bad("Định dạng nguồn chưa hỗ trợ.");};
        Path temp=Files.createTempFile(store.root,"upload-",".tmp");try{file.transferTo(temp);PreparationMediaValidation.check(temp,mime);return result(store.register(id,teacher,temp,name,mime,"source",PreparationStore.integer(store.document(id,teacher),"revision",0)));}finally{Files.deleteIfExists(temp);}
    }
    @GetMapping("/assets/{id}") public ResponseEntity<?> asset(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){JsonObject a=store.asset(id,owner(token));return ResponseEntity.ok().contentType(MediaType.parseMediaType(PreparationStore.str(a,"mimeType"))).header("Content-Disposition","attachment; filename*=UTF-8''"+java.net.URLEncoder.encode(PreparationStore.str(a,"name"),java.nio.charset.StandardCharsets.UTF_8)).cacheControl(CacheControl.noStore()).body(new FileSystemResource(store.assetPath(a)));}
    @GetMapping("/capabilities")public Object capabilities(@RequestHeader(value="Authorization",required=false)String token){owner(token);Map<String,Object> result=new LinkedHashMap<>(jobs.capabilities());result.put("installedComponents",store.gson.fromJson(components.installed(),Object.class));return result;}
    @PutMapping("/configuration")public Object configuration(@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body){owner(token);return result(jobs.configure(json(body)));}
    @PostMapping("/plannings/{id}/jobs")public Object start(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body){return result(jobs.start(id,owner(token),json(body)));}
    @GetMapping("/plannings/{id}/jobs")public Object list(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){String owner=owner(token);JsonArray list=new JsonArray();for(JsonElement e:store.state(id,owner).getAsJsonArray("jobs"))list.add(jobs.locate(PreparationStore.str(e.getAsJsonObject(),"id"),owner));return result(list);}
    @GetMapping("/jobs/{id}")public Object job(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(jobs.locate(id,owner(token)));}
    @PostMapping("/jobs/{id}/cancel")public Object cancel(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(jobs.cancel(id,owner(token)));}
    @PostMapping("/jobs/{id}/retry")public Object retry(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token){return result(jobs.retry(id,owner(token)));}
    @GetMapping("/courses")public Object courses(@RequestHeader(value="Authorization",required=false)String token,@RequestHeader("X-Google-Teacher-Email")String email){return publishing.courses(auth.authenticate(token),email);}
    @PostMapping("/google/connect")public Object connect(@RequestHeader(value="Authorization",required=false)String token,@RequestHeader("X-Google-Teacher-Email")String email){return publishing.connect(auth.authenticate(token),email);}
    @GetMapping("/recordings/devices")public Object devices(@RequestHeader(value="Authorization",required=false)String token)throws Exception{owner(token);return recording.devices();}
    @PostMapping("/plannings/{id}/recordings")public Object record(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body)throws Exception{return recording.start(id,owner(token),json(body));}
    @GetMapping("/plannings/{id}/recordings")public Object recordings(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token)throws Exception{return recording.list(id,owner(token));}
    @PostMapping("/recordings/{id}/stop")public Object stop(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token)throws Exception{return recording.stop(id,owner(token));}
    @PostMapping("/recordings/{id}/discard")public Object discard(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token)throws Exception{return recording.discard(id,owner(token));}
    @PostMapping("/plannings/{id}/publish")public Object publish(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestHeader("X-Google-Teacher-Email")String email,@RequestBody Map<String,Object> body){return result(publishing.publish(id,auth.authenticate(token),email,json(body)));}
}
