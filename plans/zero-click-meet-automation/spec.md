# Spec: Zero-Click Google Meet Host Automation & Persistent Session

**Date:** 2026-10-14  
**Status:** Ready  

---

## Problem Statement
Mô hình tự động hóa Google Meet hiện tại trong Teacher Station bị mất tính "Zero-Click" do 4 lỗi kiến trúc:
1. Mỗi instance WebView2 khởi tạo độc lập không chia sẻ User Data Folder, khiến phiên đăng nhập Google bị mất khi mở Meet ngầm.
2. Tham số `authuser=$email` trong URL chuyển hướng sai, khiến Google Meet văng ra trang đăng nhập.
3. Hộp thoại hỏi quyền Media Native của Chromium chặn nút "Tham gia ngay".
4. App phải có nút fallback "Mở Chrome tạo phòng", khiến giáo viên phải chuyển sang trình duyệt ngoài để bấm tạo phòng và duyệt học sinh.

Hệ thống cần chuẩn hóa WebView2 ngầm với Profile cố định, tự động cấp quyền media, tự động tham gia phòng với tư cách Host, và quản lý duyệt học sinh 100% trong App.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** Là một giáo viên, tôi muốn khi đăng nhập Google trong App thì phiên đăng nhập được lưu vĩnh viễn trên máy để các buổi dạy sau không bao giờ phải đăng nhập lại hay bị hỏi mật khẩu.  
  *Accepted when:* Đăng nhập Google 1 lần trong `GoogleWebviewLoginDialog`, tắt app, mở lại và gọi `generateAndJoinRealMeetRoom()` mà WebView2 vẫn giữ nguyên trạng thái đã đăng nhập của tài khoản Google đó.

- **[P1]** Là một giáo viên, tôi muốn khi bấm "Bắt đầu" ở Dashboard, App tự động tạo phòng Google Meet thật và tự động tham gia làm Chủ phòng (Host) ngầm mà tôi không cần mở bất kỳ cửa sổ trình duyệt nào.  
  *Accepted when:* Bấm "Bắt đầu", App sinh được URL dạng `meet.google.com/xxx-yyyy-zzz` trong ≤ 5 giây mà không mở cửa sổ Chrome ngoài, và WebView2 ngầm đã ở trạng thái đã tham gia cuộc họp (`MEET_JOINED`).

- **[P1]** Là một giáo viên, tôi muốn khi học sinh bấm link Meet xin vào lớp, thông báo sẽ hiện ngay trên Banner trong Studio của App và tôi có thể bấm "Duyệt tất cả" ngay trên App mà không cần mở Google Meet.  
  *Accepted when:* Học sinh bấm xin vào trên điện thoại/máy tính $\rightarrow$ `StudioAdmissionBanner` trên App hiện số lượng học sinh chờ; bấm "Duyệt tất cả" trên banner $\rightarrow$ học sinh được chấp nhận vào phòng Meet.

- **[P1]** Là một giáo viên, tôi muốn loại bỏ hoàn toàn các nút "Mở Chrome tạo phòng mới" và "Dán từ Clipboard" để giao diện lớp học hoàn toàn sạch sẽ và tự động.  
  *Accepted when:* Giao diện `ClassroomLobbyScreen` không còn các nút mở Chrome thủ công; quy trình tạo phòng diễn ra tự động 100%.

- **[P2]** Là một giáo viên, tôi muốn có tùy chọn "Tự động duyệt học sinh" (Auto-Admit toggle) trong App để khi học sinh vào lớp, app tự động duyệt ngay lập tức mà tôi không cần bấm tay.  
  *Accepted when:* Bật toggle "Tự động duyệt" $\rightarrow$ học sinh bấm xin vào được duyệt tự động trong < 1 giây mà không cần bấm banner.

---

## Functional Requirements

1. **FR-01 (Persistent WebView2 User Data Directory):**
   - Định nghĩa đường dẫn cố định cho thư mục Profile WebView2: `%APPDATA%/HocLucTeacherStation/EdgeProfile`.
   - Cả `GoogleWebviewLoginDialog` và `MeetAutomationService` đều phải khởi tạo WebView2 trỏ về cùng thư mục này để dùng chung 100% Cookies, LocalStorage và Session của Google.

2. **FR-02 (Native Media Permissions & Chromium Flags):**
   - Cấu hình cờ khởi động Chromium của WebView2: `--use-fake-ui-for-media-stream`, `--use-fake-device-for-media-stream`, `--enable-usermedia-screen-capturing`.
   - `--use-fake-device-for-media-stream` đảm bảo Chromium không chiếm dụng webcam vật lý của Windows, giải phóng 100% phần cứng camera cho Flutter `TeacherMediaService` (tránh lỗi `Camera with given device id already exists`).
   - Tự động cấp quyền `PermissionType.camera` và `PermissionType.microphone` cho domain `https://meet.google.com`.

3. **FR-03 (Correct Google Meet Room Generation URL):**
   - Sửa URL khởi tạo trong `MeetAutomationService` từ `https://meet.google.com/new?authuser=$email...` thành `https://meet.google.com/new?hs=193`.
   - Google Meet sẽ tự động dùng tài khoản đã đăng nhập trong Profile cố định mà không bị chuyển hướng về trang chọn tài khoản.

4. **FR-04 (Host Ownership & In-App Admission):**
   - WebView2 ngầm trong App là Host chính thức của cuộc họp.
   - Khi có học sinh xin vào, `meet_bridge_script` phát hiện qua MutationObserver $\rightarrow$ gửi message `ADMIT_REQUEST` về Flutter.
   - Flutter hiển thị `StudioAdmissionBanner`. Khi bấm "Duyệt tất cả", gọi `window.MeetBridge.admitAll()`.

5. **FR-05 (UI Cleanup & Removal of Manual Workarounds):**
   - Loại bỏ nút "Mở Chrome tạo phòng mới" và "Dán link từ clipboard" ở `classroom_lobby_screen.dart`.
   - Thay thế bằng trạng thái chờ kết nối tự động mượt mà.

6. **FR-06 (Interactive One-Time Google Login Gate):**
   - Khi WebView2 ngầm điều hướng đến `accounts.google.com` (chưa có session Google), hệ thống tự động hiển thị `GoogleWebviewLoginDialog` để giáo viên đăng nhập trực quan 1 lần duy nhất thay vì để headless timeout 25 giây.
   - Sau khi đăng nhập thành công, session được lưu vĩnh viễn trong `%APPDATA%/HocLucTeacherStation/EdgeProfile` và tự động tiếp tục tạo phòng Meet thật.

7. **FR-07 (Seamless Dashboard to Studio Transition):**
   - Khi bấm "Bắt đầu" tại Dashboard: Hệ thống tự động tạo phòng Meet ngầm và tự join Host.
   - Chuyển tiếp vào `ClassroomLobbyScreen` với `initialMeetingUrl` đã có sẵn giá trị.
   - Camera và Mic trong Lobby hiển thị mượt mà không bị lỗi xung đột thiết bị.
   - Bấm "Bắt đầu vào phòng giảng dạy" lập tức chuyển vào `StudioScreen`, không hiện popup chặn "Chưa có link Google Meet".

---

## Non-Functional Requirements

- **Performance:** Thời gian khởi tạo phòng Meet ngầm và lấy URL phòng thật ≤ 5 giây trên đường truyền mạng tiêu chuẩn khi đã đăng nhập.
- **Reliability:** Phiên đăng nhập Google tồn tại bền vững qua các lần tắt/mở ứng dụng mà không cần đăng nhập lại.
- **Zero-Friction:** Giáo viên không phải thao tác bất kỳ click nào trên trang web Google Meet. Không xuất hiện popup chặn lỗi khi vào phòng.

---

## Success Criteria

- [ ] WebView2 ngầm duy trì phiên đăng nhập Google sau khi khởi động lại app.
- [ ] Bổ sung `--use-fake-device-for-media-stream`: Không còn lỗi `Camera with given device id already exists` trong màn hình Lobby.
- [ ] Khi chưa đăng nhập Google, app chủ động bật modal đăng nhập 1 lần duy nhất thay vì timeout ngầm 25s.
- [ ] Bấm "Bắt đầu" tạo được phòng Google Meet thật hoàn toàn dưới nền trong ≤ 5 giây mà không mở Chrome ngoài.
- [ ] Màn hình Lobby hiển thị link Meet đã tạo sẵn, bấm "Bắt đầu vào phòng giảng dạy" vào thẳng Studio mà không bị popup cảnh báo chặn lại.
- [ ] Học sinh bấm link Meet xin vào lớp $\rightarrow$ App hiển thị thông báo và duyệt thành công học sinh vào lớp từ giao diện Studio của App.
- [ ] Không còn nút "Mở Chrome tạo phòng" trong giao diện Lobby.

---

## Out of Scope

- Tích hợp các nền tảng họp khác (Zoom, Microsoft Teams, WebRTC tự host).
- Tính năng ghi hình đám mây của Google Meet (việc ghi hình bài giảng đã có dịch vụ ghi hình cục bộ của Studio).

---

## Assumptions

- Máy tính của giáo viên chạy Windows 10/11 đã cài đặt sẵn Microsoft Edge WebView2 Runtime (được cài mặc định trên Windows).
- Giáo viên có một tài khoản Google (Gmail thông thường hoặc Google Workspace/Edu) và đăng nhập 1 lần vào App.
