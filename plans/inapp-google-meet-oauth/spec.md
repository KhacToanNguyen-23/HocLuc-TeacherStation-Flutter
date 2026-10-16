# Spec: In-App Zero-Click Google Meet & Classroom Unified Auth

**Date:** 2026-10-16  
**Status:** Ready  

---

## Problem Statement
Giáo viên hiện đang phải đăng nhập tài khoản Google 2 lần riêng biệt (1 lần trên Chrome bên ngoài để cấp quyền Classroom/Calendar và 1 lần trong Edge WebView2 để có session Host phòng Google Meet). Điều này gây cản trở và trải nghiệm người dùng rất xấu khi tổ chức lớp học trực tuyến. Hệ thống cần hợp nhất toàn bộ luồng tạo link, mời học sinh tự động và mở phòng Meet vào 1 lần đăng nhập duy nhất ngay bên trong ứng dụng (Zero-click ra ngoài).

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** Là một giáo viên, tôi muốn nhấn "Đăng nhập Google" ngay tại màn hình Login của app và hoàn tất đăng nhập/cấp quyền trong cửa sổ nhúng duy nhất, để tôi không phải rời khỏi ứng dụng hay chuyển sang trình duyệt bên ngoài.  
  *Accepted when:* Bấm nút Google ở LoginScreen mở dialog WebView2 tải luồng OAuth của Google, sau khi đăng nhập và chấp nhận quyền, dialog đóng lại và app chuyển thẳng vào ClassroomDashboardScreen với đầy đủ thông tin giáo viên.

- **[P1]** Là một giáo viên, tôi muốn khi bắt đầu buổi học của một lớp, hệ thống tự động sinh link Google Meet có mời sẵn toàn bộ email học sinh trong lớp, để học sinh được vào thẳng phòng mà tôi không phải bấm duyệt (admit) từng em.  
  *Accepted when:* Backend gọi Google Calendar API / Meet Spaces API với danh sách email học sinh trong `attendees`, trả về link Meet thật (`https://meet.google.com/xxx-yyyy-zzz`).

- **[P1]** Là một giáo viên, tôi muốn khi mở phòng học trong Studio, ứng dụng tự động nhận diện tôi là Host của phòng Google Meet mà không bắt tôi đăng nhập lại lần thứ hai.  
  *Accepted when:* Edge WebView2 mở link Meet đã tạo và nhận diện tài khoản Google của giáo viên ngay lập tức (dựa vào session cookie đã được lưu trong `%APPDATA%\HocLucTeacherStation\EdgeProfile` từ bước đăng nhập).

- **[P2]** Là một giáo viên, tôi muốn hệ thống tự động làm mới (refresh) token Google ngầm khi hết hạn 1 giờ, để buổi dạy không bị ngắt quãng giữa chừng.  
  *Accepted when:* Backend tự động dùng Refresh Token để lấy Access Token mới mà không yêu cầu giáo viên thao tác lại.

- **[P3]** *(Out of scope)*: Tự động ghi âm/ghi hình cuộc họp Google Meet trực tiếp lên Google Drive qua Cloud API (Google yêu cầu gói Google Workspace Enterprise/Education Plus).

---

## Functional Requirements

1. **FR-01 (In-App OAuth Flow):** Chuyển đổi `GoogleConnectionFlow.connect` để tải `authorizationUrl` trong `GoogleWebviewLoginDialog` (sử dụng môi trường `WebviewEnvironmentService.defaultUserDataPath`) thay vì gọi `openExternalUrl` mở trình duyệt OS.
2. **FR-02 (Localhost Redirect Capture):** Khi Google hoàn tất cấp quyền và chuyển hướng về `http://127.0.0.1:47831/api/integrations/google/callback`, WebView2 bắt được trạng thái thành công, tự đóng dialog và trả kết quả xác thực về Flutter App.
3. **FR-03 (Headless Meeting Generation):** Backend `GoogleClassService.schedule` / `start` tự động đồng bộ danh sách học sinh từ Classroom và tạo sự kiện Google Calendar có `conferenceData` (Hangouts Meet) chứa danh sách attendees.
4. **FR-04 (Host Auto-Join in Studio):** `StudioScreen` và `MeetAutomationService` nạp link Meet đã sinh sẵn vào WebView2 điều khiển phòng, tiêm script hỗ trợ bài giảng (camera ảo, nhận diện giơ tay, chat) mà không yêu cầu xác thực phụ.
5. **FR-05 (Session Persistence):** Session cookie của Google trong WebView2 và OAuth refresh token trong backend được lưu bền vững, chỉ yêu cầu đăng nhập lại khi người dùng chủ động nhấn "Đăng xuất" hoặc Google thu hồi quyền.

---

## Non-Functional Requirements

- **Performance:** Thời gian mở dialog đăng nhập Google WebView2 < 1.5 giây trên Windows Desktop; thời gian tạo phòng và trả link Meet từ Backend < 3 giây.
- **Security:** 
  - OAuth 2.0 PKCE (`code_verifier`, `code_challenge` SHA-256) được duy trì nghiêm ngặt.
  - Secret và refresh token chỉ lưu tại Backend (`GoogleStore`), không phơi bày ra frontend client.
- **Reliability:** Phiên WebView2 sử dụng đường dẫn cố định `%APPDATA%\HocLucTeacherStation\EdgeProfile`, chống mất phiên khi cập nhật ứng dụng.

---

## Success Criteria

- [ ] Số lần giáo viên phải đăng nhập tài khoản Google để vừa có lớp Classroom vừa Host được Google Meet: **Chính xác 1 lần**.
- [ ] Số lần app phải mở cửa sổ trình duyệt ngoài (Chrome/Edge bên ngoài app): **0 lần (Zero external click)**.
- [ ] Học sinh có email trong danh sách lớp khi bấm vào link Meet: **Được vào thẳng cuộc họp mà Host không phải nhấn Chấp nhận (Knock/Admit)**.
- [ ] Màn hình Studio trong app nhúng và điều khiển được giao diện Meet mượt mà với đầy đủ quyền Host.

---

## Out of Scope

- Không can thiệp vào máy chủ Google Meet (chỉ tương tác qua Google Workspace Open APIs và DOM bridge script hợp lệ).
- Không ép chia đôi màn hình cố định trong Studio (giữ nguyên bố cục dock / popup linh hoạt hiện tại).

---

## Assumptions

- Máy tính giáo viên sử dụng hệ điều hành Windows 10/11 đã có sẵn Microsoft Edge WebView2 Runtime (thành phần mặc định trên Windows 10 bản mới và Windows 11).
- Tài khoản Google của giáo viên được phép tạo Calendar Event và Meet Conference (tài khoản cá nhân @gmail.com hoặc tài khoản trường học @edu.vn/Workspace).
