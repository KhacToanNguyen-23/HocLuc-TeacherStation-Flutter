package vn.teaching.controller;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import java.util.Arrays;
import java.util.Map;

/** Ephemeral, local presentation frames; never reads lesson JSON or teacher notes. */
@RestController
@RequestMapping("/api/audience/frame")
public class AudienceFrameController {
    private byte[] frame;
    private String session;
    private long updatedAt;
    private static final byte[] PNG = {(byte)137,80,78,71,13,10,26,10};

    private void local(HttpServletRequest request, String id) {
        if (!java.util.Set.of("127.0.0.1","::1","0:0:0:0:0:0:0:1").contains(request.getRemoteAddr()))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.FORBIDDEN);
        if (id == null || !id.matches("[a-f0-9]{48}"))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.BAD_REQUEST);
    }

    @PostMapping(consumes="image/png")
    public synchronized Map<String,Object> update(@RequestHeader("X-Audience-Id") String id,
            @RequestBody byte[] bytes, HttpServletRequest request) {
        local(request,id);
        if(bytes.length < 8 || bytes.length > 2_000_000 || !Arrays.equals(PNG,Arrays.copyOf(bytes,8)))
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.BAD_REQUEST,"Invalid frame");
        if(session != null && !session.equals(id) && System.currentTimeMillis()-updatedAt < 10_000)
            throw new org.springframework.web.server.ResponseStatusException(HttpStatus.CONFLICT,"Presentation already open");
        session=id; frame=bytes.clone(); updatedAt=System.currentTimeMillis();
        return Map.of("received",true,"updatedAt",updatedAt);
    }

    @GetMapping(produces="image/png")
    public synchronized ResponseEntity<byte[]> read(@RequestHeader("X-Audience-Id") String id,
            HttpServletRequest request) {
        local(request,id);
        if(!id.equals(session) || frame==null || System.currentTimeMillis()-updatedAt > 5_000)
            return ResponseEntity.notFound().cacheControl(CacheControl.noStore()).build();
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(frame.clone());
    }

    @DeleteMapping
    public synchronized Map<String,Boolean> clear(@RequestHeader("X-Audience-Id") String id,
            HttpServletRequest request) {
        local(request,id);
        if(id.equals(session)) { frame=null; session=null; updatedAt=0; }
        return Map.of("cleared",true);
    }
}
