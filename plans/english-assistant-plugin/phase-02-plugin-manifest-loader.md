# Phase 02: Plugin Package (.hlep) Loader & Storage Manager

**Canonical Phase ID:** `phase-02-plugin-manifest-loader`  
**Stories Covered:** P1 (Định dạng gói .hlep, Cài đặt từ ngăn kéo tài liệu)  
**Priority:** P1  

---

## Objective
Xây dựng mô hình cấu hình `PluginManifest`, dịch vụ `PluginManager` giải nén file `.hlep` (archive ZIP), đọc `manifest.json`, quản lý danh sách các plugin đã cài đặt trong bộ nhớ và lưu trữ cục bộ.

---

## Scope & Implementation Tasks

1. **Tạo model `PluginManifest` (`frontend/lib/models/plugin_manifest.dart`):**
   - Parse các trường từ `manifest.json`:
     - `id`: Mã định danh (ví dụ: `com.hocluc.plugin.english`).
     - `name`: Tên plugin (ví dụ: `Trợ giảng Tiếng Anh`).
     - `version`, `author`, `description`, `category`.
     - `ui`: `{entry: "ui/index.html", placement: "drawer_panel", default_width: 420}`.
     - `backend`: `{has_sidecar: true, executable: "engine/service.exe", port: 18888}`.
   - Hỗ trợ `fromJson()` và `toJson()`.

2. **Tạo service `PluginManager` (`frontend/lib/services/plugin_manager.dart`):**
   - Sử dụng package `archive` (đã có sẵn trong pubspec của Flutter) để đọc file `.hlep` (zip format).
   - Phương thức `installPluginFromBytes(Uint8List bytes, String filename)`:
     - Giải nén zip trong bộ nhớ hoặc lưu vào thư mục `plugins/{plugin_id}/`.
     - Tìm và đọc `manifest.json`.
     - Lưu thông tin vào danh sách `installedPlugins`.
   - Phương thức `uninstallPlugin(String pluginId)`.
   - Hỗ trợ tải các plugin mẫu tích hợp sẵn (*built-in demo plugins*).

3. **Viết unit test cho `PluginManifest` và `PluginManager`:**
   - Test giải nén gói `.hlep` mẫu, parse manifest, kiểm tra tính toàn vẹn của các file `ui/index.html` và `engine/service.py`.

---

## Files Affected
- `frontend/lib/models/plugin_manifest.dart` (new)
- `frontend/lib/services/plugin_manager.dart` (new)
- `frontend/test/plugin_manifest_test.dart` (new)

---

## Dependencies
- Không phụ thuộc Phase 01. Có thể chạy độc lập.

---

## Tests and Acceptance Criteria
- Chạy `flutter test test/plugin_manifest_test.dart`:
  - `PluginManifest.fromJson` parse chính xác manifest Tiếng Anh mẫu.
  - `PluginManager` giải nén một archive `.hlep` hợp lệ và nhận diện đúng các file HTML, JS, service script.
  - Ném ngoại lệ an toàn nếu file `.hlep` bị hỏng hoặc thiếu `manifest.json`.
