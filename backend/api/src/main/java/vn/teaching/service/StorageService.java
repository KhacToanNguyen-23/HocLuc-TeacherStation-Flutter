package vn.teaching.service;

import com.google.gson.Gson;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

@Service
public class StorageService {
    private final Path dataDirectory;
    private final Object fileLock = new Object();
    private final Gson gson;

    public StorageService(Path dataDirectory, Gson gson) {
        this.dataDirectory = dataDirectory;
        this.gson = gson;
    }

    public JsonObject readDocument(String type) throws IOException {
        Path file = dataFile(type);
        synchronized (fileLock) {
            if (Files.exists(file)) {
                return JsonParser.parseString(Files.readString(file, StandardCharsets.UTF_8)).getAsJsonObject();
            }
            return new JsonObject();
        }
    }

    public void saveDocument(String type, JsonObject value) throws IOException {
        synchronized (fileLock) {
            Path target = dataFile(type);
            Path temp = target.resolveSibling(target.getFileName() + ".tmp");
            Files.writeString(temp, gson.toJson(value), StandardCharsets.UTF_8);
            try {
                Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
            } catch (AtomicMoveNotSupportedException ignored) {
                Files.move(temp, target, StandardCopyOption.REPLACE_EXISTING);
            }
        }
    }

    public Path dataFile(String path) {
        return dataDirectory.resolve(path.endsWith("lesson") ? "lesson.json" : "config.json");
    }
}
