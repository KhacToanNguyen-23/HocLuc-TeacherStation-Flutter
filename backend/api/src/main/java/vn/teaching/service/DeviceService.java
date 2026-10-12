package vn.teaching.service;

import org.springframework.stereotype.Service;

import javax.sound.sampled.AudioSystem;
import javax.sound.sampled.Mixer;
import javax.sound.sampled.TargetDataLine;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

@Service
public class DeviceService {
    private final Path root;

    public DeviceService(Path rootDirectory) {
        this.root = rootDirectory;
    }

    public Map<String, Object> getCapabilities() {
        return Map.of(
            "javaService", true,
            "virtualCamera", false,
            "virtualMicrophone", false,
            "audioCapture", false,
            "cameraCapture", false,
            "aiStreaming", false,
            "meetInteraction", false,
            "flatHostBuilt", Files.isRegularFile(root.resolve("backend/whiteboard-host/dist/index.html"))
                || Files.isRegularFile(root.resolve("whiteboard-host/index.html"))
        );
    }

    public Map<String, Object> getAudioDevices() {
        List<Map<String, Object>> microphones = new ArrayList<>();
        for (Mixer.Info info : AudioSystem.getMixerInfo()) {
            try {
                Mixer mixer = AudioSystem.getMixer(info);
                if (Arrays.stream(mixer.getTargetLineInfo()).anyMatch(line -> TargetDataLine.class.isAssignableFrom(line.getLineClass()))) {
                    microphones.add(Map.of(
                        "id", info.getName() + "|" + info.getVendor(),
                        "name", info.getName()
                    ));
                }
            } catch (IllegalArgumentException ignored) {}
        }
        return Map.of(
            "microphones", microphones,
            "cameras", List.of(),
            "note", "JavaSound enumeration only; capture and camera adapter not implemented"
        );
    }
}
