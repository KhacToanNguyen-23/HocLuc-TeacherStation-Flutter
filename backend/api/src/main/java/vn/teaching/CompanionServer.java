package vn.teaching;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.io.File;
import java.nio.file.Files;
import java.util.List;

@SpringBootApplication
public class CompanionServer {
    private static final Logger log = LoggerFactory.getLogger(CompanionServer.class);

    public static void main(String[] args) {
        loadDotEnv();
        log.info("[companion-server] Starting application");

        String parent = System.getenv("HOC_LUC_PARENT_PID");
        if (parent != null) {
            try {
                long parentId = Long.parseLong(parent);
                ProcessHandle owner = ProcessHandle.of(parentId).orElse(null);
                Thread watcher = new Thread(() -> {
                    try {
                        while (owner != null && owner.isAlive()) {
                            Thread.sleep(1000);
                        }
                    } catch (InterruptedException ignored) {
                        Thread.currentThread().interrupt();
                    }
                    log.info("[companion-server] Desktop parent process exited; shutting down");
                    System.exit(0);
                }, "desktop-parent-watch");
                watcher.setDaemon(true);
                watcher.start();
            } catch (Exception e) {
                log.warn("[companion-server] Could not start desktop parent watcher", e);
            }
        }

        SpringApplication.run(CompanionServer.class, args);
    }

    private static void loadDotEnv() {
        File[] candidates = new File[] {
            new File(".env"),
            new File("../.env"),
            new File("../../.env"),
            new File(System.getProperty("user.dir", "."), ".env"),
            new File(System.getProperty("user.dir", "."), "../.env")
        };
        for (File file : candidates) {
            if (file.exists() && file.isFile()) {
                try {
                    List<String> lines = Files.readAllLines(file.toPath());
                    for (String raw : lines) {
                        String line = raw.trim();
                        if (line.isEmpty() || line.startsWith("#")) continue;
                        int idx = line.indexOf('=');
                        if (idx > 0) {
                            String key = line.substring(0, idx).trim();
                            String val = line.substring(idx + 1).trim();
                            if ((val.startsWith("\"") && val.endsWith("\"")) || (val.startsWith("'") && val.endsWith("'"))) {
                                val = val.substring(1, val.length() - 1);
                            }
                            if (System.getProperty(key) == null) {
                                System.setProperty(key, val);
                            }
                            if (key.equals("GOOGLE_CLIENT_ID") && System.getProperty("HOC_LUC_GOOGLE_CLIENT_ID") == null) {
                                System.setProperty("HOC_LUC_GOOGLE_CLIENT_ID", val);
                            }
                            if (key.equals("GOOGLE_CLIENT_SECRET") && System.getProperty("HOC_LUC_GOOGLE_CLIENT_SECRET") == null) {
                                System.setProperty("HOC_LUC_GOOGLE_CLIENT_SECRET", val);
                            }
                        }
                    }
                    break;
                } catch (Exception e) {
                    log.warn("[companion-server] Could not load environment file {}", file.getName(), e);
                }
            }
        }
    }
}
