# Spec: Tinh Gọn Lobby Chuẩn Google Meet & Bổ Sung Quản Lý Học Sinh (Mic/Cam/Join)

**Date:** 2026-10-12  
**Status:** Ready

---

## Problem Statement
Giao diện Lobby hiện tại chứa nhiều khối chữ mô tả rườm rà, thiếu nút Hủy phòng học / Quay lại Dashboard trực quan, và trong Studio thiếu hoàn toàn khu vực cho phép học sinh tham gia cũng như quản lý Mic/Cam của từng học sinh (không có thanh video/avatar học sinh, không thấy học sinh ai đang nói, không có chỗ duyệt/tắt tiếng học sinh).

---

## User Stories

- **[P1]** Là giáo viên ở Lobby, tôi muốn giao diện chuẩn tối giản như Google Meet Green Room (camera lớn bên trái với các nút tròn nổi bên dưới, tiêu đề và link chia sẻ bên phải, không có mô tả rườm rà) để vào lớp nhanh chóng và tập trung.
  Accepted when: Lobby loại bỏ các description text rườm rà, các nút điều khiển Mic/Cam/Phông nền nổi trực tiếp trên video preview.

- **[P1]** Là giáo viên ở Lobby hoặc Studio, tôi muốn có nút "Hủy / Quay lại Dashboard" và "Kết thúc lớp học" rõ ràng để có thể rời phòng hoặc hủy buổi dạy bất cứ lúc nào.
  Accepted when: Có nút hủy phòng tại Lobby và nút kết thúc/rời lớp tại Studio với hộp thoại xác nhận.

- **[P1]** Là giáo viên trong Studio, tôi muốn thấy dải học sinh (Student Strip) nằm ngang phía trên bảng đen (chuẩn Zoom) hiển thị avatar/video, tên và trạng thái Mic/Cam của từng em để quan sát cả lớp trong lúc giảng bài.
  Accepted when: Dải học sinh hiển thị ngang dưới Top Bar, có trạng thái Mic/Cam và biểu tượng giơ tay ✋, có nút thu gọn/mở rộng.

- **[P1]** Là giáo viên trong Studio, tôi muốn nhận thông báo khi có học sinh xin vào phòng Meet và có thể bấm [Duyệt] / [Duyệt tất cả] ngay trên màn hình mà không cần mở tab Google Meet ngoài.
  Accepted when: Banner xin vào lớp xuất hiện nổi bật khi có yêu cầu và bấm duyệt gọi script Meet tự động.

- **[P2]** Là giáo viên trong Studio, tôi muốn có Sidebar danh sách học sinh (Participants Drawer) kèm tính năng "Tắt tiếng tất cả" (Mute All) hoặc tắt tiếng từng học sinh để duy trì trật tự lớp học.
  Accepted when: Mở được danh sách học sinh từ icon trên Top Bar và thực hiện được lệnh Mute.

---

## Functional Requirements

1. **FR-01 (Lobby Minimalistic Overhaul):**
   - Tinh gọn `LobbyMediaPreview`: Khung camera 16:9 với 3 nút tròn nổi: Bật/Tắt Mic (kèm hiệu ứng sóng âm thanh), Bật/Tắt Camera, Đổi phông nền ảo. Icon bánh răng mở popup cài đặt thiết bị.
   - Tinh gọn `LobbyMeetRoomCard`: Tiêu đề bài giảng lớn, trạng thái tài khoản Google, link Google Meet kèm icon sao chép nhanh, nút "Bắt đầu vào phòng" và nút "Hủy / Quay lại Dashboard".
   - Tinh gọn `LobbyHeader`: Nút "← Quay lại Dashboard" to rõ ràng.
2. **FR-02 (Exit / Cancel Actions):**
   - Thêm nút "Hủy phòng học" tại Lobby -> Chuyển về Dashboard.
   - Thêm nút "Rời phòng / Kết thúc" tại `StudioTopBar` -> Hiện dialog xác nhận -> Đóng meeting và chuyển về Dashboard.
3. **FR-03 (Student Video/Avatar Strip):**
   - Tạo widget `StudioStudentStrip`:
     - Danh sách học sinh nằm ngang trên bảng đen.
     - Hiển thị Avatar / Initials, Tên, Icon Mic (đỏ nếu mute, xanh nếu nói), Icon Cam, Icon Giơ tay ✋.
     - Nút mũi tên thu gọn/mở rộng dải này.
4. **FR-04 (Student Admission Banner):**
   - Khi `pendingAdmitCount > 0`, hiển thị banner nổi bật ngay trong Studio: "X học sinh đang xin vào lớp" -> Nút [Cho vào tất cả].
5. **FR-05 (Students Participants Sidebar):**
   - Tạo widget `StudioStudentsDrawer` (hoặc tích hợp vào Inspector Panel):
     - Hiển thị đầy đủ danh sách học sinh.
     - Nút "Tắt tiếng cả lớp" (Mute All).
     - Nút "Tắt tiếng" từng học sinh.
6. **FR-06 (Data Model & Bridge Integration):**
   - Cung cấp model `MeetParticipant` trong `meet_events.dart` (`id`, `name`, `isMuted`, `isCameraOn`, `isHandRaised`, `isSpeaking`).
   - Cập nhật `MeetAutomationService` quản lý `List<MeetParticipant> _participants`.

---

## Non-Functional Requirements

- **UX Tinh tế:** Không có bất kỳ khối chữ mô tả kỹ thuật không cần thiết nào (loại bỏ "Tín hiệu Micro: -20 dB", "Nguồn Video (Camera)", "Link lớp học chính thức gửi cho học sinh:").
- **Tối ưu Bảng viết:** Dải học sinh nhỏ gọn (chiều cao ~72px), cho phép ẩn/hiện tức thì.
- **Tính toàn vẹn (Zero Regression):** Toàn bộ 45 unit/widget tests hiện có tiếp tục PASS 100%.

---

## Success Criteria

- [ ] Lobby có bố cục tinh gọn chuẩn Google Meet: Camera 60% bên trái với các nút nổi, tiêu đề & link & 2 nút Bắt đầu / Hủy 40% bên phải.
- [ ] Giáo viên có thể bấm "Hủy / Quay lại Dashboard" tại Lobby và "Kết thúc lớp học" tại Studio.
- [ ] Trong Studio hiển thị dải học sinh (Student Strip) với trạng thái Mic/Cam/Giơ tay.
- [ ] Giáo viên có thể duyệt học sinh xin vào và bấm "Tắt tiếng tất cả".
- [ ] `flutter analyze lib` báo cáo 0 lỗi.
- [ ] `flutter test` đạt 45/45 passed.
