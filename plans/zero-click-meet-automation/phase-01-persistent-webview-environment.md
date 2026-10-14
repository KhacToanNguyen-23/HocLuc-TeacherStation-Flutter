# Phase 1: Persistent WebView2 Environment & Profile Directory

**Phase:** 1  
**Status:** Completed  
**Spec Story:** [P1] Persistent Google Session  

---

## Objective
Cấu hình môi trường khởi động duy nhất cho Edge WebView2 trên Windows (`WebviewController.initializeEnvironment()`) nhằm:
1. Lưu trữ Cookies và LocalStorage của tài khoản Google vào thư mục cố định trên máy (`%APPDATA%/HocLucTeacherStation/EdgeProfile`).
2. Tự động cấp quyền Camera và Microphone cho WebView2 thông qua cờ Chromium `--use-fake-ui-for-media-stream`.
3. Đảm bảo toàn bộ WebView trong ứng dụng (`GoogleWebviewLoginDialog`, `MeetAutomationService`, `FlatHost`) dùng chung profile này.

---

## Tasks

- [x] **Task 1.1:** Xác định đường dẫn User Data Directory an toàn trên Windows bằng `path_provider` hoặc biến môi trường `APPDATA`.
- [x] **Task 1.2:** Cập nhật `main.dart` để gọi `WebviewController.initializeEnvironment(userDataPath: ..., additionalArguments: '--use-fake-ui-for-media-stream --enable-usermedia-screen-capturing')` trước khi khởi chạy app.
- [x] **Task 1.3:** Kiểm tra đảm bảo không có controller nào được khởi tạo trước khi `initializeEnvironment` hoàn thành.
- [x] **Task 1.4:** Viết test hoặc verify hàm khởi tạo môi trường hoạt động tốt trên môi trường Windows native.
