package vn.teaching.modules.media.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PreDestroy;
import org.springframework.stereotype.Service;
import java.io.IOException;
import java.net.*;
import java.net.http.*;
import java.nio.file.*;
import java.time.Duration;
import java.security.SecureRandom;
import java.util.*;

/** One lazy, loopback-only inference process. No microphone access in Java. */
@Service
public class AudioRuntimeService {
    private final Path root;
    private final ObjectMapper mapper;
    private final HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();
    private Process worker;
    private String token;
    private int port;
    private final Set<String> leases = new HashSet<>();

    public AudioRuntimeService(Path rootDirectory, ObjectMapper mapper) { this.root=rootDirectory; this.mapper=mapper; }
    private Path directory() { return root.resolve("backend/ai-runtime"); }
    private Path python() {
        String override=System.getenv("HOC_LUC_AI_PYTHON");
        return override==null||override.isBlank()?directory().resolve(".venv/Scripts/python.exe"):Path.of(override);
    }
    public synchronized Map<String,Object> status() {
        Map<String,Object> result=new LinkedHashMap<>();
        result.put("installed",Files.isRegularFile(python())&&Files.isRegularFile(directory().resolve("server.py")));
        result.put("running",worker!=null&&worker.isAlive());
        result.put("supportedLanguages",List.of("en"));
        result.put("denoiseReady",false);
        if(worker!=null&&worker.isAlive()) {
            try { result.putAll(health()); } catch(Exception e) { result.put("ready",false); }
        } else { result.put("ready",false); result.put("modelsLoaded",false); }
        return result;
    }
    private Map<String,Object> health() throws Exception {
        var req=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/health"))
            .header("X-AI-Token",token).timeout(Duration.ofSeconds(2)).GET().build();
        var res=client.send(req,HttpResponse.BodyHandlers.ofString());
        if(res.statusCode()!=200) throw new IOException("Runtime health unavailable");
        return mapper.readValue(res.body(),new TypeReference<>(){});
    }
    public synchronized Map<String,Object> connect(String voice,String owner) throws Exception {
        if(owner==null||!owner.matches("[A-Za-z0-9_-]{16,64}")) throw new IllegalArgumentException("Audio client ID không hợp lệ.");
        if(!voice.matches("[ab][fm]_[a-z]+")) throw new IllegalArgumentException("Giọng English không hợp lệ.");
        if(worker==null||!worker.isAlive()) {
            leases.clear();
            if(!Files.isRegularFile(python())) throw new IOException("Chưa cài AI runtime. Chạy scripts/Setup-AiRuntime.ps1.");
            byte[] proof=new byte[32]; new SecureRandom().nextBytes(proof);
            token=Base64.getUrlEncoder().withoutPadding().encodeToString(proof);
            try(var socket=new java.net.ServerSocket(0,1,InetAddress.getLoopbackAddress())) { port=socket.getLocalPort(); }
            Files.createDirectories(root.resolve(".run"));
            var process=new ProcessBuilder(python().toString(),"server.py","--port",Integer.toString(port)).directory(directory().toFile());
            process.environment().put("HOC_LUC_AI_TOKEN",token);
            process.environment().put("HOC_LUC_AI_PARENT_PID",Long.toString(ProcessHandle.current().pid()));
            process.environment().put("HF_HOME",root.resolve(".run/ai-hf-cache").toString());
            process.environment().put("HF_HUB_OFFLINE","1");
            process.environment().put("TOKENIZERS_PARALLELISM","false");
            process.redirectErrorStream(true).redirectOutput(ProcessBuilder.Redirect.appendTo(root.resolve(".run/ai-runtime.log").toFile()));
            worker=process.start();
        }
        Map<String,Object> ready=null;
        for(int i=0;i<30;i++) {
            if(!worker.isAlive()) throw new IOException("AI runtime đã dừng. Kiểm tra .run/ai-runtime.log.");
            try { ready=health(); break; } catch(Exception e) { Thread.sleep(150); }
        }
        if(ready==null) throw new IOException("AI runtime chưa trả lời.");
        if(!Boolean.TRUE.equals(ready.get("assetsReady"))) throw new IOException("Thiếu asset model local: "+ready.get("missing"));
        leases.add(owner);
        return Map.of("url","ws://127.0.0.1:"+port+"/stream?token="+token+"&voice="+voice,"status",ready);
    }
    @PreDestroy public synchronized void stop() {
        if(worker!=null) {
            worker.descendants().forEach(ProcessHandle::destroy);
            worker.destroy();
            try { if(!worker.waitFor(2,java.util.concurrent.TimeUnit.SECONDS)) worker.destroyForcibly(); }
            catch(InterruptedException e) { Thread.currentThread().interrupt(); worker.destroyForcibly(); }
        }
        worker=null; token=null; leases.clear();
    }
    public synchronized void release(String owner) {
        if(owner==null||!leases.remove(owner)) return;
        if(leases.isEmpty()) stop();
    }
    public Map<String,Object> file(byte[] wav,String voice,String owner) throws Exception {
        if(wav.length>4_000_000) throw new IllegalArgumentException("WAV tối đa 4 MB và 15 giây.");
        HttpRequest req;
        synchronized(this) {
            connect(voice,owner);
            req=HttpRequest.newBuilder(URI.create("http://127.0.0.1:"+port+"/file?voice="+voice))
                .header("X-AI-Token",token).header("Content-Type","audio/wav").timeout(Duration.ofSeconds(180))
                .POST(HttpRequest.BodyPublishers.ofByteArray(wav)).build();
        }
        var res=client.send(req,HttpResponse.BodyHandlers.ofString());
        if(res.statusCode()!=200) {
            var problem=mapper.readValue(res.body(),new TypeReference<Map<String,Object>>(){});
            throw new IOException(String.valueOf(problem.getOrDefault("detail","Không xử lý được WAV.")));
        }
        return mapper.readValue(res.body(),new TypeReference<>(){});
    }
}

