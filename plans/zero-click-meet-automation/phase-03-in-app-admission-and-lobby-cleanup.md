# Phase 3: In-App Student Admission & Lobby UI Modernization

**Phase:** 3  
**Status:** Completed  
**Spec Story:** [P1] In-App Admission, [P1] Removal of Manual Workarounds, [P2] Auto-Admit  

---

## Objective
1. Gỡ bỏ hoàn toàn nút mở Chrome thủ công ở `ClassroomLobbyScreen`.
2. Đảm bảo toàn bộ luồng tiếp nhận học sinh và duyệt học sinh diễn ra 100% trong App (`StudioAdmissionBanner` và `admitAllPending()`).
3. Cung cấp tùy chọn cấu hình Auto-Admit để tự động chấp nhận học sinh vào lớp ngay tức thì.

---

## Tasks

- [x] **Task 3.1:** Xóa bỏ `_openChromeToCreateRoom()` và các nút "Mở Chrome tạo phòng mới", "Dán từ Clipboard" trong `classroom_lobby_screen.dart`.
- [x] **Task 3.2:** Tinh chỉnh trạng thái phòng trong `ClassroomLobbyScreen` để hiển thị link phòng tự động tạo một cách trực quan, có nút Sao chép link để gửi vào Zalo/Facebook lớp.
- [x] **Task 3.3:** Kiểm tra và hoàn thiện kịch bản `admitAll()` trong `meet_bridge_script.dart` để đảm bảo click trúng nút duyệt học sinh trong Google Meet mới nhất.
- [x] **Task 3.4:** Thêm cờ cấu hình `autoAdmitEnabled` (mặc định bật hoặc cho phép giáo viên tùy chọn trong Studio Header/Settings).
