# Phase 02: Packaging `.hlep` & Marketplace Catalog

**Goal:** Đóng gói plugin thành tệp nén nhị phân `plugins/casio_calculator.hlep`, kiểm tra nạp catalog và giải nén tự động vào thư mục người dùng `%LOCALAPPDATA%/HocLuc/plugins/`.

---

## 1. Scope & Action Items

1. **Đóng gói file `.hlep`:**
   - Chạy `node scripts/package_plugin.mjs casio_calculator`.
   - Xác nhận file `plugins/casio_calculator.hlep` được tạo thành công với dung lượng tối ưu (< 1MB).
2. **Kiểm thử giải nén và lưu trữ On-Disk (`PluginStorageManager`):**
   - Đảm bảo cơ chế lazy loading của `PluginStorageManager` giải nén đúng cấu trúc:
     `%LOCALAPPDATA%/HocLuc/plugins/com.hocluc.plugin.casio/v1.0.0/`
   - Xác nhận `PluginManager.installFromHlep` hoặc quét thư mục nhận diện đúng metadata (name, version, icon, placement).
3. **Cập nhật danh mục Marketplace mẫu (Marketplace Catalog):**
   - Đảm bảo trong kho tiện ích có thẻ "Máy Tính Khoa Học Casio" cho giáo viên cài đặt.

---

## 2. Verification Criteria
- [ ] File `plugins/casio_calculator.hlep` tồn tại trên đĩa và mở được dạng zip tiêu chuẩn.
- [ ] Unit test `test/plugin_manifest_test.dart` và `test/plugin_storage_test.dart` đều vượt qua khi kiểm thử gói casio mới.
