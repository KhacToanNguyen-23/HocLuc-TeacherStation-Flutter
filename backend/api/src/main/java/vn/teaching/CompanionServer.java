package vn.teaching;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.web.context.WebServerInitializedEvent;
import java.util.HashMap;
import java.util.Map;

@SpringBootApplication
public class CompanionServer {

    public static void main(String[] args) {
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
                    System.exit(0);
                }, "desktop-parent-watch");
                watcher.setDaemon(true);
                watcher.start();
            } catch (Exception ignored) {}
        }

        SpringApplication application = new SpringApplication(CompanionServer.class);
        // Preserve the positional launcher contract used by the desktop shell.
        Map<String, Object> defaults = new HashMap<>();
        if (args.length > 0 && !args[0].startsWith("--")) {
            defaults.put("companion.root-directory", args[0]);
            if (args.length > 1) defaults.put("server.port", args[1]);
            if (args.length > 2) defaults.put("companion.data-directory", args[2]);
            args = new String[0];
        }
        // Command-line properties override application.properties (including port 0).
        String[] launchArgs = defaults.entrySet().stream()
                .map(entry -> "--" + entry.getKey() + "=" + entry.getValue())
                .toArray(String[]::new);
        if (launchArgs.length == 0) launchArgs = args;
        application.addListeners((org.springframework.context.ApplicationListener<WebServerInitializedEvent>) event ->
                System.out.println("Teaching Companion: http://127.0.0.1:" + event.getWebServer().getPort()));
        application.run(launchArgs);
    }
}
