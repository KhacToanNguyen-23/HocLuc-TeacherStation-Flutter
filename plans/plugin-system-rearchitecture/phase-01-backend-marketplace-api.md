# Phase 01: Backend Spring Boot Marketplace API

**Goal:** Xây dựng dịch vụ RESTful Plugin Marketplace trên Spring Boot Backend (`backend/api/`) để quản lý danh mục và phân phối các gói `.hlep` cho giáo viên tải về qua Internet.

---

## 1. Scope & Action Items

1. **Tạo DTO & Metadata Service:**
   - Tạo `vn.teaching.dto.PluginItemDto`:
     - `id`, `name`, `version`, `author`, `description`, `category`, `iconUrl`, `fileSize`, `downloadUrl`, `permissions`, `placement`.
   - Tạo `vn.teaching.service.PluginMarketplaceService`:
     - Đọc metadata từ các file `.hlep` hoặc thư mục lưu trữ plugin (`plugins/` hoặc thư mục cấu hình storage).
     - Cung cấp danh sách plugin khả dụng cho client.
     - Cung cấp `Resource` file `.hlep` tương ứng khi client yêu cầu download.
2. **Tạo REST Controller:**
   - Tạo `vn.teaching.controller.PluginMarketplaceController`:
     - `@GetMapping("/api/v1/plugins")`: Trả về danh sách `List<PluginItemDto>`.
     - `@GetMapping("/api/v1/plugins/{id}/download")`: Trả về `ResponseEntity<Resource>` với header `application/octet-stream` và `Content-Disposition`.
3. **Viết Kiểm Thử:**
   - Tạo `vn.teaching.controller.PluginMarketplaceControllerTest`.
   - Xác nhận gọi API lấy danh mục và tải file `.hlep` thành công bằng `mvn test`.

---

## 2. Verification Criteria
- [ ] Endpoint `GET /api/v1/plugins` trả về HTTP 200 kèm danh sách JSON hợp lệ.
- [ ] Endpoint `GET /api/v1/plugins/{id}/download` trả về file `.hlep` stream thành công.
- [ ] `mvn test -Dtest=PluginMarketplaceControllerTest` PASSED 100%.
