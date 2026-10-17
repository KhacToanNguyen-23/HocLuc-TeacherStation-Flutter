# Phase 2: Login Screen & Auth Service Integration

**Goal:** Tích hợp nút Google tròn tại `AuthFormCard` (màn hình Login chính) với luồng In-App WebView2 OAuth mới và đồng bộ phiên đăng nhập của giáo viên.

---

## Tasks

1. **Cập nhật `_handleGoogleSignInAction()` trong `auth_form_card.dart`:**
   - Truyền `BuildContext context` vào `GoogleConnectionFlow.connect`.
   - Hiển thị dialog WebView2 để giáo viên thao tác.
   - Khi hoàn tất, gọi `_authService.signInWithGoogleConnection(email)` và kích hoạt `widget.onSuccess?.call()`.

2. **Cập nhật `GoogleMeetAuthService`:**
   - Đảm bảo `signInWithGoogleConnection` lưu thông tin phiên đầy đủ vào `SharedPreferences`: `_isSignedIn = true`, `_teacherEmail = email`, `_teacherName = displayName`.
   - Đảm bảo cơ chế tự động khôi phục phiên (`init()`) hoạt động ổn định khi khởi động app lần sau.

## Verification Criteria
- Tại màn hình LoginScreen: Nhấn nút icon Google -> Dialog WebView2 mở ra -> Đăng nhập & cho phép -> App tự chuyển vào `ClassroomDashboardScreen`.
- Đóng app và mở lại -> App tự động vào thẳng Dashboard (Session được giữ nguyên).
