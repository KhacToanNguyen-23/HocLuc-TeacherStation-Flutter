package vn.teaching.exam;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.*;
import java.util.stream.Collectors;
import static vn.teaching.exam.ExamModels.*;
import static vn.teaching.exam.ExamRepository.*;

@Service
public class PaperService {
    public record Generate(String matrixId,String title,List<String> sourceIds,int variants,Long seed,String difficulty,String skill) {}
    public record Edit(String title,String instructions,int durationMinutes,List<String> questionIds) {}
    public record Revision(String examType,String examVersion,String skill,String title,int count,int durationMinutes) {}
    private record Unit(List<Question> questions,int[] counts) {}
    private final ExamRepository repo; private final SourceService sources; private final MatrixService matrices;
    public PaperService(ExamRepository repo,SourceService sources,MatrixService matrices) { this.repo=repo; this.sources=sources; this.matrices=matrices; }
    public Paper owned(String id,String teacher) {
        Paper p=repo.require("papers",id,Paper.class); if(!p.teacherId().equals(teacher)) throw ExamException.missing(); return p;
    }
    /** Creates an explicit practice matrix from existing reviewed evidence; never invents filler. */
    @Transactional public List<Paper> revision(String teacher,Revision request) {
        SourceService.required(request.skill(),"Kỹ năng"); SourceService.required(request.title(),"Tên bộ ôn tập");
        if(request.count()<1||request.count()>100||request.durationMinutes()<1||request.durationMinutes()>500) throw ExamException.bad("Bộ ôn tập cần 1–100 câu và thời gian 1–500 phút.");
        List<Question> bank=sources.bank().stream().filter(q->q.examType().equals(request.examType())&&q.examVersion().equals(request.examVersion())&&q.skill().equals(request.skill())).toList();
        Set<String> candidates=bank.stream().map(Question::id).collect(Collectors.toSet()); Map<String,List<Question>> units=new LinkedHashMap<>();
        for(Question q:bank) units.computeIfAbsent(q.groupId()==null?q.id():q.groupId(),k->new ArrayList<>()).add(q);
        Set<String> seen=new HashSet<>(); List<List<Question>> eligible=new ArrayList<>();
        for(List<Question> unit:units.values()) {
            String group=unit.get(0).groupId();
            if(group!=null&&repo.all("questions",Question.class).stream().filter(q->group.equals(q.groupId())).anyMatch(q->!candidates.contains(q.id()))) continue;
            if(unit.stream().anyMatch(q->seen.contains(q.fingerprint()))||unit.stream().map(Question::fingerprint).distinct().count()!=unit.size()) continue;
            unit.forEach(q->seen.add(q.fingerprint())); eligible.add(unit);
        }
        List<List<Question>>[] achievable=new List[request.count()+1]; achievable[0]=new ArrayList<>();
        for(List<Question> unit:eligible) for(int total=request.count();total>=unit.size();total--) if(achievable[total]==null&&achievable[total-unit.size()]!=null) {
            achievable[total]=new ArrayList<>(achievable[total-unit.size()]); achievable[total].add(unit);
        }
        if(achievable[request.count()]==null) throw new ExamException(HttpStatus.CONFLICT,"INSUFFICIENT_REVISION_BANK","Không đủ tổ hợp câu/nhóm ngữ cảnh cho bộ ôn tập này.",List.of(Map.of("label",request.skill(),"required",request.count(),"available",eligible.stream().mapToInt(List::size).sum(),"missing",Math.max(0,request.count()-eligible.stream().mapToInt(List::size).sum()))));
        Map<String,Integer> counts=new LinkedHashMap<>(); achievable[request.count()].stream().flatMap(List::stream).forEach(q->counts.merge(q.section()+":"+q.type(),1,Integer::sum));
        List<Quota> quotas=counts.entrySet().stream().map(e->{ String[] key=e.getKey().split(":",2); return new Quota(key[0],request.skill()+" / "+key[0]+" / "+key[1],e.getValue(),key[1],null,request.skill(),null); }).toList();
        Matrix matrix=new Matrix("revision-"+id(),request.examType(),request.examVersion(),"Ôn kỹ năng: "+request.skill(),"ACTIVE",request.durationMinutes(),request.count(),quotas,"RAW_PRACTICE",1,"Teacher-created practice set from approved bank; not a full official exam matrix.","PRACTICE");
        matrices.create(matrix); return generate(teacher,new Generate(matrix.id(),request.title(),List.of(),1,null,null,request.skill()));
    }
    @Transactional public List<Paper> generate(String teacher,Generate request) {
        Matrix m=repo.require("matrix_versions",request.matrixId(),Matrix.class); matrices.validate(m);
        if(!m.status().equals("ACTIVE")) throw ExamException.bad("Ma trận chưa được kích hoạt.");
        SourceService.required(request.title(),"Tên đề");
        if(request.variants()<1||request.variants()>20) throw ExamException.bad("Số mã đề từ 1 đến 20.");
        if(request.difficulty()!=null&&!request.difficulty().isBlank()&&!Set.of("EASY","MEDIUM","HARD").contains(request.difficulty())) throw ExamException.bad("Độ khó không hợp lệ.");
        Set<String> sourceIds=new HashSet<>(request.sourceIds()==null?List.of():request.sourceIds());
        sourceIds.forEach(sources::source);
        List<Question> bank=sources.bank().stream().filter(q->q.examType().equals(m.examType())&&q.examVersion().equals(m.examVersion()))
            .filter(q->sourceIds.isEmpty()||sourceIds.contains(q.sourceId()))
            .filter(q->request.difficulty()==null||request.difficulty().isBlank()||request.difficulty().equals(q.difficulty()))
            .filter(q->request.skill()==null||request.skill().isBlank()||request.skill().equals(q.skill())).toList();
        Set<String> candidateIds=bank.stream().map(Question::id).collect(Collectors.toSet());
        Map<String,List<Question>> grouped=new LinkedHashMap<>();
        for(Question q:bank) grouped.computeIfAbsent(q.groupId()==null?"q:"+q.id():"g:"+q.groupId(),k->new ArrayList<>()).add(q);
        List<Unit> units=new ArrayList<>();
        for(var entry:grouped.entrySet()) {
            List<Question> qs=entry.getValue();
            if(entry.getKey().startsWith("g:")) {
                String group=entry.getKey().substring(2);
                if(repo.all("questions",Question.class).stream().filter(q->group.equals(q.groupId())).anyMatch(q->!candidateIds.contains(q.id()))) continue;
            }
            int[] counts=new int[m.quotas().size()]; boolean eligible=true; Set<String> fingerprints=new HashSet<>();
            for(Question q:qs) {
                int slot=-1; for(int i=0;i<m.quotas().size();i++) if(MatrixService.matches(m.quotas().get(i),q)) { slot=i; break; }
                if(slot<0||!fingerprints.add(q.fingerprint())) { eligible=false; break; } counts[slot]++;
            }
            if(eligible) units.add(new Unit(List.copyOf(qs),counts));
        }
        List<Map<String,Object>> shortages=new ArrayList<>();
        for(int i=0;i<m.quotas().size();i++) {
            Quota quota=m.quotas().get(i); int index=i;
            long available=units.stream().flatMap(u->u.questions().stream()).filter(q->MatrixService.matches(m.quotas().get(index),q)).map(Question::fingerprint).distinct().count();
            if(available<quota.count()) shortages.add(Map.of("section",quota.section(),"label",quota.label(),"required",quota.count(),"available",available,"missing",quota.count()-available));
        }
        if(!shortages.isEmpty()) throw new ExamException(HttpStatus.CONFLICT,"INSUFFICIENT_BANK","Chưa đủ câu đã duyệt theo từng quota.",shortages);
        Random random=new Random(request.seed()==null?new java.security.SecureRandom().nextLong():request.seed()); List<Paper> papers=new ArrayList<>();
        for(int variant=1;variant<=request.variants();variant++) {
            List<Unit> shuffled=new ArrayList<>(units); Collections.shuffle(shuffled,random);
            int[] remaining=m.quotas().stream().mapToInt(Quota::count).toArray(); List<Unit> selected=new ArrayList<>(); Search search=new Search();
            if(!search.solve(shuffled,remaining,new HashSet<>(),selected)) throw new ExamException(HttpStatus.CONFLICT,search.steps>=100000?"SEARCH_LIMIT":"GROUP_QUOTA_CONFLICT",search.steps>=100000?"Tổ hợp quá phức tạp. Thu hẹp nguồn hoặc điều chỉnh quota.":"Số câu có sẵn nhưng nhóm ngữ cảnh/câu trùng không ghép được đúng quota.",List.of());
            selected.sort(Comparator.comparingInt(u->firstSlot(u.counts()))); List<Question> questions=new ArrayList<>(); selected.forEach(u->questions.addAll(u.questions()));
            List<Group> groups=questions.stream().map(Question::groupId).filter(Objects::nonNull).distinct().map(g->repo.require("question_groups",g,Group.class)).toList();
            Paper p=new Paper(id(),teacher,m,request.title().trim(),"Chọn đáp án đúng hoặc điền đáp án theo yêu cầu của câu hỏi.",m.durationMinutes(),variant,"DRAFT",List.copyOf(questions),groups,now());
            validate(p,false); repo.insert("papers",p.id(),p,Map.of("teacher_id",teacher,"matrix_id",m.id())); saveItems(p); papers.add(p);
        }
        return papers;
    }
    private int firstSlot(int[] counts) { for(int i=0;i<counts.length;i++) if(counts[i]>0) return i; return counts.length; }
    private static final class Search {
        int steps;
        boolean solve(List<Unit> candidates,int[] remaining,Set<String> fingerprints,List<Unit> selected) {
            if(++steps>=100000) return false;
            if(Arrays.stream(remaining).allMatch(n->n==0)) return true;
            int slot=-1; List<Unit> options=null;
            for(int i=0;i<remaining.length;i++) if(remaining[i]>0) {
                List<Unit> fits=new ArrayList<>(); int capacity=0;
                for(Unit u:candidates) if(u.counts()[i]>0&&fits(u,remaining,fingerprints)) { fits.add(u); capacity+=u.counts()[i]; }
                if(capacity<remaining[i]) return false;
                if(options==null||fits.size()<options.size()) { slot=i; options=fits; }
            }
            if(slot<0) return false;
            for(Unit u:options) {
                List<Unit> next=new ArrayList<>(candidates); next.remove(u);
                for(int i=0;i<remaining.length;i++) remaining[i]-=u.counts()[i];
                u.questions().forEach(q->fingerprints.add(q.fingerprint())); selected.add(u);
                if(solve(next,remaining,fingerprints,selected)) return true;
                selected.remove(selected.size()-1); u.questions().forEach(q->fingerprints.remove(q.fingerprint()));
                for(int i=0;i<remaining.length;i++) remaining[i]+=u.counts()[i];
                if(steps>=100000) return false;
            }
            return false;
        }
        boolean fits(Unit u,int[] remaining,Set<String> fingerprints) {
            for(int i=0;i<remaining.length;i++) if(u.counts()[i]>remaining[i]) return false;
            return u.questions().stream().noneMatch(q->fingerprints.contains(q.fingerprint()));
        }
    }
    public void validate(Paper p,boolean checkAvailability) {
        if(p.questions().size()!=p.matrix().totalQuestions()) throw ExamException.bad("Số câu khác ma trận.");
        if(p.durationMinutes()!=p.matrix().durationMinutes()) throw ExamException.bad("Thời gian khác ma trận. Tạo phiên bản ma trận riêng nếu muốn đổi thời gian.");
        Set<String> ids=new HashSet<>(),fingerprints=new HashSet<>(),closed=new HashSet<>(); String current=null;
        for(Question q:p.questions()) {
            if(!ids.add(q.id())||!fingerprints.add(q.fingerprint())) throw ExamException.bad("Đề có câu trùng.");
            if(!q.status().equals("APPROVED")||!q.examType().equals(p.matrix().examType())||!q.examVersion().equals(p.matrix().examVersion())) throw ExamException.bad("Câu hỏi sai kỳ thi/phiên bản hoặc chưa duyệt.");
            if(!Objects.equals(current,q.groupId())) {
                if(current!=null) closed.add(current); current=q.groupId();
                if(current!=null&&closed.contains(current)) throw ExamException.bad("Nhóm ngữ cảnh phải liền nhau.");
            }
        }
        for(Quota quota:p.matrix().quotas()) if(p.questions().stream().filter(q->MatrixService.matches(quota,q)).count()!=quota.count()) throw ExamException.bad("Vi phạm quota: "+quota.label());
        if(checkAvailability) {
            Set<String> bank=sources.bank().stream().map(Question::id).collect(Collectors.toSet());
            if(!bank.containsAll(ids)) throw ExamException.bad("Đề chứa câu từ nguồn vô hiệu hóa hoặc chưa được duyệt.");
            for(String group:p.questions().stream().map(Question::groupId).filter(Objects::nonNull).distinct().toList())
                if(repo.all("questions",Question.class).stream().filter(q->group.equals(q.groupId())).anyMatch(q->!ids.contains(q.id()))) throw ExamException.bad("Không được tách nhóm ngữ cảnh.");
        }
    }
    @Transactional public Paper edit(String id,String teacher,Edit request) {
        Paper old=owned(id,teacher); if(!old.status().equals("DRAFT")) throw ExamException.conflict("Đề đã xuất bản không thể sửa; hãy tạo mã đề mới.");
        SourceService.required(request.title(),"Tên đề");
        if(request.questionIds()==null) throw ExamException.bad("Danh sách câu bắt buộc.");
        List<Question> questions=request.questionIds().stream().map(q->repo.require("questions",q,Question.class)).toList();
        List<Group> groups=questions.stream().map(Question::groupId).filter(Objects::nonNull).distinct().map(g->repo.require("question_groups",g,Group.class)).toList();
        Paper p=new Paper(old.id(),teacher,old.matrix(),request.title(),request.instructions()==null?"":request.instructions(),request.durationMinutes(),old.variant(),"DRAFT",questions,groups,old.createdAt());
        validate(p,true); repo.update("papers",id,p); saveItems(p); return p;
    }
    @Transactional public Paper publish(String id,String teacher) {
        Paper p=owned(id,teacher); if(p.status().equals("PUBLISHED")) return p;
        validate(p,true); Paper published=new Paper(p.id(),teacher,p.matrix(),p.title(),p.instructions(),p.durationMinutes(),p.variant(),"PUBLISHED",p.questions(),p.groups(),p.createdAt()); repo.update("papers",id,published); return published;
    }
    private void saveItems(Paper p) {
        repo.jdbc().update("DELETE FROM exam_platform.paper_items WHERE paper_id=?",p.id());
        for(int i=0;i<p.questions().size();i++) { Question q=p.questions().get(i); repo.jdbc().update("INSERT INTO exam_platform.paper_items VALUES (?,?,?,?)",p.id(),i+1,q.id(),repo.json(q)); }
    }
}
