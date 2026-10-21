package vn.teaching.preparation;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import org.springframework.stereotype.Component;
import org.springframework.core.annotation.Order;
import org.springframework.web.filter.OncePerRequestFilter;
import vn.teaching.exam.*;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import org.springframework.beans.factory.annotation.Autowired;

/** Runs before DispatcherServlet resolves/spools multipart data. */
@Component
@Order(-100)
public class PreparationUploadFilter extends OncePerRequestFilter {
    final ExamAuth auth;final String companion;final Path spool;
    @Autowired public PreparationUploadFilter(ExamAuth auth,String companionToken,MultipartConfigElement multipart){this.auth=auth;this.companion=companionToken;this.spool=Path.of(multipart.getLocation());}
    PreparationUploadFilter(ExamAuth auth,String companionToken){this(auth,companionToken,new MultipartConfigElement(System.getProperty("java.io.tmpdir")));}
    long available()throws IOException{return Files.getFileStore(spool).getUsableSpace();}
    @Override protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain)throws ServletException,IOException{
        String type=request.getContentType();if(type==null||!type.toLowerCase(java.util.Locale.ROOT).startsWith("multipart/")){chain.doFilter(request,response);return;}
        if(!request.getRequestURI().equals("/api/preparation/components/install")){
            // Ordinary uploads retain their previous small request budget even though
            // the servlet must allow multi-GB, explicitly authenticated offline bundles.
            if(request.getContentLengthLong()<0&&!(request instanceof org.springframework.web.multipart.MultipartHttpServletRequest)){reject(response,411,"Multipart request cần Content-Length.");return;}
            if(request.getContentLengthLong()>51L*1024*1024){reject(response,413,"Request upload thông thường tối đa 51 MB; nguồn tối đa 50 MB.");return;}
        }else{
            String token=request.getHeader("X-Companion-Token");
            if(token==null||!java.security.MessageDigest.isEqual(token.getBytes(StandardCharsets.UTF_8),companion.getBytes(StandardCharsets.UTF_8))){reject(response,401,"Local session required");return;}
            try{auth.authenticate(request.getHeader("Authorization"));}catch(ExamException e){reject(response,e.status.value(),e.getMessage());return;}
            long length=request.getContentLengthLong();
            if(length<0){reject(response,411,"Gói offline cần Content-Length để kiểm dung lượng trước khi nhận.");return;}
            if(length>PreparationComponents.MAX_ZIP+1_048_576){reject(response,413,"Gói offline tối đa 8 GB.");return;}
            if(available()<length+512L*1024*1024){reject(response,507,"Không đủ dung lượng thư mục nhận gói và vùng an toàn 512 MB. Hãy giải phóng ổ dữ liệu trước khi cài.");return;}
        }
        chain.doFilter(request,response);
    }
    void reject(HttpServletResponse response,int status,String message)throws IOException{response.setStatus(status);response.setContentType("application/json;charset=UTF-8");response.getWriter().write(new com.google.gson.Gson().toJson(java.util.Map.of("message",message)));}
}
