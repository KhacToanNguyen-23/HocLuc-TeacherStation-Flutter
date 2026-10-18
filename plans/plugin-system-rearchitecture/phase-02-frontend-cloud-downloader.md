# Phase 02: Frontend Cloud Downloader & Cache Manager

**Goal:** Xây dựng `PluginMarketplaceService` trong Flutter để nạp danh mục plugin từ Internet qua Backend API, tải gói `.hlep` về và giải nén vào bộ nhớ cục bộ (`%LOCALAPPDATA%`), đồng thời giữ cơ chế offline fallback khi mất mạng.

---

## 1. Scope & Action Items

1. **Xây dựng `PluginMarketplaceService` (`frontend/lib/services/plugin_marketplace_service.dart`):**
   - Lấy URL backend động từ `LocalService` / cấu hình môi trường.
   - Hàm `Future<List<MarketplacePlugin>> fetchCatalog()`:
     - Gọi `GET /api/v1/plugins`.
     - Nếu có mạng: cập nhật danh sách và lưu cache metadata vào `SharedPreferences`.
     - Nếu mất mạng: fallback sang cache đã lưu trước đó + quét thư mục local dev `plugins/`.
   - Hàm `Future<InstalledPlugin> downloadAndInstall(MarketplacePlugin item, {Function(double progress)? onProgress})`:
     - Tải stream file `.hlep` qua HTTP.
     - Gọi `PluginStorageManager.instance.installFromZip(bytes)`.
     - Đăng ký vào `PluginManager` và cập nhật trạng thái đã cài đặt.
2. **Cập nhật `StudioPluginsMarketplacePanel`:**
   - Hiển thị danh mục kết hợp: Các plugin trên Cloud Marketplace + Các plugin đã cài trong máy.
   - Hiển thị dung lượng file (ví dụ "695 KB"), version, tác giả.
   - Nút **[Cài đặt]**: Hiển thị trạng thái đang tải (Loading spinner / Progress) $\rightarrow$ chuyển thành **[Mở]** khi hoàn tất.
3. **Giữ nguyên khả năng Sideload trong môi trường Dev:**
   - Trong môi trường dev, nếu có file `.hlep` hoặc thư mục trong `plugins/`, hệ thống vẫn tự động nhận diện để lập trình viên test nhanh.

---

## 2. Verification Criteria
- [ ] `PluginMarketplaceService` fetch danh mục từ API thành công.
- [ ] Tải và cài đặt file `.hlep` qua HTTP thành công.
- [ ] Hỗ trợ offline fallback mượt mà khi không có kết nối backend.
