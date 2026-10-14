# Phase 5: Camera Device Isolation & Interactive Google Login Gate

**Status:** Not Started  
**Covers:** [P1] Zero-Friction Host Creation, [P1] Camera Device Freedom, [P1] One-Time Login Gate  
**Risk:** Medium  

---

## Context & Root Causes
1. **Lỗi `Camera with given device id already exists`:**
   - WebView2 khi khởi chạy Chromium ngầm mặc định dò tìm và khóa độc quyền webcam phần cứng DirectShow của Windows.
   - Khi `ClassroomLobbyScreen` của Flutter (`TeacherMediaService`) mở camera để preview thì Windows từ chối truy cập.
   - **Khắc phục:** Bổ sung cờ `--use-fake-device-for-media-stream` vào `WebviewEnvironmentService`. Cờ này hướng dẫn Chromium tạo luồng video tổng hợp giả lập cho WebView2 ngầm, giải phóng 100% webcam vật lý cho Flutter.

2. **Lỗi `Chưa có link Google Meet` & Treo 25s:**
   - Khi WebView2 chưa có session đăng nhập Google, trang `https://meet.google.com/new?hs=193` lập tức chuyển hướng về `https://accounts.google.com/signin`.
   - Vì WebView2 chạy ẩn (headless), giáo viên không nhìn thấy giao diện đăng nhập để điền thông tin, dẫn đến timeout 25s và trả về `null`.
   - **Khắc phục:**
     - Trong `MeetAutomationService`: Bắt sự kiện URL khi phát hiện chuyển hướng sang domain `accounts.google.com` $\rightarrow$ Đánh dấu trạng thái `needsGoogleLogin = true` hoặc ném `GoogleAuthRequiredException` để hủy sớm việc chờ đợi vô ích.
     - Trong `ClassroomDashboardScreen._startClassroom()`: Nếu phát hiện cần đăng nhập, lập tức mở `GoogleWebviewLoginDialog` để giáo viên đăng nhập trực quan 1 lần duy nhất (lưu vào EdgeProfile dùng chung). Sau khi đăng nhập thành công, tự động tiếp tục tạo phòng và chuyển sang Lobby.
     - Trong `ClassroomLobbyScreen`: Mở ra với `initialMeetingUrl` đã có giá trị sẵn. Nút "Bắt đầu vào phòng giảng dạy" đưa thẳng vào `StudioScreen` mà không hiện popup cảnh báo.

---

## Tasks

### Task 5.1: Bổ sung cờ `--use-fake-device-for-media-stream`
- **File:** [`lib/services/webview_environment_service.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/webview_environment_service.dart)
- Thêm `--use-fake-device-for-media-stream` vào `additionalArguments`.
- Cập nhật test trong [`test/webview_environment_service_test.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/test/webview_environment_service_test.dart).

### Task 5.2: Nhận diện yêu cầu đăng nhập trong `MeetAutomationService`
- **File:** [`lib/services/meet_automation_service.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_automation_service.dart)
- Khai báo flag `bool needsGoogleLogin = false`.
- Trong `_urlSubscription`, nếu `url.contains('accounts.google.com')`:
  - Set `needsGoogleLogin = true`.
  - Cancel timeout và hoàn tất completer sớm với mã/exception nhận diện được.

### Task 5.3: Tích hợp One-Time Login Gate tại Dashboard
- **File:** [`lib/screens/classroom_dashboard_screen.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/screens/classroom_dashboard_screen.dart)
- Trong `_startClassroom`:
  - Nếu `realMeetUrl == null` do cần đăng nhập:
    - Bật `GoogleWebviewLoginDialog.show(context)`.
    - Khi đăng nhập thành công $\rightarrow$ Tự động thử lại `generateAndJoinRealMeetRoom()`.
  - Khi đã có `realMeetUrl` $\rightarrow$ Điều hướng tới `ClassroomLobbyScreen(initialMeetingUrl: realMeetUrl)`.

### Task 5.4: Kiểm thử và Xác thực End-to-End
- Chạy `flutter test` toàn bộ test suite.
- Xác thực luồng tạo phòng Meet, không bị lỗi camera trùng device id, và không bị popup chặn ở Lobby.

---

## Verification
- Lệnh: `flutter test`
- Tiêu chí:
  - 100% unit/widget test pass.
  - Cờ Chromium `--use-fake-device-for-media-stream` được thiết lập chính xác.
  - Luồng bấm Bắt đầu $\rightarrow$ Có link Meet $\rightarrow$ Vào thẳng Studio không còn popup chặn.
