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
        // The OAuth grant endpoints must not be callable from arbitrary sites,
        // even though the legacy bootstrap endpoint has permissive CORS.
        if (path.startsWith("/api/google/oauth/") || path.equals("/api/classroom/create")) {
            String origin = request.getHeader("Origin");
            if (origin != null && !isLocalOrigin(origin)) {
                response.setStatus(HttpServletResponse.SC_FORBIDDEN);
                response.setContentType("application/json");
                response.getWriter().write("{\"error\":\"Local app origin required\"}");
                return false;
            }
        }
        if (path.equals("/api/bootstrap") || path.startsWith("/api/auth/") || !path.startsWith("/api/")) {
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

    private boolean isLocalOrigin(String value) {
        try {
            java.net.URI origin = java.net.URI.create(value);
            return ("http".equals(origin.getScheme()) || "https".equals(origin.getScheme()))
                    && ("127.0.0.1".equals(origin.getHost()) || "localhost".equals(origin.getHost()))
                    && origin.getUserInfo() == null;
        } catch (IllegalArgumentException e) { return false; }
    }
}
