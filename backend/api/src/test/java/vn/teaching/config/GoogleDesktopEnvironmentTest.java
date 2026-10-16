package vn.teaching.config;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.springframework.core.env.MapPropertySource;
import org.springframework.mock.env.MockEnvironment;
import java.nio.file.*;
import java.util.Map;
import static org.junit.jupiter.api.Assertions.*;

class GoogleDesktopEnvironmentTest {
    @TempDir Path root;

    private void client() throws Exception {
        Files.writeString(root.resolve("google-desktop-client.json"),
                "{\"installed\":{\"client_id\":\"test-client\",\"client_secret\":\"test-secret\"}}");
    }

    @Test void discoversFromBackendAndKeepsKeyAcrossRestarts() throws Exception {
        client();
        Path backend = Files.createDirectories(root.resolve("backend/api"));
        MockEnvironment first = new MockEnvironment().withProperty("server.port", "49001");
        GoogleDesktopEnvironment.configure(first, backend);
        assertEquals("test-client", first.getProperty("GOOGLE_CLIENT_ID"));
        assertEquals("test-secret", first.getProperty("HOC_LUC_GOOGLE_CLIENT_SECRET"));
        assertEquals("http://127.0.0.1:49001/api/integrations/google/callback", first.getProperty("HOC_LUC_GOOGLE_REDIRECT_URI"));
        MockEnvironment second = new MockEnvironment();
        GoogleDesktopEnvironment.configure(second, root);
        assertEquals(first.getProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY"), second.getProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY"));
        assertEquals(32, java.util.Base64.getDecoder().decode(second.getProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY")).length);
    }

    @Test void existingEnvironmentWins() throws Exception {
        client();
        MockEnvironment env = new MockEnvironment().withProperty("GOOGLE_CLIENT_ID", "override")
                .withProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY", "external-key");
        GoogleDesktopEnvironment.configure(env, root);
        assertEquals("override", env.getProperty("GOOGLE_CLIENT_ID"));
        assertEquals("external-key", env.getProperty("HOC_LUC_GOOGLE_ENCRYPTION_KEY"));
        assertFalse(Files.exists(root.resolve(".hocluc-local")));
    }

    @Test void springPlaceholdersResolveFromDefaults() throws Exception {
        client();
        MockEnvironment env = new MockEnvironment();
        env.getPropertySources().addFirst(new MapPropertySource("application", Map.of(
                "app.integrations.google.client-id", "${HOC_LUC_GOOGLE_CLIENT_ID:}",
                "app.integrations.google.encryption-key", "${HOC_LUC_GOOGLE_ENCRYPTION_KEY:}")));
        GoogleDesktopEnvironment.configure(env, root);
        assertEquals("test-client", env.getProperty("app.integrations.google.client-id"));
        assertFalse(env.getProperty("app.integrations.google.encryption-key").isBlank());
    }

    @Test void absentFileLeavesGoogleOptional() {
        MockEnvironment env = new MockEnvironment();
        GoogleDesktopEnvironment.configure(env, root);
        assertNull(env.getProperty("GOOGLE_CLIENT_ID"));
    }

    @Test void projectEnvWinsOverJsonAndSharesClient() throws Exception {
        client();
        Files.writeString(root.resolve(".env"), "# shared config\nexport GOOGLE_CLIENT_ID='env-client'\nGOOGLE_CLIENT_SECRET=\"env-secret\"\nEXAM_ADMIN_EMAIL=teacher@example.com\n");
        MockEnvironment env = new MockEnvironment().withProperty("GOOGLE_CLIENT_SECRET", "process-secret");
        GoogleDesktopEnvironment.configure(env, Files.createDirectories(root.resolve("backend/api")));
        assertEquals("env-client", env.getProperty("GOOGLE_CLIENT_ID"));
        assertEquals("env-client", env.getProperty("HOC_LUC_GOOGLE_CLIENT_ID"));
        assertEquals("process-secret", env.getProperty("HOC_LUC_GOOGLE_CLIENT_SECRET"));
        assertEquals("teacher@example.com", env.getProperty("EXAM_ADMIN_EMAIL"));
        assertTrue(Files.isRegularFile(root.resolve(".hocluc-local/google-encryption.key")));
    }

    @Test void unrelatedEnvDoesNotRequireGoogle() throws Exception {
        Files.writeString(root.resolve(".env"), "EXAM_ADMIN_EMAIL=teacher@example.com\n");
        MockEnvironment env = new MockEnvironment();
        GoogleDesktopEnvironment.configure(env, root);
        assertEquals("teacher@example.com", env.getProperty("EXAM_ADMIN_EMAIL"));
        assertNull(env.getProperty("GOOGLE_CLIENT_ID"));
    }

    @Test void malformedEnvFailsWithoutPrintingValue() throws Exception {
        Files.writeString(root.resolve(".env"), "GOOGLE_CLIENT_SECRET='do-not-log\n");
        var error = assertThrows(IllegalStateException.class,
                () -> GoogleDesktopEnvironment.configure(new MockEnvironment(), root));
        assertFalse(error.toString().contains("do-not-log"));
        assertNull(error.getCause());
    }

    @Test void explicitMissingOrInvalidFileFailsWithoutLeakingSecrets() throws Exception {
        MockEnvironment env = new MockEnvironment().withProperty("HOCLUC_GOOGLE_CLIENT_FILE", "missing.json");
        assertThrows(IllegalStateException.class, () -> GoogleDesktopEnvironment.configure(env, root));
        Files.writeString(root.resolve("google-desktop-client.json"), "{\"secret\":\"do-not-log\"");
        var error = assertThrows(IllegalStateException.class,
                () -> GoogleDesktopEnvironment.configure(new MockEnvironment(), root));
        assertFalse(error.toString().contains("do-not-log"));
        assertNull(error.getCause());
    }

    @Test void corruptKeyIsNeverReplaced() throws Exception {
        client();
        Path key = root.resolve(".hocluc-local/google-encryption.key");
        Files.createDirectories(key.getParent());
        Files.writeString(key, "invalid");
        assertThrows(IllegalStateException.class,
                () -> GoogleDesktopEnvironment.configure(new MockEnvironment(), root));
        assertEquals("invalid", Files.readString(key));
    }
}
