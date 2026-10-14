package vn.teaching.exam;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;
import java.util.*;
import static vn.teaching.exam.ExamModels.*;

@RestController
@RequestMapping("/api/exams")
public class ExamController {
    private final ExamRepository repo; private final ExamAuth auth; private final SourceService sources;
    private final MatrixService matrices; private final PaperService papers; private final ExportService exports;
    private final ResultService results; private final AnalyticsService analytics;
    public ExamController(ExamRepository repo,ExamAuth auth,SourceService sources,MatrixService matrices,PaperService papers,ExportService exports,ResultService results,AnalyticsService analytics) {
        this.repo=repo; this.auth=auth; this.sources=sources; this.matrices=matrices; this.papers=papers; this.exports=exports; this.results=results; this.analytics=analytics;
    }
    private String teacher(HttpServletRequest request) { return auth.current(request).id(); }
    private String text(Map<String,?> map,String key) { Object v=map.get(key); return v==null?null:v.toString(); }
    private int integer(Map<String,?> map,String key) { try { return Integer.parseInt(String.valueOf(map.get(key))); } catch(Exception e) { throw ExamException.bad(key+" phải là số nguyên."); } }
    @GetMapping("/auth/me") public Object me(HttpServletRequest request) { return auth.current(request); }
    @PostMapping("/auth/logout") public Object logout(HttpServletRequest request) { auth.logout(request.getHeader("Authorization")); return Map.of("success",true); }
    @GetMapping("/dashboard") public Object dashboard(HttpServletRequest request) {
        String owner=teacher(request);
        return Map.of("classes",repo.owned("classes",owner,SchoolClass.class).size(),"students",repo.owned("students",owner,Student.class).size(),"papers",repo.owned("papers",owner,Paper.class).size(),"results",repo.owned("student_results",owner,Result.class).size(),"approvedQuestions",sources.bank().size(),"sources",repo.all("pdf_sources",Source.class).size());
    }
    @GetMapping("/sources") public Object sourceList() { return repo.all("pdf_sources",Source.class); }
    @GetMapping("/sources/{id}/pdf") public ResponseEntity<?> pdf(@PathVariable String id) {
        sources.source(id); return ResponseEntity.ok().contentType(MediaType.APPLICATION_PDF).header("Content-Disposition","inline; filename=source.pdf").body(new FileSystemResource(sources.pdf(id)));
    }
    @GetMapping("/sources/{id}/assets") public Object assets(@PathVariable String id) { return sources.assets(id); }
    @GetMapping("/assets/{id}") public ResponseEntity<?> asset(@PathVariable String id) {
        Asset asset=sources.asset(id); return ResponseEntity.ok().contentType(MediaType.IMAGE_PNG).cacheControl(CacheControl.noStore()).body(new FileSystemResource(sources.path(asset.path())));
    }
    @PostMapping("/admin/sources") public Object upload(@RequestParam MultipartFile file,@RequestParam String relativePath,@RequestParam String examType,@RequestParam String examVersion) throws IOException { return sources.upload(file,relativePath,examType,examVersion); }
    @PostMapping("/admin/sources/{id}/process") public Object process(@PathVariable String id,@RequestBody(required=false) Map<String,Boolean> request) { return sources.process(id,request!=null&&Boolean.TRUE.equals(request.get("force"))); }
    @PutMapping("/admin/sources/{id}/active") public Object active(@PathVariable String id,@RequestBody Map<String,Boolean> request) { if(!request.containsKey("active")) throw ExamException.bad("Thiếu active."); return sources.active(id,Boolean.TRUE.equals(request.get("active"))); }
    @GetMapping("/admin/jobs") public Object jobs() { return repo.all("processing_jobs",Job.class); }
    @GetMapping("/admin/questions") public Object review(@RequestParam(required=false) String sourceId) { return repo.all("questions",Question.class).stream().filter(q->sourceId==null||q.sourceId().equals(sourceId)).toList(); }
    @PostMapping("/admin/questions") public Object question(@RequestBody Question input) { return sources.edit(null,input); }
    @PutMapping("/admin/questions/{id}") public Object question(@PathVariable String id,@RequestBody Question input) { return sources.edit(id,input); }
    @PostMapping("/admin/questions/{id}/approve") public Object approve(@PathVariable String id,@RequestBody Map<String,Boolean> input,HttpServletRequest request) { return sources.approve(id,auth.current(request),Boolean.TRUE.equals(input.get("visualVerified")),Boolean.TRUE.equals(input.get("answerFree"))); }
    @PostMapping("/admin/groups") public Object group(@RequestBody Group group) { return sources.group(group); }
    @GetMapping("/groups/{id}") public Object group(@PathVariable String id) { return repo.require("question_groups",id,Group.class); }
    @GetMapping("/groups") public Object groups(@RequestParam(required=false) String sourceId) { return repo.all("question_groups",Group.class).stream().filter(g->sourceId==null||g.sourceId().equals(sourceId)).toList(); }
    @PostMapping("/admin/assets/crop") public Object crop(@RequestBody Map<String,Object> input) throws IOException { return sources.crop(text(input,"sourceId"),integer(input,"page"),integer(input,"x"),integer(input,"y"),integer(input,"width"),integer(input,"height")); }
    @GetMapping("/questions") public Object bank(@RequestParam Map<String,String> filters) {
        String search=filters.getOrDefault("search","").toLowerCase(Locale.ROOT);
        return sources.bank().stream().filter(q->(q.stem()+" "+q.topic()+" "+q.skill()).toLowerCase(Locale.ROOT).contains(search))
            .filter(q->filter(filters,"examType",q.examType())&&filter(filters,"examVersion",q.examVersion())&&filter(filters,"section",q.section())&&filter(filters,"topic",q.topic())&&filter(filters,"skill",q.skill())&&filter(filters,"difficulty",q.difficulty())&&filter(filters,"sourceId",q.sourceId())&&filter(filters,"type",q.type())).toList();
    }
    private boolean filter(Map<String,String> filters,String key,String value) { String filter=filters.get(key); return filter==null||filter.isBlank()||filter.equals(value); }
    @GetMapping("/matrices") public Object matrices() { return repo.all("matrix_versions",Matrix.class); }
    @PostMapping("/admin/matrices") public Object matrix(@RequestBody Matrix matrix) { return matrices.create(matrix); }
    @PostMapping("/papers/generate") public Object generate(@RequestBody PaperService.Generate input,HttpServletRequest request) { return papers.generate(teacher(request),input); }
    @PostMapping("/papers/revision") public Object revision(@RequestBody PaperService.Revision input,HttpServletRequest request) { return papers.revision(teacher(request),input); }
    @PostMapping("/papers/export") public ResponseEntity<?> exportBatch(@RequestBody Map<String,Object> input,HttpServletRequest request) throws IOException {
        if(!(input.get("paperIds") instanceof List<?> ids)||ids.isEmpty()||ids.size()>20) throw ExamException.bad("Chọn 1–20 mã đề.");
        String format=text(input,"format"),kind=text(input,"kind");
        try(java.io.ByteArrayOutputStream out=new java.io.ByteArrayOutputStream(); java.util.zip.ZipOutputStream zip=new java.util.zip.ZipOutputStream(out)) {
            Set<String> seen=new HashSet<>();
            for(Object value:ids) {
                Paper paper=papers.owned(String.valueOf(value),teacher(request)); if(!seen.add(paper.id())) continue;
                byte[] bytes=exports.export(paper,format,kind); zip.putNextEntry(new java.util.zip.ZipEntry("exam-"+paper.id()+"-"+kind+"."+format)); zip.write(bytes); zip.closeEntry();
            }
            zip.finish(); return ResponseEntity.ok().contentType(MediaType.parseMediaType("application/zip")).header("Content-Disposition","attachment; filename=exam-variants.zip").body(out.toByteArray());
        }
    }
    @GetMapping("/papers") public Object papers(HttpServletRequest request) { return repo.owned("papers",teacher(request),Paper.class); }
    @GetMapping("/papers/{id}") public Object paper(@PathVariable String id,HttpServletRequest request) { return papers.owned(id,teacher(request)); }
    @PutMapping("/papers/{id}") public Object edit(@PathVariable String id,@RequestBody PaperService.Edit input,HttpServletRequest request) { return papers.edit(id,teacher(request),input); }
    @PostMapping("/papers/{id}/publish") public Object publish(@PathVariable String id,HttpServletRequest request) { return papers.publish(id,teacher(request)); }
    @GetMapping("/papers/{id}/export") public ResponseEntity<?> export(@PathVariable String id,@RequestParam(defaultValue="pdf") String format,@RequestParam(defaultValue="paper") String kind,HttpServletRequest request) throws IOException {
        byte[] bytes=exports.export(papers.owned(id,teacher(request)),format,kind);
        String mime=format.equals("pdf")?"application/pdf":"application/vnd.openxmlformats-officedocument.wordprocessingml.document";
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(mime)).header("Content-Disposition","attachment; filename=exam-"+id+"-"+kind+"."+format).cacheControl(CacheControl.noStore()).body(bytes);
    }
    @GetMapping("/classes") public Object classes(HttpServletRequest request) { return repo.owned("classes",teacher(request),SchoolClass.class); }
    @PostMapping("/classes") public Object createClass(@RequestBody Map<String,String> input,HttpServletRequest request) { return results.createClass(teacher(request),input.get("name")); }
    @GetMapping("/classes/{id}/students") public Object roster(@PathVariable String id,HttpServletRequest request) { return results.roster(id,teacher(request)); }
    @PostMapping("/classes/{id}/members") public Object member(@PathVariable String id,@RequestBody Map<String,String> input,HttpServletRequest request) { results.member(id,input.get("studentId"),teacher(request)); return Map.of("success",true); }
    @PostMapping("/classes/{id}/transfer") public Object transfer(@PathVariable String id,@RequestBody Map<String,String> input,HttpServletRequest request) { results.transfer(id,input.get("toClassId"),input.get("studentId"),teacher(request)); return Map.of("success",true); }
    @GetMapping("/students") public Object students(HttpServletRequest request) { return repo.owned("students",teacher(request),Student.class); }
    @PostMapping("/students") public Object student(@RequestBody Map<String,String> input,HttpServletRequest request) { return results.createStudent(teacher(request),input.get("code"),input.get("fullName"),input.get("notes"),input.get("classId")); }
    @PutMapping("/students/{id}") public Object student(@PathVariable String id,@RequestBody Map<String,String> input,HttpServletRequest request) { return results.editStudent(id,teacher(request),input.get("fullName"),input.get("notes")); }
    @PostMapping("/students/import/preview") public Object rosterPreview(@RequestParam MultipartFile file,@RequestParam String classId,HttpServletRequest request) throws IOException { return results.preview(teacher(request),null,classId,"ROSTER",file); }
    @GetMapping("/sessions") public Object sessions(HttpServletRequest request) { return repo.owned("exam_sessions",teacher(request),Session.class); }
    @PostMapping("/sessions") public Object session(@RequestBody Map<String,String> input,HttpServletRequest request) { return results.createSession(teacher(request),input.get("classId"),input.get("paperId"),input.get("title"),input.get("assessedAt")); }
    @GetMapping("/sessions/{id}/results") public Object resultList(@PathVariable String id,HttpServletRequest request) { results.ownedSession(id,teacher(request)); return repo.owned("student_results",teacher(request),Result.class).stream().filter(r->r.sessionId().equals(id)).toList(); }
    @PostMapping("/sessions/{id}/results") public Object result(@PathVariable String id,@RequestBody ResultService.ResultInput input,HttpServletRequest request) { return results.record(teacher(request),id,input); }
    @PostMapping("/sessions/{id}/import/preview") public Object preview(@PathVariable String id,@RequestParam MultipartFile file,HttpServletRequest request) throws IOException { return results.preview(teacher(request),id,null,"RESULTS",file); }
    @PostMapping("/imports/{id}/commit") public Object commit(@PathVariable String id,HttpServletRequest request) { return results.commit(teacher(request),id); }
    @GetMapping("/analytics") public Object report(@RequestParam(required=false) String classId,@RequestParam(required=false) String studentId,@RequestParam(required=false) String examType,HttpServletRequest request) { return analytics.analyze(teacher(request),classId,studentId,examType); }
    @GetMapping("/analytics/export") public ResponseEntity<?> reportExport(@RequestParam(required=false) String classId,@RequestParam(required=false) String studentId,@RequestParam(required=false) String examType,HttpServletRequest request) { return ResponseEntity.ok().contentType(MediaType.parseMediaType("text/csv;charset=UTF-8")).header("Content-Disposition","attachment; filename=practice-results.csv").body(analytics.csv(analytics.analyze(teacher(request),classId,studentId,examType))); }
}
