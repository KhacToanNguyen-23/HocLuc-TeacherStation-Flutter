package vn.teaching;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

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

        SpringApplication.run(CompanionServer.class, args);
    }
}
