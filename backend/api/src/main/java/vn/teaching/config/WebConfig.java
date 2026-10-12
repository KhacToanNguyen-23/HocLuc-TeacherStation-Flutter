package vn.teaching.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.ResourceHandlerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

import java.nio.file.Path;
import java.nio.file.Files;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;

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
        boolean packaged = Files.isDirectory(rootDirectory.resolve("app/build/web"));
        Path flatPath = rootDirectory.resolve(packaged ? "whiteboard-host" : "backend/whiteboard-host/dist");
        Path webPath = rootDirectory.resolve(packaged ? "app/build/web" : "frontend/build/web");

        registry.addResourceHandler("/flat/**")
                .addResourceLocations(directoryUri(flatPath));
        registry.addResourceHandler("/**")
                .addResourceLocations(directoryUri(webPath));
    }

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        registry.addViewController("/").setViewName("forward:/index.html");
    }

    private static String directoryUri(Path directory) {
        String uri = directory.toUri().toString();
        return uri.endsWith("/") ? uri : uri + "/";
    }
}
