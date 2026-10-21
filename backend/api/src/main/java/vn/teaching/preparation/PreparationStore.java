package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.stereotype.Service;
import vn.teaching.service.PlanningService;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.io.*;
import java.util.*;

/** Disk-backed metadata; media bytes never enter the lesson JSON. */
@Service
public class PreparationStore {
    final Path root;
    final Gson gson;
    final PlanningService planning;
    public PreparationStore(Path dataDirectory, Gson gson, PlanningService planning) throws IOException {
        this.root=dataDirectory.resolve("preparation"); this.gson=gson; this.planning=planning;
        Files.createDirectories(root);
        if(!Files.exists(root.resolve("configuration.json")))write(root.resolve("configuration.json"),new JsonObject());
    }
    static String id() { return UUID.randomUUID().toString(); }
    static String str(JsonObject o,String key) { return o.has(key)&&!o.get(key).isJsonNull()?o.get(key).getAsString():""; }
    static int integer(JsonObject o,String key,int fallback) { return o.has(key)?o.get(key).getAsInt():fallback; }
    static void checkId(String id) { if(id==null||!id.matches("[A-Za-z0-9_-]{1,100}")) throw ExamException.bad("ID không hợp lệ."); }
    public synchronized boolean legacyAllowed(String plan,String owner){checkId(plan);JsonObject state=read(root.resolve(plan).resolve("state.json"));return !state.has("owner")||str(state,"owner").equals(owner);}
    public synchronized boolean claimed(String plan){checkId(plan);return read(root.resolve(plan).resolve("state.json")).has("owner");}
    public synchronized void claim(String plan,String owner){state(plan,owner);}
    public synchronized boolean pending(String plan){checkId(plan);JsonObject state=read(root.resolve(plan).resolve("state.json"));if(!state.has("jobs"))return false;for(JsonElement e:state.getAsJsonArray("jobs"))if(Set.of("queued","running").contains(str(e.getAsJsonObject(),"status")))return true;return false;}
    synchronized JsonObject read(Path path) {
        try { return Files.exists(path)?JsonParser.parseString(Files.readString(path)).getAsJsonObject():new JsonObject(); }
        catch(IOException e) { throw new IllegalStateException("Không đọc được dữ liệu Soạn bài.",e); }
    }
    synchronized void write(Path path,JsonObject value) {
        try { Files.createDirectories(path.getParent()); Path tmp=Files.createTempFile(path.getParent(),"write-",".tmp");
            Files.writeString(tmp,gson.toJson(value));
            try { Files.move(tmp,path,StandardCopyOption.ATOMIC_MOVE,StandardCopyOption.REPLACE_EXISTING); }
            catch(AtomicMoveNotSupportedException e) { Files.move(tmp,path,StandardCopyOption.REPLACE_EXISTING); }
        } catch(IOException e) { throw new IllegalStateException("Không lưu được dữ liệu Soạn bài.",e); }
    }
    synchronized JsonObject state(String plan,String owner) {
        checkId(plan); JsonObject lesson=planning.getPlanningContent(plan); if(lesson==null) throw ExamException.missing();
        Path path=root.resolve(plan).resolve("state.json"); JsonObject state=read(path);
        if(!state.has("owner")) {
            // Local legacy plans were single-profile teacher_default. First authenticated
            // preparation access claims this compatibility record, not a Google identity.
            var meta=planning.getAllPlannings().stream().filter(p->p.getId().equals(plan)).findFirst().orElseThrow(ExamException::missing);
            if(meta.getTeacherId()!=null&&!meta.getTeacherId().equals("teacher_default")&&!meta.getTeacherId().equals(owner)) throw ExamException.missing();
            state.addProperty("owner",owner); for(String k:List.of("sources","jobs","artifacts","publications")) state.add(k,new JsonArray());
            write(path,state);
        }
        if(!str(state,"owner").equals(owner)) throw ExamException.missing(); return state;
    }
    synchronized void saveState(String plan,JsonObject state) { checkId(plan); write(root.resolve(plan).resolve("state.json"),state); }
    synchronized JsonObject document(String plan,String owner) {
        JsonObject state=state(plan,owner),lesson=planning.getPlanningContent(plan),doc;
        if(lesson.has("preparation")) doc=lesson.getAsJsonObject("preparation").deepCopy();
        else { doc=new JsonObject(); doc.addProperty("schemaVersion",1);doc.addProperty("revision",0);
            doc.addProperty("title",str(lesson,"title"));doc.addProperty("subject",str(lesson,"subject"));
            for(String k:List.of("sections","scenes","glossary")) doc.add(k,new JsonArray()); }
        for(String k:List.of("sources","jobs","artifacts","publications")) doc.add(k,state.get(k).deepCopy());
        for(JsonElement e:doc.getAsJsonArray("jobs")){JsonObject job=e.getAsJsonObject();if(job.has("request")){JsonObject input=job.getAsJsonObject("request");for(String key:List.of("sceneId","sourceId","inputMode","language"))if(input.has(key))job.add(key,input.get(key).deepCopy());job.remove("request");}}
        doc.addProperty("ownerId",owner);
        return doc;
    }
    synchronized JsonObject update(String plan,String owner,int expected,JsonObject incoming) {
        return update(plan,owner,expected,incoming,false);
    }
    synchronized JsonObject update(String plan,String owner,int expected,JsonObject incoming,boolean allowNewBankSnapshot) {
        JsonObject current=document(plan,owner); if(integer(current,"revision",0)!=expected) throw ExamException.conflict("Bài đã thay đổi. Tải lại trước khi lưu.");
        if(incoming==null||gson.toJson(incoming).length()>1_000_000)throw ExamException.bad("Nội dung bài vượt giới hạn 1 MB.");
        JsonObject doc=incoming.deepCopy(); for(String k:List.of("sources","jobs","artifacts","publications","owner","ownerId")) doc.remove(k);
        // Class association and provenance are authored by the variants endpoint,
        // not by regular autosave or restoration of an older lesson revision.
        if(current.has("variant")) doc.add("variant",current.get("variant").deepCopy()); else doc.remove("variant");
        doc.addProperty("schemaVersion",1);doc.addProperty("revision",expected+1);
        for(String k:List.of("sections","scenes","glossary")) if(!doc.has(k)||!doc.get(k).isJsonArray()) throw ExamException.bad("Thiếu danh sách "+k);
        for(String k:List.of("sections","scenes")){if(doc.getAsJsonArray(k).size()>200)throw ExamException.bad("Quá nhiều phần/cảnh.");Set<String> ids=new HashSet<>();
            for(JsonElement e:doc.getAsJsonArray(k)){JsonObject item=e.getAsJsonObject();String id=str(item,"id");checkId(id);if(!ids.add(id))throw ExamException.bad("ID phần/cảnh bị trùng.");item.remove("imagePath");item.remove("audioPath");}}
        vn.teaching.service.TeacherCueSchema.validate(doc);
        PreparationSectionSchema.validate(doc);
        PreparationExportTemplate.blocks(doc,true);
        PreparationQuestionSchema.preserveSnapshots(current,doc,allowNewBankSnapshot);
        PreparationQuestionSchema.validate(this,plan,owner,doc);
        PreparationEvidence.validate(this,plan,owner,doc);
        PreparationSceneLocks.validate(current,doc);
        write(root.resolve(plan).resolve("revisions").resolve(expected+".json"),current);
        planning.mergePreparation(plan,expected,doc);
        return document(plan,owner);
    }
    synchronized JsonArray revisions(String plan,String owner){state(plan,owner);JsonArray list=new JsonArray();Path dir=root.resolve(plan).resolve("revisions");if(Files.isDirectory(dir))try(var files=Files.list(dir)){files.filter(p->p.getFileName().toString().matches("[0-9]+\\.json")).sorted(Comparator.reverseOrder()).forEach(p->{JsonObject doc=read(p);for(String key:List.of("jobs","sources","artifacts","publications"))doc.remove(key);list.add(doc);});}catch(IOException e){throw new IllegalStateException(e);}return list;}
    synchronized JsonObject restore(String plan,String owner,int revision,int expected){state(plan,owner);if(revision<0)throw ExamException.bad("Phiên bản không hợp lệ.");Path path=root.resolve(plan).resolve("revisions").resolve(revision+".json");if(!Files.exists(path))throw ExamException.missing();return update(plan,owner,expected,read(path),true);}
    synchronized JsonObject duplicate(String plan,String owner){
        JsonObject original=document(plan,owner),doc=original.deepCopy(),lesson=planning.getPlanningContent(plan).deepCopy();doc.addProperty("revision",0);doc.addProperty("title",str(doc,"title")+" (bản sao)");
        for(String key:List.of("jobs","sources","artifacts","publications","ownerId"))doc.remove(key);lesson.add("preparation",doc);
        var copy=planning.saveOrUpdatePlanning(null,str(doc,"title"),str(doc,"subject"),lesson);if(copy==null)throw new IllegalStateException("Không nhân bản được bài.");
        try {
            state(copy.getId(),owner);Map<String,String> remap=new HashMap<>();
            for(String group:List.of("sources","artifacts"))for(JsonElement e:original.getAsJsonArray(group)){JsonObject old=asset(str(e.getAsJsonObject(),"id"),owner);
                // A new title/class makes old exports stale, even if they were current
                // in the source lesson. Raw source/question media stay reusable.
                int copiedRevision=Set.of("source","question_image","question_private").contains(str(old,"kind"))?0:-1;
                JsonObject fresh=register(copy.getId(),owner,assetPath(old),str(old,"name"),str(old,"mimeType"),str(old,"kind"),copiedRevision,str(old,"audience").equals("teacher")?"teacher":"student");if(old.has("durationSeconds")){JsonObject indexed=asset(str(fresh,"id"),owner);indexed.add("durationSeconds",old.get("durationSeconds").deepCopy());write(root.resolve("assets").resolve(str(fresh,"id")+".json"),indexed);}remap.put(str(old,"id"),str(fresh,"id"));}
            remapReferences(doc,remap);lesson.add("preparation",doc);
            if(planning.saveOrUpdatePlanning(copy.getId(),str(doc,"title"),str(doc,"subject"),lesson)==null)throw new IllegalStateException("Không lưu được bản sao.");
            JsonObject result=document(copy.getId(),owner);result.addProperty("planningId",copy.getId());return result;
        } catch(IOException|RuntimeException error) {
            try { discardCopy(copy.getId()); } catch(Exception cleanup) { error.addSuppressed(cleanup); }
            if(error instanceof RuntimeException runtime)throw runtime;throw new IllegalStateException("Không sao chép được học liệu.",error);
        }
    }
    synchronized void discardCopy(String plan) throws IOException {
        checkId(plan);Path directory=root.resolve(plan).normalize();
        if(!directory.startsWith(root)||directory.equals(root))throw new IllegalStateException("Invalid rollback path");
        // Scan copied asset indices too: register may fail after writing an index but before state.
        Path indices=root.resolve("assets");
        if(Files.isDirectory(indices))try(var files=Files.list(indices)){for(Path path:files.filter(p->p.toString().endsWith(".json")).toList())if(str(read(path),"planId").equals(plan))Files.deleteIfExists(path);}
        if(Files.isDirectory(directory))try(var paths=Files.walk(directory)){for(Path path:paths.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(path);}
        if(!planning.deletePlanning(plan))throw new IllegalStateException("Không dọn được bài sao chép chưa hoàn tất.");
    }
    private void remapReferences(JsonElement element,Map<String,String> remap){if(element.isJsonArray())for(JsonElement e:element.getAsJsonArray())remapReferences(e,remap);
        else if(element.isJsonObject()){JsonObject object=element.getAsJsonObject();if(object.has("sourceAssetId")&&remap.containsKey(str(object,"sourceAssetId"))&&object.has("sourceRevision"))object.addProperty("sourceRevision",0);for(String key:new ArrayList<>(object.keySet())){JsonElement value=object.get(key);if(value.isJsonPrimitive()&&value.getAsJsonPrimitive().isString()&&key.endsWith("AssetId")&&remap.containsKey(value.getAsString()))object.addProperty(key,remap.get(value.getAsString()));else remapReferences(value,remap);}}}
    JsonObject asset(String id,String owner) {
        checkId(id); JsonObject asset=read(root.resolve("assets").resolve(id+".json"));
        if(!str(asset,"owner").equals(owner)) throw ExamException.missing(); return asset;
    }
    Path assetPath(JsonObject asset) {
        Path path=root.resolve(str(asset,"path")).normalize(); if(!path.startsWith(root)) throw ExamException.missing(); return path;
    }
    synchronized JsonObject register(String plan,String owner,Path file,String name,String mime,String kind,int revision) throws IOException {
        return register(plan,owner,file,name,mime,kind,revision,kind.equals("question_private")?"teacher":"student");
    }
    synchronized JsonObject register(String plan,String owner,Path file,String name,String mime,String kind,int revision,String audience) throws IOException {
        PreparationMediaValidation.quota(this,plan,owner,Files.size(file),kind.equals("source"));
        JsonObject state=state(plan,owner);String id=id();Path dest=root.resolve(plan).resolve("assets").resolve(id);
        Files.createDirectories(dest.getParent());Files.copy(file,dest,StandardCopyOption.REPLACE_EXISTING);
        JsonObject a=new JsonObject(); a.addProperty("id",id);a.addProperty("planId",plan);a.addProperty("owner",owner);a.addProperty("path",root.relativize(dest).toString());
        a.addProperty("audience",audience);a.addProperty("private",audience.equals("teacher"));a.addProperty("name",name);a.addProperty("mimeType",mime);a.addProperty("kind",kind);a.addProperty("size",Files.size(dest));a.addProperty("revision",revision);a.addProperty("url","/api/preparation/assets/"+id);
        write(root.resolve("assets").resolve(id+".json"),a);state.getAsJsonArray(kind.equals("source")?"sources":"artifacts").add(publicAsset(a));saveState(plan,state);return publicAsset(a);
    }
    JsonObject publicAsset(JsonObject asset) { JsonObject a=asset.deepCopy();a.remove("path");a.remove("owner");return a; }
}
