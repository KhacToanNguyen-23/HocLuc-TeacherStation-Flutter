package vn.teaching.modules.plugin.controller;

import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import vn.teaching.modules.plugin.dto.PluginCatalogItemDto;
import vn.teaching.modules.plugin.service.PluginMarketplaceService;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

@RestController
public class PluginMarketplaceController {
    private final PluginMarketplaceService marketplaceService;

    public PluginMarketplaceController(PluginMarketplaceService marketplaceService) {
        this.marketplaceService = marketplaceService;
    }

    @GetMapping({"/api/marketplace/plugins", "/api/v1/plugins"})
    public ResponseEntity<List<PluginCatalogItemDto>> listPlugins() {
        return ResponseEntity.ok(marketplaceService.getCatalog());
    }

    @GetMapping({"/api/marketplace/plugins/{id}", "/api/v1/plugins/{id}"})
    public ResponseEntity<PluginCatalogItemDto> getPluginMetadata(@PathVariable String id) {
        PluginCatalogItemDto metadata = marketplaceService.getPluginMetadata(id);
        if (metadata == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(metadata);
    }

    @GetMapping({"/api/marketplace/plugins/{id}/icon", "/api/v1/plugins/{id}/icon"})
    public ResponseEntity<Resource> getPluginIcon(@PathVariable String id) {
        byte[] iconBytes = marketplaceService.getPluginIconBytes(id);
        if (iconBytes == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok()
                .contentType(MediaType.IMAGE_PNG)
                .contentLength(iconBytes.length)
                .body(new ByteArrayResource(iconBytes));
    }

    @GetMapping({"/api/marketplace/plugins/{id}/download", "/api/v1/plugins/{id}/download"})
    public ResponseEntity<Resource> downloadPlugin(@PathVariable String id) {
        Path packagePath = marketplaceService.getPluginPackagePath(id);
        PluginCatalogItemDto metadata = marketplaceService.getPluginMetadata(id);
        if (packagePath == null || !Files.exists(packagePath)) {
            return ResponseEntity.notFound().build();
        }
        try {
            long fileSize = Files.size(packagePath);
            String filename = id.replaceAll("[^a-zA-Z0-9._-]", "_") + ".hlep";
            ResponseEntity.BodyBuilder builder = ResponseEntity.ok()
                    .contentType(MediaType.APPLICATION_OCTET_STREAM)
                    .contentLength(fileSize)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + filename + "\"");
            if (metadata != null && metadata.getSha256() != null) {
                builder.header("X-Plugin-Sha256", metadata.getSha256());
            }
            return builder.body(new FileSystemResource(packagePath));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    @PostMapping({"/api/marketplace/plugins/publish", "/api/v1/plugins/publish"})
    public ResponseEntity<?> publishPlugin(
            @RequestParam(value = "file", required = false) MultipartFile file,
            @RequestBody(required = false) byte[] rawBytes
    ) {
        try {
            byte[] payload = (file != null && !file.isEmpty()) ? file.getBytes() : rawBytes;
            PluginCatalogItemDto published = marketplaceService.publishPluginPackage(payload);
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "plugin", published
            ));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false,
                    "error", e.getMessage()
            ));
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of(
                    "success", false,
                    "error", "Lỗi máy chủ khi phát hành plugin: " + e.getMessage()
            ));
        }
    }
}

