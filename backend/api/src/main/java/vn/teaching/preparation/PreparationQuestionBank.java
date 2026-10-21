package vn.teaching.preparation;

import com.google.gson.*;
import org.springframework.web.bind.annotation.*;
import vn.teaching.exam.*;
import static vn.teaching.exam.ExamModels.*;
import java.util.*;
import java.nio.file.*;

/** Inserts a fresh approved bank snapshot; group siblings are an indivisible unit. */
@RestController
@RequestMapping("/api/preparation")
public class PreparationQuestionBank {
    private final PreparationStore store; private final SourceService sources;
    private final ExamRepository repo; private final ExamAuth auth;
    public PreparationQuestionBank(PreparationStore store,SourceService sources,ExamRepository repo,ExamAuth auth){this.store=store;this.sources=sources;this.repo=repo;this.auth=auth;}
    static String value(String s){return s==null?"":s;}
    List<Question> resolve(String id,List<Question> bank){
        Question selected=bank.stream().filter(q->q.id().equals(id)).findFirst().orElseThrow(ExamException::missing);
        if(value(selected.groupId()).isBlank())return List.of(selected);
        List<Question> siblings=repo.all("questions",Question.class).stream().filter(q->value(q.groupId()).equals(selected.groupId())&&q.sourceId().equals(selected.sourceId())).toList();
        Set<String> approved=new HashSet<>();bank.forEach(q->approved.add(q.id()));
        if(siblings.isEmpty()||siblings.stream().anyMatch(q->!approved.contains(q.id())))throw ExamException.conflict("Nhóm có câu chưa duyệt hoặc nguồn đã ngừng hoạt động. Cần duyệt đủ nhóm trước khi chèn.");
        Group group=repo.require("question_groups",selected.groupId(),Group.class);
        if(!group.sourceId().equals(selected.sourceId()))throw ExamException.bad("Ngữ cảnh nhóm không cùng nguồn.");
        return siblings.stream().sorted(Comparator.comparingInt(Question::sourcePage).thenComparing(Question::id)).toList();
    }
    @GetMapping("/questions") public Object list(@RequestHeader(value="Authorization",required=false)String token,@RequestParam(defaultValue="")String search){
        auth.authenticate(token);List<Question> bank=sources.bank();List<Object> items=new ArrayList<>();Set<String> seen=new HashSet<>();
        String query=search.toLowerCase(Locale.ROOT).strip();
        for(Question q:bank){String unit=value(q.groupId()).isBlank()?q.id():q.groupId();if(!seen.add(unit))continue;
            List<Question> selected;try{selected=resolve(q.id(),bank);}catch(ExamException incomplete){continue;}
            Group group=value(q.groupId()).isBlank()?null:repo.require("question_groups",q.groupId(),Group.class);
            String searchable=selected.stream().map(x->value(x.stem())+" "+value(x.topic())+" "+value(x.skill())).reduce("",(a,b)->a+" "+b)+ (group==null?"":value(group.content()));
            if(!searchable.toLowerCase(Locale.ROOT).contains(query))continue;
            Map<String,Object> dto=new LinkedHashMap<>();dto.put("id",q.id());dto.put("title",value(q.stem()));dto.put("groupId",value(q.groupId()));dto.put("groupContent",group==null?"":value(group.content()));dto.put("groupAssets",group==null?List.of():group.assets());dto.put("questionCount",selected.size());dto.put("questions",selected);items.add(dto);if(items.size()==200)break;
        }return Map.of("items",items);
    }
    @PostMapping("/plannings/{id}/question-insert") public Object insert(@PathVariable String id,@RequestHeader(value="Authorization",required=false)String token,@RequestBody Map<String,Object> body)throws Exception{
        String owner=auth.authenticate(token).id();JsonObject input=store.gson.toJsonTree(body).getAsJsonObject();
        synchronized(store){JsonObject doc=store.document(id,owner);int revision=PreparationStore.integer(input,"expectedRevision",-1);
            if(PreparationStore.integer(doc,"revision",0)!=revision)throw ExamException.conflict("Bài đã thay đổi. Tải lại trước khi chèn câu hỏi.");
            PreparationMutationBackup backup=new PreparationMutationBackup(store,id,revision);
            try {
            List<Question> questions=resolve(PreparationStore.str(input,"questionId"),sources.bank());Question first=questions.get(0);
            JsonObject section=new JsonObject(),snapshot=new JsonObject();section.addProperty("id",PreparationStore.id());section.addProperty("title",questions.size()>1?"Nhóm câu hỏi đã duyệt ("+questions.size()+")":"Câu hỏi đã duyệt");section.addProperty("minutes",5);
            List<String> student=new ArrayList<>(),teacher=new ArrayList<>();JsonArray images=new JsonArray(),ids=new JsonArray(),fingerprints=new JsonArray();
            snapshot.addProperty("sourceId",first.sourceId());snapshot.addProperty("groupId",value(first.groupId()));snapshot.addProperty("insertedAt",java.time.Instant.now().toString());
            if(!value(first.groupId()).isBlank()){Group g=repo.require("question_groups",first.groupId(),Group.class);student.add(value(g.content()));copyImages(id,owner,revision,g.assets(),first.sourceId(),"",false,"context",images);}
            int number=0;for(Question q:questions){number++;ids.add(q.id());fingerprints.add(value(q.fingerprint()));student.add("Câu "+number+". "+value(q.stem()));for(Choice c:q.choices()==null?List.<Choice>of():q.choices())student.add(c.key()+". "+c.text());
                teacher.add("Câu "+number+" — Đáp án: "+value(q.answer())+(q.acceptedAnswers()==null||q.acceptedAnswers().isEmpty()?"":" / "+String.join(" / ",q.acceptedAnswers()))+"\n"+value(q.solution()));
                copyImages(id,owner,revision,q.assets(),q.sourceId(),q.id(),false,"question",images);copyImages(id,owner,revision,q.solutionAssets(),q.sourceId(),q.id(),true,"solution",images);
            }
            section.addProperty("body",String.join("\n\n",student));section.addProperty("teacherNotes",String.join("\n\n",teacher));snapshot.add("questionIds",ids);snapshot.add("fingerprints",fingerprints);snapshot.add("images",images);section.add("questionBank",snapshot);doc.getAsJsonArray("sections").add(section);
            return store.gson.fromJson(store.update(id,owner,revision,doc,true),Object.class);
            } catch(Exception error){try{backup.restore();}catch(Exception rollback){error.addSuppressed(rollback);}throw error;}
        }
    }
    void copyImages(String plan,String owner,int revision,List<String> ids,String sourceId,String questionId,boolean privateImage,String role,JsonArray images)throws Exception{
        if(ids==null)return;for(String assetId:ids){Asset source=sources.asset(assetId);if(!source.sourceId().equals(sourceId))throw ExamException.bad("Ảnh câu hỏi không cùng nguồn.");
            Path path=sources.path(source.path());if(!Files.isRegularFile(path)||Files.size(path)>10_000_000)throw ExamException.bad("Ảnh câu hỏi không có hoặc quá lớn.");
            try(var stream=Files.newInputStream(path)){if(javax.imageio.ImageIO.read(stream)==null)throw ExamException.bad("Ảnh câu hỏi bị hỏng.");}
            String mime=Files.probeContentType(path);if(!Set.of("image/png","image/jpeg").contains(mime))throw ExamException.bad("Chỉ hỗ trợ ảnh PNG/JPEG.");
            JsonObject asset=store.register(plan,owner,path,"question-"+assetId+(mime.equals("image/png")?".png":".jpg"),mime,privateImage?"question_private":"question_image",revision+1),ref=new JsonObject();
            ref.addProperty("imageAssetId",PreparationStore.str(asset,"id"));ref.addProperty("private",privateImage);ref.addProperty("questionId",questionId);ref.addProperty("role",role);images.add(ref);
        }
    }
}
