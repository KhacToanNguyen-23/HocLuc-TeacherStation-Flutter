package vn.teaching.preparation;

import jakarta.servlet.MultipartConfigElement;
import org.springframework.boot.autoconfigure.web.servlet.MultipartProperties;
import org.springframework.context.annotation.*;
import org.springframework.beans.factory.annotation.Qualifier;
import java.nio.file.*;
import java.io.IOException;

@Configuration
public class PreparationMultipartConfig {
    @Bean MultipartConfigElement multipartConfigElement(MultipartProperties properties,@Qualifier("dataDirectory") Path data)throws IOException{
        String configured=properties.getLocation();
        Path spool=configured==null||configured.isBlank()?data.resolve("preparation/incoming"):Path.of(configured);
        Files.createDirectories(spool);properties.setLocation(spool.toAbsolutePath().normalize().toString());
        return properties.createMultipartConfig();
    }
}
