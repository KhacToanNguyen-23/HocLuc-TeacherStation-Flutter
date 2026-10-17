# Phase 04: Giao Diện Kho Tiện Ích Đồng Bộ Backend, Dev Sideload & Kiểm Thử Kiến Trúc

**Mục tiêu:** Kết nối hoàn chỉnh Frontend Flutter với Backend Marketplace API (`GET /api/marketplace/plugins` & `GET /api/marketplace/plugins/{id}/download`), nâng cấp giao diện `StudioPluginsMarketplacePanel` (hiển thị icon thật, dung lượng, trạng thái tải/cập nhật, nút nạp nhanh `.hlep` cho Dev), và siết chặt bài kiểm thử bất biến kiến trúc `architecture_test.dart`.

**User Stories bao phủ:**
- **[P1]** Giáo viên tải và cập nhật plugin 1-click từ Backend Marketplace về `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`.
- **[P2]** Lập trình viên nạp thử nghiệm (Sideload) gói `.hlep` ngay trên giao diện và kiểm chứng 100% quy chuẩn kiến trúc.

---

## 1. Các Hạng Mục Triển Khai Chi Tiết

1. **Xây dựng `PluginMarketplaceService` (`frontend/lib/services/plugin_marketplace_service.dart`):**
   - Model `MarketplaceCatalogItem`:
     - Chứa thông tin từ Backend (`id`, `name`, `version`, `author`, `description`, `category`, `placement`, `sizeBytes`, `sha256`, `iconUrl`, `downloadUrl`, `permissions`).
     - Hỗ trợ định dạng hiển thị dung lượng (ví dụ: `678 KB`, `16.9 MB`).
   - Hàm `fetchCatalog()`:
     - Gọi `GET $baseUrl/api/marketplace/plugins` (sử dụng cấu hình URL từ `LocalService`).
     - Lưu bản chụp danh mục vào `SharedPreferences` để hiển thị ngay khi ngoại tuyến (Offline fallback).
   - Hàm `downloadPluginPackage(MarketplaceCatalogItem item)`:
     - Tải dữ liệu nhị phân `.hlep` từ `GET $baseUrl/api/marketplace/plugins/${item.id}/download`.
     - Kiểm tra mã băm `sha256` (nếu có) và gọi `PluginManager.instance.installPluginFromBytes(bytes, '${item.id}.hlep')`.

2. **Tích hợp Đồng bộ Kho Backend vào `PluginManager` (`frontend/lib/services/plugin_manager.dart`):**
   - Quản lý danh sách catalog từ Backend (`remoteCatalog`), trạng thái đang tải của từng plugin (`isDownloading(id)`), và phát hiện bản cập nhật mới (`hasUpdate(id)` khi version trên Backend mới hơn version đã cài).
   - Khi gọi `PluginManager.install(id)`:
     - Nếu plugin chưa có file cục bộ mà đến từ Backend Marketplace, tự động gọi `PluginMarketplaceService.downloadPluginPackage` tải về giải nén vào `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`.

3. **Nâng cấp Giao diện `StudioPluginsMarketplacePanel` (`frontend/lib/widgets/studio/studio_plugins_marketplace_panel.dart`):**
   - Hiển thị ảnh `icon.png` thực tế của từng plugin (từ file cục bộ đã giải nén hoặc từ `iconUrl` của Backend, fallback về icon vector nếu không có ảnh).
   - Hiển thị phiên bản (`v1.0.0`), dung lượng gói tải, nhãn loại hiển thị (`Cửa sổ nổi` / `Gắn bài giảng`).
   - Hỗ trợ đầy đủ các trạng thái nút bấm:
     - **Cài đặt / Tải về** (chưa cài) $\rightarrow$ **Đang tải...** (vòng xoay tiến trình) $\rightarrow$ **Mở** (hoặc **Cập nhật** nếu có version mới trên Backend) & nút **Gỡ tiện ích**.
   - Bổ sung nút **Nạp file `.hlep` (Dev Sideload)** và nút **Làm mới kho** trên thanh header của bảng Kho Tiện Ích để lập trình viên nạp nhanh bất kỳ gói `.hlep` nào từ máy tính.

4. **Siết chặt `architecture_test.dart` & Viết Unit Test Marketplace (`frontend/test/`):**
   - Nâng cấp `frontend/test/architecture_test.dart`:
     - Bất biến 1 kiểm tra cấm toàn bộ các chuỗi `'english_assistant'`, `'com.hocluc.plugin.'`, `'casio_calculator'` trong toàn bộ `frontend/lib/`.
     - Bổ sung kiểm tra Schema v2.1 cho tất cả các plugin trong `plugins/`.
   - Tạo `frontend/test/plugin_marketplace_test.dart` kiểm thử:
     - Đồng bộ danh mục từ Mock HTTP Backend API (`GET /api/marketplace/plugins`).
     - Luồng bấm tải plugin Casio từ Backend $\rightarrow$ giải nén vào thư mục tạm AppData $\rightarrow$ kiểm tra trạng thái đã cài đặt $\rightarrow$ mở song song cửa sổ nổi Casio và tiện ích ngăn kéo.

---

## 2. Tiêu Chí Nghiệm Thu (Verification Criteria)
- [ ] `flutter test test/architecture_test.dart` PASSED 100% với bộ quy tắc cấm hardcode mở rộng.
- [ ] `flutter test test/plugin_marketplace_test.dart test/subject_plugins_test.dart test/plugin_storage_test.dart` PASSED 100%.
- [ ] `mvn test -Dtest=PluginMarketplaceControllerTest` trong `backend/api/` PASSED 100%.
- [ ] `flutter analyze` đạt `0` lỗi.

