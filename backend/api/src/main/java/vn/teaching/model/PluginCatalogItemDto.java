package vn.teaching.model;

import java.util.Collections;
import java.util.List;
import java.util.Map;

public class PluginCatalogItemDto {
    private String id;
    private String name;
    private String version;
    private String author;
    private String description;
    private String category;
    private String placement;
    private double defaultWidth;
    private double defaultHeight;
    private boolean injectSdk;
    private long sizeBytes;
    private String sha256;
    private String iconUrl;
    private String downloadUrl;
    private List<String> permissions;
    private Map<String, Object> contributes;

    public PluginCatalogItemDto() {
        this.permissions = Collections.emptyList();
        this.contributes = Collections.emptyMap();
    }

    public String getId() {
        return id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getVersion() {
        return version;
    }

    public void setVersion(String version) {
        this.version = version;
    }

    public String getAuthor() {
        return author;
    }

    public void setAuthor(String author) {
        this.author = author;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getPlacement() {
        return placement;
    }

    public void setPlacement(String placement) {
        this.placement = placement;
    }

    public double getDefaultWidth() {
        return defaultWidth;
    }

    public void setDefaultWidth(double defaultWidth) {
        this.defaultWidth = defaultWidth;
    }

    public double getDefaultHeight() {
        return defaultHeight;
    }

    public void setDefaultHeight(double defaultHeight) {
        this.defaultHeight = defaultHeight;
    }

    public boolean isInjectSdk() {
        return injectSdk;
    }

    public void setInjectSdk(boolean injectSdk) {
        this.injectSdk = injectSdk;
    }

    public long getSizeBytes() {
        return sizeBytes;
    }

    public void setSizeBytes(long sizeBytes) {
        this.sizeBytes = sizeBytes;
    }

    public String getSha256() {
        return sha256;
    }

    public void setSha256(String sha256) {
        this.sha256 = sha256;
    }

    public String getIconUrl() {
        return iconUrl;
    }

    public void setIconUrl(String iconUrl) {
        this.iconUrl = iconUrl;
    }

    public String getDownloadUrl() {
        return downloadUrl;
    }

    public void setDownloadUrl(String downloadUrl) {
        this.downloadUrl = downloadUrl;
    }

    public List<String> getPermissions() {
        return permissions;
    }

    public void setPermissions(List<String> permissions) {
        this.permissions = permissions != null ? permissions : Collections.emptyList();
    }

    public Map<String, Object> getContributes() {
        return contributes;
    }

    public void setContributes(Map<String, Object> contributes) {
        this.contributes = contributes != null ? contributes : Collections.emptyMap();
    }
}

