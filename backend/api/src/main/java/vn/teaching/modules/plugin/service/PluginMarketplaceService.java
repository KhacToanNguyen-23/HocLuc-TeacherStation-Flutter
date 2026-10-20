package vn.teaching.modules.plugin.service;

import com.google.gson.Gson;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.reflect.TypeToken;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import vn.teaching.modules.plugin.dto.PluginCatalogItemDto;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Base64;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;
import java.util.zip.ZipInputStream;
import java.util.zip.ZipOutputStream;

@Service
public class PluginMarketplaceService {
    private static final Logger log = LoggerFactory.getLogger(PluginMarketplaceService.class);
    private static final byte[] FALLBACK_ICON_PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    );

    private final Path rootDirectory;
    private final Path marketplaceStorageDir;
    private final Gson gson;
    private final Object lock = new Object();

    public PluginMarketplaceService(Path rootDirectory, Path dataDirectory, Gson gson) throws IOException {
        this.rootDirectory = rootDirectory;
        this.marketplaceStorageDir = dataDirectory.resolve("marketplace-plugins");
        this.gson = gson;
        Files.createDirectories(this.marketplaceStorageDir);
    }

    public List<PluginCatalogItemDto> getCatalog() {
        synchronized (lock) {
            Map<String, PluginCatalogItemDto> itemsById = new LinkedHashMap<>();
            Map<String, Path> pathsById = new LinkedHashMap<>();
            scanAllPackages(itemsById, pathsById);
            List<PluginCatalogItemDto> result = new ArrayList<>(itemsById.values());
            result.sort(Comparator.comparing(PluginCatalogItemDto::getName, String.CASE_INSENSITIVE_ORDER));
            return result;
        }
    }

    public PluginCatalogItemDto getPluginMetadata(String pluginId) {
        if (pluginId == null || pluginId.isBlank()) return null;
        synchronized (lock) {
            Map<String, PluginCatalogItemDto> itemsById = new LinkedHashMap<>();
            Map<String, Path> pathsById = new LinkedHashMap<>();
            scanAllPackages(itemsById, pathsById);
            return itemsById.get(pluginId);
        }
    }

    public Path getPluginPackagePath(String pluginId) {
        if (pluginId == null || pluginId.isBlank()) return null;
        synchronized (lock) {
            Map<String, PluginCatalogItemDto> itemsById = new LinkedHashMap<>();
            Map<String, Path> pathsById = new LinkedHashMap<>();
            scanAllPackages(itemsById, pathsById);
            return pathsById.get(pluginId);
        }
    }

    public byte[] getPluginIconBytes(String pluginId) {
        Path packagePath = getPluginPackagePath(pluginId);
        if (packagePath == null || !Files.exists(packagePath)) {
            return null;
        }
        try (ZipFile zipFile = new ZipFile(packagePath.toFile())) {
            var entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                if (!entry.isDirectory()) {
                    String norm = entry.getName().replace('\\', '/');
                    if (norm.equals("icon.png") || norm.endsWith("/icon.png")) {
                        try (InputStream is = zipFile.getInputStream(entry)) {
                            return is.readAllBytes();
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.err.println("[PluginMarketplaceService] Failed to read icon for " + pluginId + ": " + e.getMessage());
        }
        return FALLBACK_ICON_PNG;
    }

    public PluginCatalogItemDto publishPluginPackage(byte[] packageBytes) throws IOException {
        if (packageBytes == null || packageBytes.length == 0) {
            throw new IllegalArgumentException("Gói plugin tải lên bị rỗng.");
        }
        JsonObject manifest = extractManifestFromBytes(packageBytes);
        if (manifest == null) {
            throw new IllegalArgumentException("Gói .hlep không chứa tệp manifest.json hợp lệ.");
        }
        String id = getString(manifest, "id", "").trim();
        String name = getString(manifest, "name", "").trim();
        if (id.isEmpty() || name.isEmpty() || id.contains("..") || id.contains("/") || id.contains("\\")) {
            throw new IllegalArgumentException("manifest.json thiếu trường id hoặc name hợp lệ.");
        }

        synchronized (lock) {
            String safeFileName = id.replaceAll("[^a-zA-Z0-9._-]", "_") + ".hlep";
            Path targetPath = marketplaceStorageDir.resolve(safeFileName);
            Files.write(targetPath, packageBytes);
            return inspectHlepPackage(targetPath);
        }
    }

    private void scanAllPackages(
            Map<String, PluginCatalogItemDto> itemsById,
            Map<String, Path> pathsById
    ) {
        List<Path> candidateDirs = new ArrayList<>();
        String customDir = System.getenv("HOCLUC_MARKETPLACE_DIR");
        if (customDir != null && !customDir.isBlank()) {
            candidateDirs.add(Paths.get(customDir));
        }
        if (rootDirectory != null) {
            candidateDirs.add(rootDirectory.resolve("plugins"));
        }
        candidateDirs.add(Paths.get("plugins"));
        candidateDirs.add(Paths.get("../plugins"));
        candidateDirs.add(Paths.get("../../plugins"));
        candidateDirs.add(marketplaceStorageDir);

        for (Path dir : candidateDirs) {
            if (dir == null || !Files.exists(dir) || !Files.isDirectory(dir)) {
                continue;
            }
            // 1. Auto-pack unpacked plugin folders that have manifest.json if no .hlep exists yet
            try (DirectoryStream<Path> subDirs = Files.newDirectoryStream(dir)) {
                for (Path entry : subDirs) {
                    if (Files.isDirectory(entry)) {
                        Path manifestPath = entry.resolve("manifest.json");
                        if (Files.exists(manifestPath)) {
                            Path siblingHlep = dir.resolve(entry.getFileName().toString() + ".hlep");
                            Path cachedHlep = marketplaceStorageDir.resolve(entry.getFileName().toString() + ".hlep");
                            if (!Files.exists(siblingHlep) && !Files.exists(cachedHlep)) {
                                try {
                                    packDirectoryToHlep(entry, cachedHlep);
                                } catch (Exception e) {
                                    System.err.println("[PluginMarketplaceService] Auto-pack warning for " + entry + ": " + e.getMessage());
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                log.warn("[marketplace] Failed to scan plugin directories | cause={}", e.getMessage());
            }

            // 2. Scan all .hlep files in directory
            try (DirectoryStream<Path> hlepStream = Files.newDirectoryStream(dir, "*.hlep")) {
                for (Path hlepPath : hlepStream) {
                    if (!Files.isRegularFile(hlepPath)) continue;
                    PluginCatalogItemDto dto = inspectHlepPackage(hlepPath);
                    if (dto != null && dto.getId() != null && !dto.getId().isBlank()) {
                        itemsById.put(dto.getId(), dto);
                        pathsById.put(dto.getId(), hlepPath);
                    }
                }
            } catch (Exception e) {
                System.err.println("[PluginMarketplaceService] Error scanning " + dir + ": " + e.getMessage());
            }
        }
    }

    private PluginCatalogItemDto inspectHlepPackage(Path hlepPath) {
        try (ZipFile zipFile = new ZipFile(hlepPath.toFile())) {
            ZipEntry manifestEntry = null;
            var entries = zipFile.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                if (!entry.isDirectory()) {
                    String norm = entry.getName().replace('\\', '/');
                    if (norm.equals("manifest.json") || norm.endsWith("/manifest.json")) {
                        manifestEntry = entry;
                        break;
                    }
                }
            }
            if (manifestEntry == null) return null;

            String manifestJsonStr;
            try (InputStream is = zipFile.getInputStream(manifestEntry)) {
                manifestJsonStr = new String(is.readAllBytes(), StandardCharsets.UTF_8);
            }

            JsonObject json = JsonParser.parseString(manifestJsonStr).getAsJsonObject();
            String id = getString(json, "id", "");
            if (id.isEmpty()) return null;

            long sizeBytes = Files.size(hlepPath);
            String sha256 = computeSha256(hlepPath);

            JsonObject uiObj = json.has("ui") && json.get("ui").isJsonObject()
                    ? json.getAsJsonObject("ui")
                    : new JsonObject();

            String placement = getString(json, "placement", getString(uiObj, "placement", "drawer_panel"));
            double defaultWidth = getDouble(json, "default_width", getDouble(uiObj, "default_width", 420.0));
            double defaultHeight = getDouble(json, "default_height", getDouble(uiObj, "default_height", 560.0));
            boolean injectSdk = getBoolean(json, "inject_sdk", true);

            List<String> permissions = new ArrayList<>();
            if (json.has("permissions") && json.get("permissions").isJsonArray()) {
                for (JsonElement el : json.getAsJsonArray("permissions")) {
                    if (!el.isJsonNull()) {
                        permissions.add(el.getAsString());
                    }
                }
            }

            Map<String, Object> contributes = Collections.emptyMap();
            if (json.has("contributes") && json.get("contributes").isJsonObject()) {
                Type mapType = new TypeToken<Map<String, Object>>() {}.getType();
                contributes = gson.fromJson(json.get("contributes"), mapType);
            }

            PluginCatalogItemDto dto = new PluginCatalogItemDto();
            dto.setId(id);
            dto.setName(getString(json, "name", id));
            dto.setVersion(getString(json, "version", "1.0.0"));
            dto.setAuthor(getString(json, "author", "HocLuc Studio"));
            dto.setDescription(getString(json, "description", ""));
            dto.setCategory(getString(json, "category", inferCategoryFromId(id)));
            dto.setPlacement(placement);
            dto.setDefaultWidth(defaultWidth);
            dto.setDefaultHeight(defaultHeight);
            dto.setInjectSdk(injectSdk);
            dto.setSizeBytes(sizeBytes);
            dto.setSha256(sha256);
            dto.setIconUrl("/api/marketplace/plugins/" + id + "/icon");
            dto.setDownloadUrl("/api/marketplace/plugins/" + id + "/download");
            dto.setPermissions(permissions);
            dto.setContributes(contributes);
            return dto;
        } catch (Exception e) {
            System.err.println("[PluginMarketplaceService] Failed to inspect " + hlepPath + ": " + e.getMessage());
            return null;
        }
    }

    private JsonObject extractManifestFromBytes(byte[] zipBytes) {
        try (ZipInputStream zis = new ZipInputStream(new ByteArrayInputStream(zipBytes))) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                String norm = entry.getName().replace('\\', '/');
                if (norm.contains("..")) {
                    throw new IllegalArgumentException("Phát hiện đường dẫn không an toàn trong gói nén.");
                }
                if (!entry.isDirectory() && (norm.equals("manifest.json") || norm.endsWith("/manifest.json"))) {
                    ByteArrayOutputStream baos = new ByteArrayOutputStream();
                    zis.transferTo(baos);
                    String jsonStr = baos.toString(StandardCharsets.UTF_8);
                    return JsonParser.parseString(jsonStr).getAsJsonObject();
                }
            }
        } catch (IllegalArgumentException e) {
            throw e;
        } catch (Exception e) {
            log.warn("[marketplace] Failed to read manifest from zip bytes | cause={}", e.getMessage());
        }
        return null;
    }

    private void packDirectoryToHlep(Path sourceDir, Path targetHlep) throws IOException {
        try (ZipOutputStream zos = new ZipOutputStream(Files.newOutputStream(targetHlep));
             Stream<Path> walk = Files.walk(sourceDir)) {
            walk.filter(Files::isRegularFile).forEach(file -> {
                String rel = sourceDir.relativize(file).toString().replace('\\', '/');
                // Skip heavy python virtual environments or caches if any
                if (rel.contains("__pycache__/") || rel.contains(".venv/") || rel.contains("node_modules/")) {
                    return;
                }
                try {
                    ZipEntry entry = new ZipEntry(rel);
                    zos.putNextEntry(entry);
                    Files.copy(file, zos);
                    zos.closeEntry();
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            });
        }
    }

    private String computeSha256(Path file) throws Exception {
        MessageDigest digest = MessageDigest.getInstance("SHA-256");
        try (InputStream is = Files.newInputStream(file)) {
            byte[] buf = new byte[8192];
            int read;
            while ((read = is.read(buf)) > 0) {
                digest.update(buf, 0, read);
            }
        }
        byte[] hash = digest.digest();
        StringBuilder sb = new StringBuilder(hash.length * 2);
        for (byte b : hash) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    private String inferCategoryFromId(String id) {
        String lower = id.toLowerCase();
        if (lower.contains("casio") || lower.contains("math") || lower.contains("calc")) return "math";
        if (lower.contains("english") || lower.contains("lang")) return "languages";
        if (lower.contains("chem") || lower.contains("phys") || lower.contains("sci")) return "science";
        return "utility";
    }

    private String getString(JsonObject obj, String key, String defaultValue) {
        if (obj != null && obj.has(key) && !obj.get(key).isJsonNull() && obj.get(key).isJsonPrimitive()) {
            return obj.get(key).getAsString();
        }
        return defaultValue;
    }

    private double getDouble(JsonObject obj, String key, double defaultValue) {
        if (obj != null && obj.has(key) && !obj.get(key).isJsonNull() && obj.get(key).isJsonPrimitive()) {
            try {
                return obj.get(key).getAsDouble();
            } catch (Exception ignored) {}
        }
        return defaultValue;
    }

    private boolean getBoolean(JsonObject obj, String key, boolean defaultValue) {
        if (obj != null && obj.has(key) && !obj.get(key).isJsonNull() && obj.get(key).isJsonPrimitive()) {
            try {
                return obj.get(key).getAsBoolean();
            } catch (Exception ignored) {}
        }
        return defaultValue;
    }
}

