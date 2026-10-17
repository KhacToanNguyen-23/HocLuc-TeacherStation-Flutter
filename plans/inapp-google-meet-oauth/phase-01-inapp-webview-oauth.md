# Phase 1: In-App WebView2 OAuth Bridge

**Goal:** Chuyển đổi luồng Google OAuth authorization từ mở trình duyệt hệ thống (`openExternalUrl`) sang mở cửa sổ dialog Edge WebView2 nội bộ, sử dụng thư mục dữ liệu chia sẻ `WebviewEnvironmentService.defaultUserDataPath`.

---

## Tasks

1. **Cập nhật `GoogleConnectionFlow`:**
   - Hỗ trợ nhận `BuildContext context` để có thể mở dialog WebView2 trực tiếp trong app.
   - Gọi `GoogleWebviewLoginDialog.showOAuth(context, initialUrl: flow['authorizationUrl'])`.
   - Lắng nghe URL chuyển hướng trong WebView2: khi gặp `http://127.0.0.1:47831/api/integrations/google/callback`, ghi nhận callback thành công và đóng dialog.

2. **Cập nhật `GoogleWebviewLoginDialog`:**
   - Thêm chế độ xử lý URL OAuth (hỗ trợ `authorizationUrl` chứa scope Classroom/Calendar/Meet).
   - Thêm logic tự động nhận biết khi backend hoàn tất callback (`poll` trả về `status == 'COMPLETE'`), đóng dialog với kết quả email kết nối thành công.
   - Đảm bảo môi trường WebView2 khởi tạo với `WebviewEnvironmentService.ensureInitialized()`.

## Verification Criteria
- Bấm kết nối Google không làm mở bất kỳ cửa sổ trình duyệt nào bên ngoài app.
- Dialog WebView2 hiển thị màn hình đăng nhập Google và màn hình cấp quyền của Google đầy đủ.
- Sau khi bấm "Cho phép", dialog tự đóng và trả về kết quả email kết nối hợp lệ.
