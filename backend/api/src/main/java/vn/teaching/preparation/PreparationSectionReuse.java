package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import vn.teaching.exam.*;
import java.util.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Server-owned copies preserve provenance and remap every referenced owned asset. */
@RestController
@RequestMapping("/api/preparation")
public class PreparationSectionReuse {
    private final PreparationStore store;private final ExamAuth auth;
    public PreparationSectionReuse(PreparationStore store,ExamAuth auth){this.store=store;this.auth=auth;}
    @PostMapping("/plannings/{id}/reuse-section")
    public Object insert(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body)throws Exception{
        return store.gson.fromJson(copy(id,auth.authenticate(token).id(),store.gson.toJsonTree(body).getAsJsonObject()),Object.class);
    }
    JsonObject copy(String target,String owner,JsonObject input)throws Exception{
        synchronized(store){
            String source=str(input,"sourcePlanningId"),sectionId=str(input,"sectionId");checkId(source);checkId(sectionId);
            JsonObject current=store.document(target,owner),original=store.document(source,owner);int revision=integer(current,"revision",0);
            if(integer(input,"expectedRevision",-1)!=revision)throw ExamException.conflict("Lưu bài trước khi chèn phần.");
            JsonObject section=null;for(JsonElement e:original.getAsJsonArray("sections"))if(str(e.getAsJsonObject(),"id").equals(sectionId)){section=e.getAsJsonObject().deepCopy();break;}
            if(section==null)throw ExamException.missing();
            // A library snapshot is immutable: refuse a changed source instead of silently importing another version.
            if(integer(input,"sourceRevision",-1)!=integer(original,"revision",0))throw ExamException.conflict("Bài nguồn đã đổi. Mở bài nguồn và lưu lại phần vào thư viện.");
            PreparationMutationBackup backup=new PreparationMutationBackup(store,target,revision);
            try{
                Map<String,String> remap=new HashMap<>();Set<String> references=new LinkedHashSet<>();collect(section,references);
                for(String assetId:references){JsonObject old=store.asset(assetId,owner);if(!str(old,"planId").equals(source))throw ExamException.bad("Học liệu không thuộc bài nguồn.");
                    JsonObject fresh=store.register(target,owner,store.assetPath(old),str(old,"name"),str(old,"mimeType"),str(old,"kind"),revision+1,str(old,"audience").equals("teacher")?"teacher":"student");
                    if(old.has("durationSeconds")){JsonObject indexed=store.asset(str(fresh,"id"),owner);indexed.add("durationSeconds",old.get("durationSeconds").deepCopy());store.write(store.root.resolve("assets").resolve(str(fresh,"id")+".json"),indexed);}
                    remap.put(assetId,str(fresh,"id"));
                }
                rewrite(section,remap,revision+1);section.addProperty("id",id());current.getAsJsonArray("sections").add(section);
                return store.update(target,owner,revision,current,true);
            }catch(Exception error){try{backup.restore();}catch(Exception rollback){error.addSuppressed(rollback);}throw error;}
        }
    }
    private void collect(JsonElement element,Set<String> ids){
        if(element.isJsonArray())for(JsonElement e:element.getAsJsonArray())collect(e,ids);
        else if(element.isJsonObject())for(var entry:element.getAsJsonObject().entrySet()){JsonElement value=entry.getValue();if(entry.getKey().endsWith("AssetId")&&value.isJsonPrimitive()&&value.getAsJsonPrimitive().isString()&&!value.getAsString().isBlank())ids.add(value.getAsString());else collect(value,ids);}
    }
    private void rewrite(JsonElement element,Map<String,String> ids,int revision){
        if(element.isJsonArray())for(JsonElement e:element.getAsJsonArray())rewrite(e,ids,revision);
        else if(element.isJsonObject()){JsonObject object=element.getAsJsonObject();if(object.has("sourceAssetId")&&ids.containsKey(str(object,"sourceAssetId")))object.addProperty("sourceRevision",revision);
            for(String key:new ArrayList<>(object.keySet())){JsonElement value=object.get(key);if(key.endsWith("AssetId")&&value.isJsonPrimitive()&&value.getAsJsonPrimitive().isString()&&ids.containsKey(value.getAsString()))object.addProperty(key,ids.get(value.getAsString()));else rewrite(value,ids,revision);}}
    }
}
