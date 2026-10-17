package vn.teaching.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.env.EnvironmentPostProcessor;
import org.springframework.core.Ordered;
import org.springframework.core.env.ConfigurableEnvironment;
import org.springframework.core.env.MapPropertySource;

import java.io.IOException;
import java.nio.file.*;
import java.security.SecureRandom;
import java.util.*;

/** Local runtime defaults only: credentials never enter the jar or Flutter assets. */
public class GoogleDesktopEnvironment implements EnvironmentPostProcessor, Ordered {
    @Override public int getOrder() { return Ordered.LOWEST_PRECEDENCE; }

    @Override public void postProcessEnvironment(ConfigurableEnvironment env, SpringApplication app) {
        configure(env, Path.of(System.getProperty("user.dir")));
    }

    static void configure(ConfigurableEnvironment env, Path workingDirectory) {
        Path envFile = discover(workingDirectory, ".env");
        if (envFile != null) {
            try {
                Map<String, Object> values = new LinkedHashMap<>();
                for (String line : Files.readAllLines(envFile)) {
                    String entry = line.strip();
                    if (entry.isEmpty() || entry.startsWith("#")) continue;
                    if (entry.startsWith("export ")) entry = entry.substring(7).strip();
                    int separator = entry.indexOf('=');
                    if (separator < 1) throw new IOException("Expected NAME=value");
                    String name = entry.substring(0, separator).strip();
                    String value = entry.substring(separator + 1).strip();
                    if (!name.matches("[A-Za-z_][A-Za-z0-9_]*")) throw new IOException("Invalid variable name");
                    if (value.startsWith("\"") || value.startsWith("'")) {
                        if (value.length() < 2 || value.charAt(value.length() - 1) != value.charAt(0))
                            throw new IOException("Unclosed quote");
                        value = value.substring(1, value.length() - 1);
                    }
                    values.put(name, value);
                }
                env.getPropertySources().addLast(new MapPropertySource("projectEnv", values));
            } catch (IOException e) {
                throw new IllegalStateException("Cannot load project .env; use one NAME=value per line.");
            }
        }
        String explicit = env.getProperty("HOCLUC_GOOGLE_CLIENT_FILE", "");
        Path file = envFile != null && explicit.isBlank() ? envFile
                : explicit.isBlank() ? discover(workingDirectory, "google-desktop-client.json") : workingDirectory.resolve(explicit).normalize();
        if (file == null) return; // Google remains optional for installations without credentials.
        try {
            JsonNode client = file.equals(envFile) ? new ObjectMapper().createObjectNode()
                    : new ObjectMapper().readTree(Files.readString(file)).path("installed");
            String id = env.getProperty("GOOGLE_CLIENT_ID", client.path("client_id").asText(""));
            String secret = env.getProperty("GOOGLE_CLIENT_SECRET", client.path("client_secret").asText(""));
            if (file.equals(envFile) && id.isBlank() && secret.isBlank()) return;
            if (id.isBlank() || secret.isBlank()) {
                throw new IOException("Expected installed.client_id and installed.client_secret");
            }
            Map<String, Object> defaults = new LinkedHashMap<>();
            defaults.put("GOOGLE_CLIENT_ID", id);
            defaults.put("GOOGLE_CLIENT_SECRET", secret);
            defaults.put("HOC_LUC_GOOGLE_CLIENT_ID", id);
            defaults.put("HOC_LUC_GOOGLE_CLIENT_SECRET", secret);
            String base = "http://127.0.0.1:" + env.getProperty("server.port", "47831");
            defaults.put("GOOGLE_REDIRECT_URI", base + "/api/auth/google/callback");
            defaults.put("HOC_LUC_GOOGLE_REDIRECT_URI", base + "/api/integrations/google/callback");
            if (env.getProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY", "").isBlank()
                    && env.getProperty("app.integrations.google.encryption-key", "").isBlank()) {
                Path key = file.toAbsolutePath().getParent().resolve(".hocluc-local/google-encryption.key");
                defaults.put("HOC_LUC_GOOGLE_ENCRYPTION_KEY", persistentKey(key));
            }
            env.getPropertySources().addLast(new MapPropertySource("googleDesktopDefaults", defaults));
        } catch (IOException | RuntimeException e) {
            // Do not include the JSON or parser exception: either can contain credentials.
            throw new IllegalStateException("Cannot load local Google desktop configuration. Check "
                    + ".env or google-desktop-client.json and .hocluc-local/google-encryption.key.");
        }
    }

    private static Path discover(Path directory, String name) {
        for (Path current = directory.toAbsolutePath(); current != null; current = current.getParent()) {
            Path candidate = current.resolve(name);
            if (Files.isRegularFile(candidate)) return candidate;
            if (Files.exists(current.resolve(".git"))) break;
        }
        return null;
    }

    static String persistentKey(Path file) throws IOException {
        Files.createDirectories(file.getParent());
        if (!Files.exists(file)) {
            byte[] bytes = new byte[32];
            new SecureRandom().nextBytes(bytes);
            try {
                Files.writeString(file, Base64.getEncoder().encodeToString(bytes), StandardOpenOption.CREATE_NEW);
            } catch (FileAlreadyExistsException ignored) { /* Another process created the shared key. */ }
        }
        String encoded = Files.readString(file).trim();
        try {
            if (Base64.getDecoder().decode(encoded).length == 32) return encoded;
        } catch (IllegalArgumentException ignored) { }
        throw new IOException("Invalid local encryption key; restore the original key, do not regenerate it.");
    }
}
