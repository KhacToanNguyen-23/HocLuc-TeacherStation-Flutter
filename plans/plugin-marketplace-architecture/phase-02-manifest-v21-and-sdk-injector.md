# Phase 02: Manifest Schema v2.1 (`contributes`) & Open-Source Auto-SDK Injector

**Mục tiêu:** Nâng cấp chuẩn `manifest.json` lên Schema v2.1 theo phong cách VS Code (`contributes.tools`, đa bề mặt hiển thị) và Chrome Extension (`inject_sdk: true` tự động tiêm `hocluc-plugin-sdk.js` qua `PluginWebServer` để bọc các dự án Open-Source mà không cần sửa code gốc), đồng thời bảo vệ giải nén chống Zip Slip.

**User Stories bao phủ:**
- **[P1]** Lập trình viên thêm plugin mới hoặc bọc dự án Open-Source có sẵn chỉ bằng cách cấu hình `manifest.json`, không cần chạm vào `frontend/lib/`.
- **[P2]** Công cụ đóng gói `.hlep` kiểm tra chuẩn Schema v2.1.

---

## 1. Các Hạng Mục Triển Khai Chi Tiết

1. **Mở rộng `PluginManifest` (`frontend/lib/models/plugin_manifest.dart`):**
   - Bổ sung model `PluginToolContribution`:
     - `id` (`String`), `label` (`String`), `icon` (`String`), `tooltip` (`String`), `action` (`String`: `'snip_region'`, `'toggle_tool'`, `'quick_input'`, `'rpc_event'`), `target` (`String?`).
   - Bổ sung vào `PluginManifest`:
     - `iconPath` (`String`, mặc định `'icon.png'`).
     - `uiDefaultHeight` (`double`, mặc định `560.0`), `resizable` (`bool`, mặc định `true`).
     - `injectSdk` (`bool`, mặc định `true` — tự động tiêm SDK vào HTML nếu trang chưa nhúng).
     - `contributesTools` (`List<PluginToolContribution>`): Đọc từ `json['contributes']?['tools']`.
   - Đảm bảo tương thích ngược 100% với các tệp `manifest.json` Schema v2 hiện tại và các unit test.

2. **Tự động tiêm SDK cho Open-Source trong `PluginWebServer` (`frontend/lib/services/plugin_web_server.dart`):**
   - Phục vụ tệp SDK chuẩn tại đường dẫn nội bộ `http://127.0.0.1:<port>/__hocluc_sdk__/hocluc-plugin-sdk.js`.
   - Khi phục vụ tệp `.html` của một plugin có `manifest.injectSdk == true`:
     - Nếu nội dung HTML chưa chứa `sdk.js` hoặc `hocluc-plugin-sdk.js`, tự động chèn `<script src="/__hocluc_sdk__/hocluc-plugin-sdk.js"></script>` trước thẻ `</head>` hoặc `</body>`.
     - Nhờ đó, bất kỳ dự án Open-Source nào (như Casio emulator, GeoGebra, PhET) chỉ cần chép bản build vào `ui/` là tự động có đối tượng `window.HocLuc` mà không cần sửa file build gốc.

3. **Bảo mật Giải nén & Quản lý Phiên bản trong `PluginStorageManager` (`frontend/lib/services/plugin_storage_manager.dart`):**
   - Chặn triệt để các đường dẫn chứa `..` hoặc đường dẫn tuyệt đối khi giải nén trong `installFromZip` (chống lỗ hổng Zip Slip).
   - Bổ sung kiểm tra mã băm `expectedSha256` (nếu truyền vào) trước khi giải nén gói `.hlep`.

4. **Cập nhật `manifest.json` của `casio_calculator`, `english_assistant` & `scripts/package_plugin.mjs`:**
   - Cập nhật `plugins/casio_calculator/manifest.json` bổ sung `"category": "math"`, `"inject_sdk": true`, `"resizable": true`.
   - Cập nhật `plugins/english_assistant/manifest.json` khai báo tường minh khối `contributes.tools` (gồm công cụ Quét đoạn văn, Công cụ S-V-O, Nhập câu) để `SubjectToolPalette` đọc động từ manifest thay vì hardcode trong Flutter.
   - Nâng cấp `scripts/package_plugin.mjs` để kiểm tra schema `manifest.json` và in ra mã băm `sha256` sau khi đóng gói `.hlep`.

---

## 2. Tiêu Chí Nghiệm Thu (Verification Criteria)
- [ ] `flutter test test/plugin_manifest_test.dart test/plugin_storage_test.dart` PASSED 100%.
- [ ] `PluginWebServer` tự động tiêm `hocluc-plugin-sdk.js` cho các trang HTML của plugin Open-Source khi `injectSdk: true`.
- [ ] Giải nén gói zip có chứa đường dẫn `../` bị từ chối an toàn.

