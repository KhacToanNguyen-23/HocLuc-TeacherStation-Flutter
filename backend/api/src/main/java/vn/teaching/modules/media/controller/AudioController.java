package vn.teaching.modules.media.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import vn.teaching.modules.media.service.AudioRuntimeService;
import java.util.Map;

@RestController
@RequestMapping("/api/audio")
public class AudioController {
    private final AudioRuntimeService runtime;
    public AudioController(AudioRuntimeService runtime) { this.runtime=runtime; }
    private void local(HttpServletRequest request) {
        if(!loopback(request.getRemoteAddr())||!loopback(request.getLocalAddr())||!loopback(request.getServerName()))
            throw new IllegalArgumentException("Audio runtime chỉ dùng trên máy này.");
        String origin=request.getHeader("Origin");
        if(origin!=null&&!loopback(java.net.URI.create(origin).getHost())) throw new IllegalArgumentException("Origin không hợp lệ.");
    }
    private boolean loopback(String host) { return "127.0.0.1".equals(host)||"localhost".equalsIgnoreCase(host)||"::1".equals(host)||"0:0:0:0:0:0:0:1".equals(host); }
    @GetMapping("/status") public Object status(HttpServletRequest request) { local(request); return runtime.status(); }
    @PostMapping("/connect") public ResponseEntity<?> connect(@RequestBody Map<String,String> input,HttpServletRequest request) {
        local(request);
        if(!"en".equals(input.get("language"))) return ResponseEntity.badRequest().body(Map.of("error","Chọn English để bật dịch."));
        try { return ResponseEntity.ok(runtime.connect(input.getOrDefault("voice","af_heart"),input.get("clientId"))); }
        catch(Exception e) { return ResponseEntity.status(503).body(Map.of("error",e.getMessage()==null?"Không khởi động được runtime.":e.getMessage())); }
    }
    @PostMapping("/stop") public Object stop(@RequestBody Map<String,String> input,HttpServletRequest request) { local(request); runtime.release(input.get("clientId")); return Map.of("stopped",true); }
    @PostMapping(value="/file",consumes="audio/wav") public ResponseEntity<?> file(@RequestBody byte[] bytes,@RequestParam(defaultValue="af_heart") String voice,@RequestParam String clientId,HttpServletRequest request) {
        local(request);
        try {return ResponseEntity.ok(runtime.file(bytes,voice,clientId));}
        catch(Exception e) {return ResponseEntity.status(503).body(Map.of("error",String.valueOf(e.getMessage())));}
    }
    @ExceptionHandler(IllegalArgumentException.class) public ResponseEntity<?> invalid(IllegalArgumentException e) { return ResponseEntity.badRequest().body(Map.of("error",e.getMessage())); }
}

