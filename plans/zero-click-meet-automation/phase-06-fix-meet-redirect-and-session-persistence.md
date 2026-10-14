# Phase 6: Fix Meet Redirect Chain & Seamless Session Persistence

**Status:** Not Started  
**Covers:** [P1] Browser Session Persistence, [P1] Auto Room Creation without False Login Abort, [P1] Seamless Lobby Transition  
**Risk:** Normal  

---

## Context & Root Cause
1. **Lỗi ngắt nhầm redirect tạo phòng Meet:**
   - Khi điều hướng tới `https://meet.google.com/new?hs=193`, Google luôn redirect qua `accounts.google.com/CheckCookie` trong ~0.5s để xác thực phiên đã lưu.
   - Bộ lắng nghe `if (url.contains('accounts.google.com'))` và script `return 'NEEDS_LOGIN'` trong `MeetAutomationService` đã ngắt tiến trình tạo phòng quá sớm, trả về `null` dù cookie đã lưu đầy đủ trong `%APPDATA%\HocLucTeacherStation\EdgeProfile`.
2. **Hậu quả kép:**
   - Dashboard nhận `null` nên tự động bật lại popup đăng nhập dù người dùng đã đăng nhập ở LoginScreen.
   - Popup đăng nhập bật lại trong trạng thái tài khoản đã có sẵn khiến form đăng nhập bị lỗi ("đăng nhập đúng lại sai").
   - Lobby không nhận được link phòng thật.

---

## Tasks

### Task 6.1: Đồng bộ môi trường WebView2 trong `GoogleWebviewLoginDialog`
- **File:** [`frontend/lib/widgets/auth/google_webview_login_dialog.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/auth/google_webview_login_dialog.dart)
- Thêm lệnh `await WebviewEnvironmentService.ensureInitialized();` trước khi `controller.initialize()` để đảm bảo dialog đăng nhập luôn dùng chính xác thư mục EdgeProfile chung.

### Task 6.2: Gỡ bỏ bộ ngắt chặn nhầm trong `MeetAutomationService`
- **File:** [`frontend/lib/services/meet_automation_service.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_automation_service.dart)
- Xóa bỏ việc ngắt tức thì khi gặp `accounts.google.com`.
- Cho phép Google tự nhiên xử lý chuỗi redirect: `meet.google.com/new` $\rightarrow$ `CheckCookie` $\rightarrow$ `meet.google.com/xxx-yyyy-zzz`.
- Chỉ đánh dấu `needsGoogleLogin = true` khi timeout hoặc trang dừng hẳn ở trang nhập mật khẩu/email mà không chuyển tiếp.

### Task 6.3: Tinh giản luồng Dashboard sang Lobby
- **File:** [`frontend/lib/screens/classroom_dashboard_screen.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/screens/classroom_dashboard_screen.dart)
- Khi bấm "Bắt đầu": Chờ `generateAndJoinRealMeetRoom()` lấy mã phòng thật.
- Khi có link $\rightarrow$ Chuyển thẳng sang `ClassroomLobbyScreen(initialMeetingUrl: realMeetUrl)`.
- Loại bỏ việc tự động mở lại dialog đăng nhập Google ở Dashboard (vì giáo viên đã đăng nhập ở Login screen).

### Task 6.4: Kiểm thử và Xác thực Toàn diện
- Chạy `flutter test` đảm bảo 100% test pass.
- Xác nhận không còn lỗi gián đoạn tạo link, phiên đăng nhập được giữ vững.

---

## Verification
- Lệnh kiểm thử: `flutter test`
- Tiêu chí:
  - 100% test suite pass.
  - `generateAndJoinRealMeetRoom()` sinh được link thật dạng `https://meet.google.com/xxx-yyyy-zzz`.
  - Dashboard chuyển vào Lobby với link đã có sẵn 100%.
