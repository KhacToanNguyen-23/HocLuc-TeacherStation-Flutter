package vn.teaching.config;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.SecureRandom;
import java.util.Base64;

@Configuration
public class CompanionConfig {

    @Bean
    public Gson gson() {
        return new GsonBuilder().setPrettyPrinting().create();
    }

    @Bean
    public Path dataDirectory() throws IOException {
        Path current = Path.of("").toAbsolutePath().normalize();
        Path dataDir;
        if (current.endsWith("api") || current.endsWith("service")) {
            dataDir = current.resolve("data");
        } else {
            dataDir = current.resolve("backend/api/data");
        }
        Files.createDirectories(dataDir);
        return dataDir;
    }

    @Bean
    public Path rootDirectory() {
        Path current = Path.of("").toAbsolutePath().normalize();
        if (current.endsWith("api") || current.endsWith("service")) {
            return current.getParent().getParent();
        }
        return current;
    }

    @Bean
    public String companionToken() {
        byte[] bytes = new byte[32];
        new SecureRandom().nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
