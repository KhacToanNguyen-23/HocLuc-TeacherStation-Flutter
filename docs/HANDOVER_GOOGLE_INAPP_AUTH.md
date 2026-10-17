# 📌 HANDOVER: HỢP NHẤT XÁC THỰC GOOGLE CLASSROOM & MEET IN-APP (ZERO-CLICK SSO)

> **Dành cho:** Thành viên phụ trách nhánh Google Workspace & Meet Automation  
> **Mục tiêu:** Tạo link phòng học, mời học sinh tự động từ Google Classroom, Host Meet trong app — **100% trong app, Zero-click ra ngoài trình duyệt, Giáo viên chỉ đăng nhập 1 lần duy nhất**.

---

## 1. Bối cảnh & Vấn đề cần giải quyết

### 1.1. Hiện trạng trước đây:
- App Flutter Desktop sử dụng Microsoft Edge WebView2 nhúng trong app để giáo viên đăng nhập Google và mở phòng Google Meet (`meet.google.com/new`).
- WebView2 có thư mục lưu profile riêng tại `%APPDATA%\HocLucTeacherStation\EdgeProfile`. Nhờ đó app có thể điều khiển giao diện Meet: tự vào làm Host, ảo hóa camera bài giảng, đọc Chat, Giơ tay và tự động duyệt học sinh.

### 1.2. Nhu cầu nâng cấp mới:
- Kết nối **Google Classroom API** để lấy danh sách học sinh.
- Kết nối **Google Calendar API** để tự động sinh link Google Meet kèm danh sách email học sinh trong `attendees`.
- 👉 **Mục đích:** Học sinh có email trong lớp khi bấm link Meet được **VÀO THẲNG PHÒNG HỌC, KHÔNG CẦN GIÁO VIÊN BẤM DUYỆT (ADMIT)**.

### 1.3. Vấn đề gây ức chế UX cần sửa:
- Trước đây, luồng cấp quyền OAuth lại mở trình duyệt ngoài (Chrome mặc định của máy tính).
- Do Chrome ngoài và Edge WebView2 trong app độc lập cookie với nhau, giáo viên đăng nhập trên Chrome xong, khi vào dạy học thì **WebView2 lại bắt đăng nhập Google lần 2**.
- **Hiểu lầm trước đó:** *"Nếu chuyển sang OAuth thì sợ mất WebView2 nên không điều khiển được Meet"*.  
  👉 **Thực tế:** Hoàn toàn không mất! Ta hợp nhất toàn bộ luồng OAuth chạy ngay trong chính WebView2 của app để **giáo viên chỉ cần đăng nhập đúng 1 lần duy nhất**.

---

## 2. Kiến trúc giải pháp (In-App Unified SSO Flow)

```
[Màn hình Login chính của App]
       │
       ▼ (Giáo viên nhấn icon 'G' Google)
[GoogleWebviewLoginDialog mở ra ngay trong App]
  ├── Tải URL cấp quyền Google OAuth
  └── Giáo viên đăng nhập & bấm "Cho phép" (Allow)
       │
       ├──► [Backend Spring Boot - Port 47831]
       │    └── Nhận callback `GET /api/integrations/google/callback?code=...`
       │    └── Đổi code lấy Refresh Token / Access Token
       │    └── Mã hóa AES lưu an toàn vào database (dùng để gọi Classroom/Calendar API)
       │
       └──► [Frontend Edge WebView2]
            └── Tự động lưu Google Session Cookie vào `%APPDATA%\HocLucTeacherStation\EdgeProfile`
            └── Bắt sự kiện redirect callback -> Tự động đóng Dialog
            └── App chuyển thẳng vào ClassroomDashboardScreen
       │
       ▼
[Tại Dashboard: Bấm "Bắt đầu buổi học" của lớp]
       │
       ▼
[Backend tự động xử lý ngầm]
  ├── Đồng bộ danh sách email học sinh từ Classroom
  └── Gọi Google Calendar API tạo Event có Hangouts Meet
  └── Gán danh sách học sinh vào mảng `attendees`
  └── Trả về link Meet: `https://meet.google.com/xxx-yyyy-zzz`
       │
       ▼
[Mở Studio Dạy Học trong App]
  └── WebView2 mở link Meet vừa sinh
  └── Vì WebView2 ĐÃ CÓ COOKIE từ bước đầu -> Tự động vào phòng là HOST
  └── Học sinh bấm link vào thẳng không cần duyệt (Admit)
```

---

## 3. Các file code đã cập nhật trong nhánh

1. **`frontend/lib/services/google_connection_flow.dart`:**
   - Thay `openExternalUrl` (mở Chrome ngoài) bằng `GoogleWebviewLoginDialog.show(context, initialUrl: authUrl)`.
   - Polling endpoint `/api/integrations/google/poll`, tự động đóng dialog khi backend hoàn tất.

2. **`frontend/lib/widgets/auth/google_webview_login_dialog.dart`:**
   - Thêm cờ `isOAuth` để không chạy extract DOM sớm khi giáo viên đang ở trang Consent cấp quyền của Google.
   - Bắt sự kiện redirect về `http://127.0.0.1:47831/api/integrations/google/callback` để đóng dialog an toàn.

3. **`frontend/lib/widgets/auth/auth_form_card.dart`:**
   - Nút Google kết nối với luồng In-App WebView2 OAuth.
   - **Tích hợp Fallback thông minh:** Nếu Backend chưa nạp Client ID Google Cloud, app tự động fallback mở đăng nhập Google trực tiếp qua WebView2 (`https://accounts.google.com/signin`) để giáo viên vẫn đăng nhập vào app và dạy Meet bình thường mà không bị crash hay kẹt lỗi đỏ.

4. **`backend/api/src/main/java/vn/teaching/integrations/GoogleClassService.java`:**
   - Backend đã có sẵn logic tại `schedule()` và `start()`: tự động đưa email học sinh (`students` có `meetAllowed == true`) vào mảng `attendees` của Calendar Event với `conferenceData` loại `hangoutsMeet`.

---

## 4. Checklist công việc cần làm tiếp

- [ ] **1. Cấu hình Google Cloud Console (Để chạy OAuth thật):**
  - Vào [Google Cloud Console](https://console.cloud.google.com/) -> Bật **Classroom API**, **Calendar API**, **Meet API**.
  - Tạo OAuth Client ID loại **Desktop App**.
  - Authorized redirect URIs: `http://127.0.0.1:47831/api/integrations/google/callback`.
  - Cấu hình trong `backend/api/src/main/resources/application.properties` (hoặc set biến môi trường):
    ```properties
    app.integrations.google.client-id=YOUR_CLIENT_ID.apps.googleusercontent.com
    app.integrations.google.client-secret=YOUR_CLIENT_SECRET
    app.integrations.google.encryption-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
    ```
- [ ] **2. Kiểm tra thực tế trên Windows Desktop:**
  - Chạy backend: `mvn spring-boot:run`
  - Chạy frontend: `flutter run -d windows`
  - Bấm nút Google ở màn hình Login: Kiểm tra popup mở trong app, không nhảy ra Chrome ngoài.
  - Sau khi đăng nhập: Vào lớp học -> Bấm Bắt đầu buổi học -> Vào Studio: Kiểm tra WebView2 tự động nhận diện tư cách Host.
  - Dùng tài khoản học sinh bấm link Meet: Xác nhận vào thẳng phòng không cần host bấm duyệt.
- [ ] **3. Chạy kiểm thử tự động trước khi merge:**
  - `flutter test test/architecture_test.dart test/google_workspace_test.dart`
  - `mvn test -Dtest=GoogleIntegrationTest`
