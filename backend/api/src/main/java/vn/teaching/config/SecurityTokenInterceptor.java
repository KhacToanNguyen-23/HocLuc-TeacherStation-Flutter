package vn.teaching.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

@Component
public class SecurityTokenInterceptor implements HandlerInterceptor {
    private final String companionToken;

    public SecurityTokenInterceptor(String companionToken) {
        this.companionToken = companionToken;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
        if ("OPTIONS".equalsIgnoreCase(request.getMethod())) {
            return true;
        }
        String path = request.getRequestURI();
        if (path.equals("/api/bootstrap") || path.startsWith("/api/auth/") || path.startsWith("/api/exams/") || !path.startsWith("/api/")) {
            return true;
        }

        String clientToken = request.getHeader("X-Companion-Token");
        if (clientToken == null || !clientToken.equals(companionToken)) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            response.setContentType("application/json");
            response.getWriter().write("{\"error\":\"Local session required\"}");
            return false;
        }
        return true;
    }
}
