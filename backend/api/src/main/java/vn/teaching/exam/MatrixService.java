package vn.teaching.exam;

import jakarta.annotation.PostConstruct;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.io.IOException;
import java.util.*;
import static vn.teaching.exam.ExamModels.*;

@Service
public class MatrixService {
    private final ExamRepository repo; private final ObjectMapper mapper;
    public MatrixService(ExamRepository repo,ObjectMapper mapper) { this.repo=repo; this.mapper=mapper; }
    @PostConstruct public void seed() throws IOException {
        try(var in=new ClassPathResource("exam-matrices.json").getInputStream()) {
            for(Matrix m:mapper.readValue(in,Matrix[].class)) if(repo.find("matrix_versions",m.id(),Matrix.class).isEmpty()) create(m);
        }
    }
    @Transactional public Matrix create(Matrix m) {
        validate(m);
        if(repo.find("matrix_versions",m.id(),Matrix.class).isPresent()) throw ExamException.conflict("Ma trận là bất biến. Dùng ID phiên bản mới.");
        repo.insert("matrix_versions",m.id(),m,Map.of()); return m;
    }
    public void validate(Matrix m) {
        if(m.id()==null||!m.id().matches("[a-zA-Z0-9_-]{3,100}")) throw ExamException.bad("ID ma trận không hợp lệ.");
        if(m.examType()==null||!Set.of("VACT","HSA").contains(m.examType())||m.examVersion()==null||m.examVersion().isBlank()) throw ExamException.bad("Loại/phiên bản kỳ thi bắt buộc.");
        if(m.status()==null||!Set.of("DRAFT","ACTIVE").contains(m.status())||m.durationMinutes()<1||m.durationMinutes()>500||m.totalQuestions()<1||m.totalQuestions()>300) throw ExamException.bad("Trạng thái, thời gian hoặc số câu không hợp lệ.");
        if(!Set.of("FULL","PRACTICE").contains(m.purpose())) throw ExamException.bad("Loại ma trận FULL hoặc PRACTICE.");
        if(!"RAW_PRACTICE".equals(m.scoringPolicy())||!Double.isFinite(m.pointsPerCorrect())||m.pointsPerCorrect()<=0) throw ExamException.bad("Chỉ hỗ trợ chính sách điểm luyện tập có hệ số dương.");
        if(m.quotas()==null||m.quotas().isEmpty()||m.quotas().size()>100||m.quotas().stream().mapToInt(Quota::count).sum()!=m.totalQuestions()) throw ExamException.bad("Tổng quota không bằng số câu.");
        Set<String> signatures=new HashSet<>();
        for(Quota q:m.quotas()) {
            SourceService.required(q.section(),"Phần thi"); SourceService.required(q.label(),"Tên quota");
            if(q.count()<1|| (q.type()!=null&&!Set.of("MCQ","SHORT").contains(q.type())) || (q.difficulty()!=null&&!Set.of("EASY","MEDIUM","HARD").contains(q.difficulty()))) throw ExamException.bad("Quota hoặc bộ lọc không hợp lệ.");
            if(!signatures.add(q.section()+"|"+q.type()+"|"+q.topic()+"|"+q.skill()+"|"+q.difficulty())) throw ExamException.bad("Quota trùng nhau.");
        }
        // No ambiguous overlap: one question must belong to one slot, for exact counting.
        for(int i=0;i<m.quotas().size();i++) for(int j=i+1;j<m.quotas().size();j++) {
            Quota a=m.quotas().get(i),b=m.quotas().get(j);
            if(a.section().equals(b.section())&&overlap(a.type(),b.type())&&overlap(a.topic(),b.topic())&&overlap(a.skill(),b.skill())&&overlap(a.difficulty(),b.difficulty())) throw ExamException.bad("Các quota chồng lấn; hãy tách điều kiện rõ ràng.");
        }
        SourceService.required(m.name(),"Tên ma trận"); SourceService.required(m.provenance(),"Nguồn/quy tắc ma trận");
        if(m.purpose().equals("FULL")&&m.status().equals("ACTIVE")&&m.examType().equals("HSA")&&m.quotas().stream().anyMatch(q->q.section().equals("science"))) {
            Set<String> topics=new HashSet<>(); m.quotas().stream().filter(q->q.section().equals("science")).forEach(q->topics.add(q.topic()));
            if(topics.size()!=3||!Set.of("physics","chemistry","biology","history","geography").containsAll(topics)) throw ExamException.bad("HSA Khoa học cần quota xác minh cho đúng 3/5 chủ đề.");
        }
    }
    private boolean overlap(String a,String b) { return a==null||a.isBlank()||b==null||b.isBlank()||a.equals(b); }
    public static boolean matches(Quota q,Question question) { return q.section().equals(question.section())&&match(q.type(),question.type())&&match(q.topic(),question.topic())&&match(q.skill(),question.skill())&&match(q.difficulty(),question.difficulty()); }
    private static boolean match(String filter,String value) { return filter==null||filter.isBlank()||filter.equals(value); }
}
