# Phase 01: Backend Marketplace Registry & API Phân Phối `.hlep`

**Mục tiêu:** Xây dựng dịch vụ Kho Tiện Ích (Plugin Marketplace) trên Spring Boot (`backend/api/`) để tự động quản lý danh mục các gói `.hlep`, phục vụ icon, cho phép giáo viên tải gói cài đặt qua HTTP kèm kiểm tra toàn vẹn `sha256`, và hỗ trợ Dev/Admin phát hành (publish) gói `.hlep` mới.

**User Stories bao phủ:**
- **[P1]** Giáo viên duyệt danh sách Kho Tiện Ích từ Backend và tải gói `.hlep` về máy.
- **[P2]** Lập trình viên / Quản trị viên phát hành gói `.hlep` mới lên Backend qua API.

---

## 1. Các Hạng Mục Triển Khai Chi Tiết

1. **Tạo DTO Danh mục Plugin (`PluginCatalogItemDto.java`):**
   - Đường dẫn: `backend/api/src/main/java/vn/teaching/marketplace/PluginCatalogItemDto.java`
   - Các trường dữ liệu:
     - `id` (`String`)
     - `name` (`String`)
     - `version` (`String`)
     - `author` (`String`)
     - `description` (`String`)
     - `category` (`String`)
     - `placement` (`String`)
     - `defaultWidth` (`Double`)
     - `defaultHeight` (`Double`)
     - `sizeBytes` (` long`)
     - `sha256` (`String`)
     - `iconUrl` (`String`)
     - `downloadUrl` (`String`)
     - `permissions` (`List<String>`)
     - `contributes` (`Map<String, Object>`)

2. **Xây dựng Dịch vụ Quản lý Kho Plugin (`PluginMarketplaceService.java`):**
   - Đường dẫn: `backend/api/src/main/java/vn/teaching/marketplace/PluginMarketplaceService.java`
   - Cơ chế hoạt động:
     - Quét thư mục chứa plugin (`plugins/`, `../plugins/`, `../../plugins/` hoặc thư mục cấu hình qua biến môi trường `HOCLUC_MARKETPLACE_DIR`).
     - Nếu trong thư mục `plugins/<folder>` có `manifest.json` nhưng chưa được đóng gói thành `<folder>.hlep`, tự động nén thành tệp `.hlep` chuẩn vào vùng lưu trữ phục vụ tải về (giúp Dev chỉ cần bỏ thư mục plugin mới vào `plugins/` là Backend tự động phân phối được ngay).
     - Đọc trực tiếp tệp `manifest.json` và `icon.png` từ bên trong file nén `.hlep` bằng `java.util.zip.ZipFile`, tính toán dung lượng `sizeBytes` và mã băm `SHA-256`.
     - Cung cấp hàm `publishPlugin(MultipartFile file)` để nhận file `.hlep` tải lên, xác thực có chứa `manifest.json` hợp lệ và lưu vào kho.

3. **Xây dựng REST Controller (`PluginMarketplaceController.java`):**
   - Đường dẫn: `backend/api/src/main/java/vn/teaching/marketplace/PluginMarketplaceController.java`
   - Hỗ trợ đồng thời cả 2 đường dẫn `/api/marketplace/plugins` và `/api/v1/plugins` (để tương thích với mọi client):
     - `GET /api/marketplace/plugins` (và `GET /api/v1/plugins`): Trả về danh sách `List<PluginCatalogItemDto>` của toàn bộ plugin trên kho.
     - `GET /api/marketplace/plugins/{id}/icon` (và `GET /api/v1/plugins/{id}/icon`): Trả về ảnh `icon.png` (`image/png`) trích xuất từ gói `.hlep`.
     - `GET /api/marketplace/plugins/{id}/download` (và `GET /api/v1/plugins/{id}/download`): Trả về luồng file `.hlep` (`application/octet-stream`) kèm header `Content-Disposition` và `X-Plugin-Sha256`.
     - `POST /api/marketplace/plugins/publish`: Nhận `MultipartFile` `.hlep`, kiểm tra tính hợp lệ và đăng ký vào danh mục.

4. **Viết Kiểm Thử Tự Động (`PluginMarketplaceControllerTest.java`):**
   - Đường dẫn: `backend/api/src/test/java/vn/teaching/marketplace/PluginMarketplaceControllerTest.java`
   - Kiểm tra:
     - `GET /api/marketplace/plugins` trả về HTTP 200 kèm danh sách chứa plugin (bao gồm `com.hocluc.plugin.casio`, mã `sha256` không rỗng, `sizeBytes > 0`).
     - `GET /api/marketplace/plugins/com.hocluc.plugin.casio/download` trả về mảng byte zip hợp lệ khớp với `sha256`.
     - `GET /api/marketplace/plugins/com.hocluc.plugin.casio/icon` trả về ảnh `image/png`.
     - `POST /api/marketplace/plugins/publish` tải lên 1 gói `.hlep` mẫu thành công và xuất hiện trong danh sách.

---

## 2. Tiêu Chí Nghiệm Thu (Verification Criteria)
- [ ] `mvn test -Dtest=PluginMarketplaceControllerTest` trong `backend/api/` đạt `BUILD SUCCESS` 100%.
- [ ] Không cần cấu hình thêm cơ sở dữ liệu ngoài; tự động nhận diện mọi gói `.hlep` hoặc thư mục plugin trong `plugins/`.

