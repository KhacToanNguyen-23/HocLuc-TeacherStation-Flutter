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
    private final ExamRepository repo;
    private final ExamAuth auth;
    private final SourceService sources;
    public ExamController(ExamRepository repo,ExamAuth auth,SourceService sources) { this.repo=repo;this.auth=auth;this.sources=sources; }
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
}
