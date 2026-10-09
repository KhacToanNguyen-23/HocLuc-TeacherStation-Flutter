package vn.teaching;

import com.google.gson.*;
import com.sun.net.httpserver.*;
import javax.sound.sampled.*;
import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.security.SecureRandom;
import java.util.*;
import java.util.concurrent.Executors;

/** Local orchestration only. No audio inference, device driver or Meet scraping. */
public final class CompanionServer {
    private static final Gson JSON = new GsonBuilder().setPrettyPrinting().create();
    private final Path root;
    private final String token;
    private int port;
    private final Path dataDirectory;
    private final Object fileLock = new Object();

    private CompanionServer(Path root, int port, Path dataDirectory) {
        this.root = root.toAbsolutePath().normalize();
        this.port = port;
        this.dataDirectory = dataDirectory.toAbsolutePath().normalize();
        byte[] bytes = new byte[32]; new SecureRandom().nextBytes(bytes);
        token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static void main(String[] args) throws Exception {
        Path root = Path.of(args.length > 0 ? args[0] : "..");
        int port = args.length > 1 ? Integer.parseInt(args[1]) : 47831;
        Path data = args.length > 2 ? Path.of(args[2]) : root.resolve("service/data");
        new CompanionServer(root, port, data).start();
        String parent = System.getenv("HOC_LUC_PARENT_PID");
        if (parent != null) {
            long parentId = Long.parseLong(parent);
            ProcessHandle owner = ProcessHandle.of(parentId).orElse(null);
            Thread watcher = new Thread(() -> {
                try {
                    while (owner != null && owner.isAlive()) Thread.sleep(1000);
                } catch (InterruptedException ignored) { Thread.currentThread().interrupt(); }
                System.exit(0);
            }, "desktop-parent-watch");
            watcher.setDaemon(true); watcher.start();
        }
    }

    private void start() throws IOException {
        Files.createDirectories(dataDirectory);
        HttpServer server = HttpServer.create(new InetSocketAddress("127.0.0.1", port), 0);
        port = server.getAddress().getPort();
        server.createContext("/", this::handle);
        server.setExecutor(Executors.newFixedThreadPool(4));
        Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(0)));
        server.start();
        System.out.println("Teaching Companion: http://127.0.0.1:" + port);
    }

    private void handle(HttpExchange exchange) throws IOException {
        try {
            String origin = exchange.getRequestHeaders().getFirst("Origin");
            String host = exchange.getRequestHeaders().getFirst("Host");
            if (!("127.0.0.1:" + port).equals(host) && !("localhost:" + port).equals(host)) {
                send(exchange, 403, Map.of("error", "Unexpected host")); return;
            }
            Set<String> allowed = Set.of("http://127.0.0.1:" + port, "http://localhost:" + port);
            if (origin != null && !allowed.contains(origin)) {
                send(exchange, 403, Map.of("error", "Unexpected origin")); return;
            }
            if (origin != null) exchange.getResponseHeaders().set("Access-Control-Allow-Origin", origin);
            exchange.getResponseHeaders().set("X-Content-Type-Options", "nosniff");
            String method = exchange.getRequestMethod();
            String path = exchange.getRequestURI().getPath();
            if (path.startsWith("/api/")) {
                if (path.equals("/api/bootstrap") && method.equals("GET")) {
                    send(exchange, 200, Map.of("token", token, "version", "0.1.0")); return;
                }
                if (!token.equals(exchange.getRequestHeaders().getFirst("X-Companion-Token"))) {
                    send(exchange, 401, Map.of("error", "Local session required")); return;
                }
                routeApi(exchange, method, path); return;
            }
            if (!method.equals("GET") && !method.equals("HEAD")) {
                send(exchange, 405, Map.of("error", "Method not allowed")); return;
            }
            Path base = root.resolve(path.startsWith("/flat/") ? "whiteboard-host/dist" : "app/build/web");
            String relative = path.startsWith("/flat/") ? path.substring(6) : path.substring(1);
            if (relative.isEmpty()) relative = "index.html";
            Path file = base.resolve(relative).normalize();
            if (!file.startsWith(base) || !Files.isRegularFile(file)) {
                send(exchange, 404, Map.of("error", "Build the Flutter preview / whiteboard host first")); return;
            }
            exchange.getResponseHeaders().set("Content-Type", mime(file));
            exchange.getResponseHeaders().set("Cache-Control", "no-cache");
            if (method.equals("HEAD")) { exchange.sendResponseHeaders(200, -1); return; }
            exchange.sendResponseHeaders(200, Files.size(file));
            try (OutputStream out = exchange.getResponseBody()) { Files.copy(file, out); }
        } catch (JsonParseException | IllegalArgumentException exception) {
            send(exchange, 400, Map.of("error", "Invalid JSON object"));
        } catch (Exception exception) {
            System.err.println("Request failed: " + exception.getClass().getSimpleName());
            send(exchange, 500, Map.of("error", "Local service error"));
        } finally { exchange.close(); }
    }

    private void routeApi(HttpExchange exchange, String method, String path) throws IOException {
        if (path.equals("/api/capabilities") && method.equals("GET")) {
            send(exchange, 200, Map.of("javaService", true, "virtualCamera", false,
                "virtualMicrophone", false, "audioCapture", false, "cameraCapture", false,
                "aiStreaming", false, "meetInteraction", false,
                "flatHostBuilt", Files.isRegularFile(root.resolve("whiteboard-host/dist/index.html"))));
        } else if (path.equals("/api/devices") && method.equals("GET")) {
            List<Map<String, Object>> microphones = new ArrayList<>();
            for (Mixer.Info info : AudioSystem.getMixerInfo()) {
                try {
                    Mixer mixer = AudioSystem.getMixer(info);
                    if (Arrays.stream(mixer.getTargetLineInfo()).anyMatch(line -> TargetDataLine.class.isAssignableFrom(line.getLineClass()))) {
                        microphones.add(Map.of("id", info.getName() + "|" + info.getVendor(), "name", info.getName()));
                    }
                } catch (IllegalArgumentException ignored) { }
            }
            send(exchange, 200, Map.of("microphones", microphones, "cameras", List.of(),
                "note", "JavaSound enumeration only; capture and camera adapter not implemented"));
        } else if ((path.equals("/api/lesson") || path.equals("/api/config")) && method.equals("GET")) {
            Path file = dataFile(path);
            synchronized (fileLock) {
                JsonObject value = Files.exists(file) ? JsonParser.parseString(Files.readString(file)).getAsJsonObject() : new JsonObject();
                send(exchange, 200, value);
            }
        } else if ((path.equals("/api/lesson") || path.equals("/api/config")) && method.equals("PUT")) {
            byte[] bytes = exchange.getRequestBody().readNBytes(2_000_001);
            if (bytes.length > 2_000_000) { send(exchange, 413, Map.of("error", "Document too large")); return; }
            JsonElement parsed = JsonParser.parseString(new String(bytes, StandardCharsets.UTF_8));
            if (!parsed.isJsonObject()) { send(exchange, 400, Map.of("error", "Expected JSON object")); return; }
            JsonObject value = parsed.getAsJsonObject();
            synchronized (fileLock) {
                Path target = dataFile(path), temp = target.resolveSibling(target.getFileName() + ".tmp");
                Files.writeString(temp, JSON.toJson(value), StandardCharsets.UTF_8);
                try { Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE); }
                catch (AtomicMoveNotSupportedException ignored) { Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING); }
            }
            send(exchange, 200, Map.of("saved", true));
        } else if (path.equals("/api/output/start") && method.equals("POST")) {
            send(exchange, 501, Map.of("error", "Native virtual camera/microphone bridge is not installed"));
        } else { send(exchange, 404, Map.of("error", "Unknown API route or method")); }
    }

    private Path dataFile(String path) { return dataDirectory.resolve(path.endsWith("lesson") ? "lesson.json" : "config.json"); }
    private static void send(HttpExchange exchange, int status, Object body) throws IOException {
        byte[] bytes = JSON.toJson(body).getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.getResponseHeaders().set("Cache-Control", "no-store");
        exchange.sendResponseHeaders(status, bytes.length);
        try (OutputStream out = exchange.getResponseBody()) { out.write(bytes); }
    }
    private static String mime(Path file) {
        String name = file.toString();
        if (name.endsWith(".html")) return "text/html; charset=utf-8";
        if (name.endsWith(".js") || name.endsWith(".mjs")) return "text/javascript; charset=utf-8";
        if (name.endsWith(".css")) return "text/css; charset=utf-8";
        if (name.endsWith(".json")) return "application/json";
        if (name.endsWith(".wasm")) return "application/wasm";
        if (name.endsWith(".png")) return "image/png";
        if (name.endsWith(".svg")) return "image/svg+xml";
        if (name.endsWith(".woff2")) return "font/woff2";
        return "application/octet-stream";
    }
}
