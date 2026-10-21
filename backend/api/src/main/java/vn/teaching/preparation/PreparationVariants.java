package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import vn.teaching.exam.*;
import java.time.Instant;
import java.util.*;
import static vn.teaching.preparation.PreparationStore.*;

/** Class-bound editable snapshots; creating a variant never edits its source. */
@RestController
@RequestMapping("/api/preparation")
public class PreparationVariants {
    final PreparationStore store;
    final ExamRepository repo;
    final ExamAuth auth;
    final PreparationPublishing publishing;
    public PreparationVariants(PreparationStore store, ExamRepository repo, ExamAuth auth, PreparationPublishing publishing) {
        this.store=store; this.repo=repo; this.auth=auth; this.publishing=publishing;
    }
    Object result(JsonElement value) { return store.gson.fromJson(value,Object.class); }

    @GetMapping("/variant-classes")
    public Object classes(@RequestHeader(value="Authorization",required=false) String token) {
        return Map.of("classes",repo.owned("classes",auth.authenticate(token).id(),ExamModels.SchoolClass.class));
    }
    @GetMapping("/plannings/{id}/variants")
    public Object variants(@PathVariable String id,@RequestHeader(value="Authorization",required=false) String token) {
        return result(list(id,auth.authenticate(token).id()));
    }
    @PostMapping("/plannings/{id}/variants")
    public Object create(@PathVariable String id,@RequestHeader(value="Authorization",required=false) String token,
                         @RequestHeader(value="X-Google-Teacher-Email",required=false) String email,@RequestBody Map<String,Object> body) {
        return result(create(id,auth.authenticate(token),email,store.gson.toJsonTree(body).getAsJsonObject()));
    }
    JsonObject target(ExamModels.Account account,String email,JsonObject input) {
        String kind=str(input,"classKind"),id=str(input,"classId"),name=""; checkId(id);
        if(kind.equals("local")) {
            var school=repo.require("classes",id,ExamModels.SchoolClass.class);
            if(!school.teacherId().equals(account.id())) throw ExamException.missing();
            name=school.name();
        } else if(kind.equals("google")) {
            JsonObject response=store.gson.toJsonTree(publishing.courses(account,email)).getAsJsonObject();
            for(JsonElement course:response.getAsJsonArray("courses")) {
                JsonObject row=course.getAsJsonObject();
                if(str(row,"id").equals(id)) { name=str(row,"name"); break; }
            }
            if(name.isBlank()) throw ExamException.missing();
        } else throw ExamException.bad("Chọn lớp nội bộ hoặc Google Classroom.");
        JsonObject target=new JsonObject(); target.addProperty("kind",kind); target.addProperty("id",id); target.addProperty("name",name); return target;
    }
    JsonObject create(String id,ExamModels.Account account,String email,JsonObject input) {
        int expected=integer(input,"expectedRevision",-1);
        // Check ownership/revision before an external request, and again while cloning.
        synchronized(store) { if(integer(store.document(id,account.id()),"revision",0)!=expected) throw ExamException.conflict("Bài đã thay đổi. Lưu/tải lại trước khi tạo biến thể."); }
        JsonObject target=target(account,email,input);
        String notes=str(input,"adaptationNotes").trim(),title=str(input,"title").trim();
        if(notes.length()>10000||title.length()>300) throw ExamException.bad("Tên tối đa 300 ký tự; điều chỉnh riêng tối đa 10.000 ký tự.");
        synchronized(store) {
            JsonObject source=store.document(id,account.id());
            if(integer(source,"revision",0)!=expected) throw ExamException.conflict("Bài đã thay đổi. Lưu/tải lại trước khi tạo biến thể.");
            JsonObject copy=store.duplicate(id,account.id()); String copyId=str(copy,"planningId");
            try {
                JsonObject metadata=new JsonObject(); metadata.addProperty("parentPlanningId",id); metadata.addProperty("parentRevision",expected);
                metadata.add("targetClass",target); metadata.addProperty("adaptationNotes",notes); metadata.addProperty("createdAt",Instant.now().toString());
                copy.remove("planningId"); copy.add("variant",metadata);
                copy.addProperty("title",title.isBlank()?str(source,"title")+" — "+str(target,"name"):title);
                // No artificial history: this is revision zero of an independent lesson.
                JsonObject lesson=store.planning.getPlanningContent(copyId);
                JsonObject persisted=copy.deepCopy(); for(String key:List.of("sources","jobs","artifacts","publications")) persisted.remove(key);
                lesson.add("preparation",persisted);
                if(store.planning.saveOrUpdatePlanning(copyId,str(copy,"title"),str(copy,"subject"),lesson)==null) throw new IllegalStateException("Không lưu được biến thể.");
                JsonObject result=store.document(copyId,account.id()); result.addProperty("planningId",copyId); return result;
            } catch(RuntimeException error) { try { store.discardCopy(copyId); } catch(Exception cleanup) { error.addSuppressed(cleanup); } throw error; }
        }
    }
    JsonArray list(String id,String owner) {
        synchronized(store) {
            store.document(id,owner); JsonArray result=new JsonArray();
            for(var plan:store.planning.getAllPlannings()) {
                if(!store.claimed(plan.getId())||!store.legacyAllowed(plan.getId(),owner)) continue;
                JsonObject doc=store.document(plan.getId(),owner);
                if(doc.has("variant")&&doc.get("variant").isJsonObject()&&str(doc.getAsJsonObject("variant"),"parentPlanningId").equals(id)) {
                    JsonObject row=new JsonObject(); row.addProperty("planningId",plan.getId()); row.addProperty("title",str(doc,"title"));
                    row.addProperty("revision",integer(doc,"revision",0)); row.add("variant",doc.get("variant").deepCopy()); result.add(row);
                }
            }
            return result;
        }
    }
}
