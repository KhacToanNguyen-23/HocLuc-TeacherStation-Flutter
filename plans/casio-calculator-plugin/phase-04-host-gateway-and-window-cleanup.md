# Phase 04: Host Static Gateway Server & Neutral Floating Window

**Goal:** Triển khai Micro HTTP Server nội bộ trên Flutter Host để phục vụ Webview với zero CORS lỗi (chuẩn VS Code / Tauri), đồng thời làm sạch thanh tiêu đề cửa sổ nổi (FloatingPluginWindow) để trở thành khung điều khiển độc lập trung lập, hiển thị trọn vẹn UI máy tính Casio.

---

## 1. Scope & Action Items

### Task 1: Xây dựng `PluginWebServer` nội bộ trên Flutter Host
- Tạo file `frontend/lib/services/plugin_web_server.dart`.
- Sử dụng `HttpServer.bind(InternetAddress.loopbackIPv4, 0)` để mở 1 cổng ngẫu nhiên khả dụng chỉ trong phạm vi máy cục bộ (`127.0.0.1`).
- Định tuyến static files an toàn:
  - Route: `/plugins/<plugin_id>/<path>` trỏ tới thư mục cài đặt của plugin (`%LOCALAPPDATA%/HocLuc/plugins/<plugin_id>/v<version>/` hoặc thư mục phát triển).
  - Tự động gán MIME type chuẩn xác: `.html` -> `text/html; charset=utf-8`, `.js` -> `application/javascript`, `.css` -> `text/css`, `.wasm` -> `application/wasm`, `.png/.jpg/.svg/.woff2/.wav/.mp3` tương ứng.
  - Thiết lập Header `Access-Control-Allow-Origin: *` cho loopback nội bộ để đảm bảo tuyệt đối không còn bất kỳ rào cản CORS nào đối với ES Modules (`type="module"`), Web Workers hoặc WASM.
- Tích hợp vòng đời: Khởi động server trong `PluginManager.init()` và dừng an toàn khi đóng ứng dụng.

### Task 2: Cập nhật URL Resolution trong `FloatingPluginWindow` & `PluginHostDrawer`
- Cập nhật `FloatingPluginWindow` và `PluginHostDrawer`:
  - Thay vì dùng `file:///` trực tiếp, trỏ `targetUrl` tới `PluginWebServer.instance.getUrl(plugin.id, plugin.manifest.uiEntry)`.
  - Fallback về `file:///` nếu server chưa sẵn sàng (đảm bảo tính ổn định tối đa).

### Task 3: Làm sạch thanh tiêu đề của `FloatingPluginWindow`
- Loại bỏ hoàn toàn nút cứng `[Quét đoạn văn]` môn Tiếng Anh trên thanh tiêu đề `FloatingPluginWindow`.
- Thanh tiêu đề chuẩn hóa thành khung điều khiển độc lập:
  - `[Icon] Tên Plugin` (màu sắc và icon theo manifest)
  - Nút `[Gắn vào ngăn kéo]` (Dock)
  - Nút `[Đóng X]`

### Task 4: Kiểm thử kiến trúc & End-to-End
- Chạy `flutter test test/architecture_test.dart` (xác nhận 5/5 bất biến đạt 100%).
- Chạy `flutter test test/subject_plugins_test.dart test/plugin_ui_test.dart test/english_assistant_e2e_test.dart`.
- Khởi động lại ứng dụng và xác nhận máy tính Casio hiển thị đầy đủ giao diện tính toán sắc nét, không còn màn hình trắng.

---

## 2. Verification Criteria
- [ ] `PluginWebServer` khởi động thành công trên cổng loopback ngẫu nhiên.
- [ ] Thẻ `<script type="module">` của React Vite tải mượt mà qua `http://127.0.0.1:<port>/plugins/...`.
- [ ] Cửa sổ nổi hiển thị đầy đủ bàn phím máy tính Casio fx-580VN X, không còn màn hình trắng.
- [ ] Thanh tiêu đề sạch sẽ, không còn nút môn học lạ ("Quét đoạn văn").
- [ ] Toàn bộ bộ test kiến trúc `architecture_test.dart` và UI tests đều PASSED.
