package vn.teaching.exam;

import jakarta.servlet.http.*;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.*;
import java.util.List;

@Configuration
public class ExamWebConfig implements WebMvcConfigurer {
    private final ExamAuth auth;
    private final ExamRepository repo;
    public ExamWebConfig(ExamAuth auth, ExamRepository repo) { this.auth=auth; this.repo=repo; }
    @Override public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override public boolean preHandle(HttpServletRequest req,HttpServletResponse res,Object handler) throws Exception {
                if(req.getMethod().equals("OPTIONS")) return true;
                String path=req.getRequestURI();
                try {
                    var account=auth.authenticate(req.getHeader("Authorization"));
                    if(path.startsWith("/api/exams/admin/") && !account.role().equals("ADMIN"))
                        throw new ExamException(HttpStatus.FORBIDDEN,"ADMIN_REQUIRED","Chỉ admin được quản lý nguồn và duyệt câu hỏi.",List.of());
                    req.setAttribute("examAccount",account); return true;
                } catch(ExamException e) {
                    res.setStatus(e.status.value()); res.setContentType("application/json;charset=UTF-8");
                    res.getWriter().write(repo.json(java.util.Map.of("code",e.code,"message",e.getMessage(),"details",e.details))); return false;
                }
            }
        }).addPathPatterns("/api/exams/**");
    }
}
