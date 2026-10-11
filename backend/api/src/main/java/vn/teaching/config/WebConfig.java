package vn.teaching.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;

@Configuration
public class WebConfig implements WebMvcConfigurer {
    private final SecurityTokenInterceptor securityTokenInterceptor;
    private final Path rootDirectory;

    public WebConfig(SecurityTokenInterceptor securityTokenInterceptor, Path rootDirectory) {
        this.securityTokenInterceptor = securityTokenInterceptor;
        this.rootDirectory = rootDirectory;
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/**")
                .allowedOriginPatterns("*")
                .allowedMethods("GET", "POST", "PUT", "DELETE", "OPTIONS", "HEAD")
                .allowedHeaders("*")
                .allowCredentials(false);
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(securityTokenInterceptor).addPathPatterns("/api/**");
    }

    @Override
    public void addResourceHandlers(ResourceHandlerRegistry registry) {
        Path flatPath = rootDirectory.resolve("backend/whiteboard-host/dist");
        Path webPath = rootDirectory.resolve("frontend/build/web");

        registry.addResourceHandler("/flat/**")
                .addResourceLocations(flatPath.toUri().toString());
        registry.addResourceHandler("/**")
                .addResourceLocations(webPath.toUri().toString());
    }
}
