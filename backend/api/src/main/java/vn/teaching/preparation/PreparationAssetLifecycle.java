package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import vn.teaching.exam.ExamAuth;
import vn.teaching.exam.ExamException;
import java.nio.file.*;
import java.util.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Removes unused source bytes; referenced lesson/job/publication inputs remain immutable. */
@RestController
@RequestMapping("/api/preparation/assets")
public class PreparationAssetLifecycle {
    final PreparationStore store;final ExamAuth auth;
    public PreparationAssetLifecycle(PreparationStore store,ExamAuth auth){this.store=store;this.auth=auth;}
    @DeleteMapping("/{id}") public Object delete(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token)throws Exception{
        return remove(id,auth.authenticate(token).id());
    }
    Object remove(String id,String owner)throws Exception{
        synchronized(store){
            JsonObject asset=store.asset(id,owner);String plan=str(asset,"planId");JsonObject state=store.state(plan,owner);
            if(references(store.document(plan,owner),id))throw ExamException.conflict("Nguồn đang dùng trong bài. Gỡ liên kết trước khi xóa.");
            Path revisions=store.root.resolve(plan).resolve("revisions");
            if(Files.isDirectory(revisions))try(var paths=Files.list(revisions)){
                for(Path path:paths.filter(p->p.getFileName().toString().endsWith(".json")).toList())
                    if(references(store.read(path),id))throw ExamException.conflict("Nguồn được dùng trong lịch sử phiên bản; giữ file để có thể khôi phục.");
            }
            for(JsonElement job:state.getAsJsonArray("jobs"))if(contains(job.getAsJsonObject().get("request"),id))
                throw ExamException.conflict("Nguồn được dùng bởi tác vụ. Giữ file để đối soát hoặc thử lại.");
            for(JsonElement publication:state.getAsJsonArray("publications"))if(contains(publication.getAsJsonObject().get("artifactIds"),id))
                throw ExamException.conflict("Học liệu đã thuộc một lần đăng Classroom; không xóa file lịch sử.");
            String group=str(asset,"kind").equals("source")?"sources":"artifacts";
            JsonArray remaining=new JsonArray();for(JsonElement row:state.getAsJsonArray(group))if(!str(row.getAsJsonObject(),"id").equals(id))remaining.add(row);
            state.add(group,remaining);store.saveState(plan,state);
            Files.deleteIfExists(store.assetPath(asset));Files.deleteIfExists(store.root.resolve("assets").resolve(id+".json"));
            return Map.of("success",true,"id",id);
        }
    }
    static boolean references(JsonObject document,String id){
        JsonObject editable=document.deepCopy();for(String key:List.of("sources","artifacts","jobs","publications","owner"))editable.remove(key);
        return contains(editable,id);
    }
    static boolean contains(JsonElement value,String id){
        if(value==null||value.isJsonNull())return false;
        if(value.isJsonPrimitive())return value.getAsJsonPrimitive().isString()&&value.getAsString().equals(id);
        if(value.isJsonArray()){for(JsonElement item:value.getAsJsonArray())if(contains(item,id))return true;}
        if(value.isJsonObject()){for(JsonElement item:value.getAsJsonObject().asMap().values())if(contains(item,id))return true;}
        return false;
    }
}
