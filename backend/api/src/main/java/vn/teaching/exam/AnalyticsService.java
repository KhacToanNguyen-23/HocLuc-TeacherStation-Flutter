package vn.teaching.exam;

import org.springframework.stereotype.Service;
import java.util.*;
import java.util.stream.Collectors;
import static vn.teaching.exam.ExamModels.*;

@Service
public class AnalyticsService {
    private final ExamRepository repo; private final PaperService papers; private final ResultService results; private final SourceService sources;
    public AnalyticsService(ExamRepository repo,PaperService papers,ResultService results,SourceService sources) { this.repo=repo; this.papers=papers; this.results=results; this.sources=sources; }
    private static final class Evidence {
        int attempted,correct; String last=""; List<Boolean> outcomes=new ArrayList<>();
        void add(boolean ok,String at) { attempted++; if(ok) correct++; outcomes.add(ok); if(at.compareTo(last)>0) last=at; }
        Map<String,Object> data(String key) {
            int half=outcomes.size()/2; String trend="INSUFFICIENT";
            if(half>=5) { double before=outcomes.subList(0,half).stream().filter(Boolean::booleanValue).count()/(double)half; double after=outcomes.subList(half,outcomes.size()).stream().filter(Boolean::booleanValue).count()/(double)(outcomes.size()-half); trend=after-before>0.1?"IMPROVING":before-after>0.1?"DECLINING":"STABLE"; }
            return Map.of("key",key,"questionsAttempted",attempted,"correctAnswers",correct,"accuracyRate",100.0*correct/attempted,"evidenceLevel",attempted<10?"LIMITED":"OBSERVED","lastAssessedAt",last,"trend",trend);
        }
    }
    public Map<String,Object> analyze(String teacher,String classId,String studentId,String examType) {
        if(classId!=null&&!classId.isBlank()) results.ownedClass(classId,teacher);
        if(studentId!=null&&!studentId.isBlank()) results.ownedStudent(studentId,teacher);
        if(examType!=null&&!examType.isBlank()&&!Set.of("VACT","HSA").contains(examType)) throw ExamException.bad("Loại kỳ thi không hợp lệ.");
        Map<String,Session> sessions=repo.owned("exam_sessions",teacher,Session.class).stream().collect(Collectors.toMap(Session::id,s->s));
        List<Result> selected=repo.owned("student_results",teacher,Result.class).stream()
            .filter(r->studentId==null||studentId.isBlank()||studentId.equals(r.studentId()))
            .filter(r->classId==null||classId.isBlank()||classId.equals(sessions.get(r.sessionId()).classId()))
            .filter(r->examType==null||examType.isBlank()||examType.equals(papers.owned(sessions.get(r.sessionId()).paperId(),teacher).matrix().examType()))
            .sorted(Comparator.comparing(r->sessions.get(r.sessionId()).assessedAt())).toList();
        Map<String,Evidence> skills=new TreeMap<>(),topics=new TreeMap<>(),sections=new TreeMap<>(),difficulties=new TreeMap<>();
        List<Map<String,Object>> scores=new ArrayList<>(); Map<String,List<Double>> byType=new TreeMap<>(); Map<String,Integer> distribution=new TreeMap<>();
        int detailed=0;
        for(Result r:selected) {
            Session session=sessions.get(r.sessionId()); Paper p=papers.owned(session.paperId(),teacher); String type=p.matrix().examType();
            double percentage=100*r.score()/(r.totalQuestions()*p.matrix().pointsPerCorrect()); byType.computeIfAbsent(type,k->new ArrayList<>()).add(percentage);
            String bucket=percentage<40?"0–39%":percentage<60?"40–59%":percentage<80?"60–79%":"80–100%"; distribution.merge(bucket,1,Integer::sum);
            Map<String,Object> score=new LinkedHashMap<>(); score.put("studentId",r.studentId()); score.put("studentName",results.ownedStudent(r.studentId(),teacher).fullName()); score.put("sessionId",r.sessionId()); score.put("title",session.title()); score.put("examType",type); score.put("assessedAt",session.assessedAt()); score.put("score",r.score()); score.put("maxScore",r.totalQuestions()*p.matrix().pointsPerCorrect()); score.put("percentage",percentage); score.put("level",r.level()); scores.add(score);
            if(r.level().equals("DETAILED")) {
                detailed++;
                for(int i=0;i<p.questions().size();i++) {
                    Question q=p.questions().get(i); boolean correct=ResultService.correct(q,r.answers().get(String.valueOf(i+1)));
                    evidence(skills,type+" / "+q.skill(),correct,session.assessedAt()); evidence(topics,type+" / "+q.topic(),correct,session.assessedAt()); evidence(sections,type+" / "+q.section(),correct,session.assessedAt()); evidence(difficulties,type+" / "+q.difficulty(),correct,session.assessedAt());
                }
            }
        }
        List<Map<String,Object>> recommendations=new ArrayList<>();
        for(var entry:skills.entrySet()) {
            Evidence e=entry.getValue(); if(e.attempted<10||e.correct/(double)e.attempted>=0.6) continue;
            String[] split=entry.getKey().split(" / ",2);
            List<String> questionIds=sources.bank().stream().filter(q->q.examType().equals(split[0])&&q.skill().equals(split[1])).map(Question::id).limit(20).toList();
            recommendations.add(Map.of("skill",split[1],"examType",split[0],"reason",e.correct+"/"+e.attempted+" câu đúng; cần ôn tập thêm.","questionsAttempted",e.attempted,"questionIds",questionIds));
        }
        Map<String,Object> report=new LinkedHashMap<>(); report.put("resultCount",selected.size()); report.put("detailedResultCount",detailed); report.put("aggregateResultCount",selected.size()-detailed); report.put("scores",scores); report.put("skills",data(skills)); report.put("topics",data(topics)); report.put("sections",data(sections)); report.put("difficulties",data(difficulties)); report.put("recommendations",recommendations); report.put("distribution",distribution);
        Map<String,Double> averages=new TreeMap<>(); byType.forEach((k,v)->averages.put(k,v.stream().mapToDouble(Double::doubleValue).average().orElse(0))); report.put("averagePercentageByExamType",averages);
        report.put("limitation",detailed==0?"Chưa có đáp án chi tiết: chỉ phân tích điểm và xu hướng. Không có kết luận theo kỹ năng.":"Tỷ lệ đúng dựa trên số câu đã ghi nhận; dưới 10 câu là bằng chứng hạn chế. Điểm luyện tập không dự đoán điểm thi chính thức."); return report;
    }
    private void evidence(Map<String,Evidence> map,String key,boolean correct,String at) { map.computeIfAbsent(key,k->new Evidence()).add(correct,at); }
    private List<Map<String,Object>> data(Map<String,Evidence> map) { return map.entrySet().stream().map(e->e.getValue().data(e.getKey())).toList(); }
    public byte[] csv(Map<String,Object> report) {
        StringBuilder csv=new StringBuilder("\uFEFFstudent,exam_type,assessed_at,practice_score,max_score,percentage,evidence_level\r\n");
        for(Object item:(List<?>)report.get("scores")) { Map<?,?> row=(Map<?,?>)item; csv.append(List.of("studentName","examType","assessedAt","score","maxScore","percentage","level").stream().map(k->escape(row.get(k))).collect(Collectors.joining(","))).append("\r\n"); }
        return csv.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
    }
    private String escape(Object value) { String text=String.valueOf(value); if(text.matches("^[=+@\\-].*")) text="'"+text; return "\""+text.replace("\"","\"\"")+"\""; }
}
