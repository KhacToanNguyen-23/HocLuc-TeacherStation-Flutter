# Phase 04: Python Sidecar Lifecycle Manager (Desktop) & Web Fallback

**Canonical Phase ID:** `phase-04-python-sidecar-desktop`  
**Stories Covered:** P2 (Tự động chạy tiến trình ngầm service.exe trên Windows, Web fallback)  
**Priority:** P2  

---

## Objective
Xây dựng dịch vụ `SidecarManager` chịu trách nhiệm tự động quản lý vòng đời của tiến trình `engine/service.exe` trên Windows Desktop (start, health-check, terminate khi dispose) và cung cấp fallback chế độ Mock / hướng dẫn trên Flutter Web.

---

## Scope & Implementation Tasks

1. **Kiến trúc đa nền tảng (`frontend/lib/services/sidecar_manager.dart`):**
   - Áp dụng conditional export tương tự `desktop_lifecycle.dart`:
     - `sidecar_manager_stub.dart`
     - `sidecar_manager_native.dart` (Windows / Desktop qua `dart:io Process`)
     - `sidecar_manager_web.dart` (Web qua HTTP Ping check)

2. **Cài đặt Native (`sidecar_manager_native.dart`):**
   - Phương thức `Future<int> startSidecar(String exePath, int preferredPort)`:
     - Kiểm tra file `exePath` tồn tại.
     - Sử dụng `Process.start(exePath, ['--port', preferredPort.toString()])`.
     - Ping `http://127.0.0.1:$preferredPort/` với timeout 5 giây để xác nhận server FastAPI đã sẵn sàng.
     - Bắt `Process.exitCode` và log lỗi nếu tiến trình chết bất ngờ.
   - Phương thức `Future<void> stopSidecar()`:
     - Gửi tín hiệu `process.kill()` khi plugin đóng hoặc khi thoát ứng dụng.

3. **Cài đặt Web (`sidecar_manager_web.dart`):**
   - Ping `http://127.0.0.1:18888/` bằng HTTP request nhẹ:
     - Nếu online: Trả về trạng thái `connected`.
     - Nếu offline: Trả về trạng thái `offline`, giao diện hiển thị badge nhắc giáo viên bật local server hoặc tự động kích hoạt Mock Parser (fallback dữ liệu demo S-V-O cho trải nghiệm kiểm thử).

4. **Tích hợp kiểm tra tự động giải phóng:**
   - Đăng ký hook vào `DesktopLifecycle` để bảo đảm `service.exe` không bao giờ bị orphan (chạy ngầm vô tận) sau khi đóng cửa sổ Studio.

---

## Files Affected
- `frontend/lib/services/sidecar_manager.dart` (new)
- `frontend/lib/services/sidecar_manager_stub.dart` (new)
- `frontend/lib/services/sidecar_manager_native.dart` (new)
- `frontend/lib/services/sidecar_manager_web.dart` (new)
- `frontend/test/sidecar_manager_test.dart` (new)

---

## Dependencies
- Phụ thuộc Phase 02 (`PluginManifest` chứa cấu hình backend port & executable path).

---

## Tests and Acceptance Criteria
- Chạy `flutter test test/sidecar_manager_test.dart`:
  - `SidecarManagerWeb` xác định chính xác trạng thái online/offline của backend.
  - Native stub xử lý timeout và ném lỗi có thông điệp rõ ràng khi không tìm thấy file thực thi.
