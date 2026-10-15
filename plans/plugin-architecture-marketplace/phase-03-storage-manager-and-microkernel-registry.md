# Phase 03: Storage Manager & Clean Microkernel

**Parent Plan:** `plans/plugin-architecture-marketplace/plan.md`  
**Stories Covered:** Download Story (P1), FR-02, FR-05  
**Risk Tier:** normal  

---

## 1. Goal
Chuyển đổi toàn bộ cơ chế lưu trữ plugin từ việc nhồi nhét byte thô trong RAM sang lưu trữ thư mục cục bộ (%LOCALAPPDATA%), biến `PluginManager` thành một Pure Microkernel Registry, và làm sạch `FlatHost`.

---

## 2. Tasks & Detailed Implementation Steps

1. **Xây dựng `frontend/lib/services/plugin_storage_manager.dart`**:
   - Xác định thư mục gốc lưu trữ plugin:
     - Windows: `%LOCALAPPDATA%/HocLuc/plugins/` (hoặc thư mục tương đương trên macOS/Linux).
   - Phương thức `Future<String> installFromZip(List<int> bytes, String pluginId, String version)`:
     - Giải nén file nén zip/hlep vào thư mục `%LOCALAPPDATA%/HocLuc/plugins/$pluginId/v$version/`.
     - Kiểm tra sự tồn tại của `manifest.json`.
     - Trả về đường dẫn tuyệt đối của thư mục đã giải nén.
   - Phương thức `Future<void> uninstall(String pluginId)`: Xóa toàn bộ thư mục của plugin trên ổ đĩa.
   - Phương thức `String? getInstalledDirectory(String pluginId)`: Trả về đường dẫn thư mục đã cài đặt nếu tồn tại.

2. **Tái cấu trúc `frontend/lib/services/plugin_manager.dart`**:
   - Xóa bỏ trường `filesMap` (Map<String, Uint8List>) trong `InstalledPlugin`.
   - Thay thế bằng việc lưu trữ đường dẫn thư mục `pluginDirectory` trên đĩa.
   - Xóa bỏ hoàn toàn hàm mock hardcode chuỗi HTML `installSampleEnglishPlugin`.
   - Kết nối với `PluginStorageManager` và `ProcessSupervisor`:
     - Khi `openPlugin(plugin)`: Kích hoạt WebView trỏ tới file HTML trên ổ đĩa, ra lệnh `ProcessSupervisor.startSidecar(...)` nếu plugin có backend.
     - Khi `closePlugin()`: Ra lệnh `ProcessSupervisor.stopSidecar(...)`.

3. **Làm sạch `frontend/lib/widgets/flat_host_native.dart`**:
   - Xóa bỏ toàn bộ các đường dẫn hardcode `File('../plugins/english_assistant/...')`.
   - Nhận trực tiếp đường dẫn file tuyệt đối (`file:///C:/Users/.../index.html`) hoặc URL từ `InstalledPlugin`.

4. **Cập nhật Marketplace UI (`studio_plugins_marketplace_panel.dart`)**:
   - Hiển thị danh mục plugin với trạng thái rõ ràng (Chưa cài đặt / Đã cài đặt).
   - Nút "Cài đặt" gọi `PluginStorageManager.installFromZip(...)` và cập nhật danh sách plugin khả dụng.
   - Nút "Gỡ cài đặt" gọi `PluginStorageManager.uninstall(...)`.

---

## 3. Verification Criteria
- [ ] Mở ứng dụng lần đầu: RAM tăng 0 MB cho các plugin chưa cài đặt.
- [ ] Bấm "Cài đặt" plugin từ tệp `.hlep` -> Thư mục `%LOCALAPPDATA%/HocLuc/plugins/` xuất hiện đúng cấu trúc file.
- [ ] WebView mở giao diện plugin trơn tru từ đường dẫn file cục bộ mà không có bất kỳ dòng code nào trỏ tĩnh đến `english_assistant`.
- [ ] Bấm "Gỡ cài đặt" -> Thư mục trên ổ đĩa biến mất, trạng thái UI cập nhật về "Chưa cài đặt".
