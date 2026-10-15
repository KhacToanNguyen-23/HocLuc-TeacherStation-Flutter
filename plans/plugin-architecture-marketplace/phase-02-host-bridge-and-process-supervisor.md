# Phase 02: Process Supervisor & Host Bridge

**Parent Plan:** `plans/plugin-architecture-marketplace/plan.md`  
**Stories Covered:** Lifecycle Story (P1), FR-03, FR-04  
**Risk Tier:** high-risk  

---

## 1. Goal
Xây dựng hạ tầng quản lý tiến trình nền (Process Supervisor) cấp phát port động và Cầu nối Host Bridge xử lý các lệnh RPC từ Webview vào Studio State, thay thế hoàn toàn logic chạy ngầm trong `dgnl_service.dart`.

---

## 2. Tasks & Detailed Implementation Steps

1. **Xây dựng `frontend/lib/services/process_supervisor.dart`**:
   - Phương thức `Future<int> findAvailablePort()`: Mở socket port 0 trên `127.0.0.1` để lấy port khả dụng rồi đóng lại ngay.
   - Phương thức `Future<ProcessInstance> startSidecar(PluginManifest manifest, String pluginDir)`:
     - Khởi chạy tiến trình `Process.start(executable, [entryPath, '--port', port.toString()])`.
     - Polling health check endpoint `http://127.0.0.1:$port${manifest.backend?.healthEndpoint ?? '/health'}` với timeout 5 giây.
     - Trả về đối tượng `ProcessInstance` chứa `port` và `process`.
   - Phương thức `Future<void> stopSidecar(String pluginId)`: Gửi SIGTERM / `process.kill()` triệt để khi đóng plugin.
   - Lắng nghe `ProcessSignal` và đăng ký callback khi Flutter App đóng để dọn dẹp sạch toàn bộ tiến trình con đang chạy.

2. **Xây dựng `frontend/lib/services/host_bridge.dart`**:
   - Nhận chuỗi JSON từ `FlatHost.onMessage(rawMessage)`.
   - Giải mã payload dạng `{ id, action, payload }`.
   - Kiểm tra `permissions` của plugin đang active (ví dụ: chỉ cho phép `board:insert_annotation` nếu trong manifest có khai báo quyền này).
   - Dispatch đến `StudioState`:
     - Hành động `board:getSelectedText` -> Lấy text đang chọn trong tài liệu/PDF.
     - Hành động `board:insertAnnotation` -> Gọi `studio.addAnnotation(...)`.
   - Gửi phản hồi kết quả về Webview qua `FlatHost.executeScript("window.__hocluc_resolve('$id', ...)")`.

3. **Refactor `frontend/lib/services/dgnl_service.dart`**:
   - Loại bỏ hardcode đường dẫn tới file `service.py` và hardcode port `18888`.
   - Chuyển `DgnlService` sang sử dụng cổng động được cấp phát từ `ProcessSupervisor` hoặc hoạt động như một fallback phân tích nhẹ khi không có sidecar.

---

## 3. Verification Criteria
- [ ] Chạy tiến trình sidecar thành công trên port ngẫu nhiên (ví dụ port 52341), health check trả về 200.
- [ ] Đóng plugin trên giao diện -> Tiến trình Python trong Task Manager biến mất ngay lập tức (không sinh zombie process).
- [ ] Bấm nút "Phân tích & Ghim lên bảng" trong Webview -> Kết quả xuất hiện chính xác trên bảng vẽ Studio.
