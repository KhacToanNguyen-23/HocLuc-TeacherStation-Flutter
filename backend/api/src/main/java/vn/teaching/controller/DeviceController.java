package vn.teaching.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import vn.teaching.service.DeviceService;

import java.util.Map;

@RestController
@RequestMapping("/api")
public class DeviceController {
    private final DeviceService deviceService;

    public DeviceController(DeviceService deviceService) {
        this.deviceService = deviceService;
    }

    @GetMapping("/capabilities")
    public ResponseEntity<Map<String, Object>> handleCapabilities() {
        return ResponseEntity.ok(deviceService.getCapabilities());
    }

    @GetMapping("/devices")
    public ResponseEntity<Map<String, Object>> handleDevices() {
        return ResponseEntity.ok(deviceService.getAudioDevices());
    }
}
