# Brainstorm: Tự Động Tạo Link Google Meet Mới Khi Bắt Đầu & Hủy Triệt Để Phòng Tại Lobby

**Date:** 2026-10-12
**Status:** Completed

---

## Problem Statement

Hiện tại khi người dùng bấm "HỦY / QUAY LẠI DASHBOARD" tại Lobby, phòng học vẫn bị lưu ở trạng thái `ONGOING` trên backend và `MeetAutomationService` vẫn giữ URL cũ. Khi người dùng bấm lại "Bắt đầu", hệ thống không tự động sinh ra link Meet mới 100% (hoặc bị giữ lại link cũ / hiển thị "Chưa có link"). Người dùng yêu cầu:
1. Bấm **"Bắt đầu"** là hệ thống **tự động sinh ra 1 link Meet mới 100%**.
2. Khi bấm **"HỦY"** ở Lobby, hệ thống phải **hủy triệt để phòng học đó** (giải phóng session, đóng trạng thái trên Backend để Dashboard trống hoàn toàn).

---

## Ideas Explored

1. **Option A: Chỉ xóa session ở Dashboard:** Khi bấm Bắt đầu thì force kill session cũ, nhưng giữ nguyên nút Hủy ở Lobby chỉ pop màn hình. (Dismissed: Khiến Dashboard vẫn hiện phòng dở dang khi người dùng đã bấm Hủy ở Lobby).
2. **Option B: Tự động hủy phòng tại Lobby + Reset triệt để WebView sinh link mới (Selected):**
   - Khi bấm "HỦY / QUAY LẠI DASHBOARD" (hoặc nút Back AppBar) ở Lobby: Gọi Backend hủy/đóng phòng active ngay lập tức, gọi `leaveClassroom()`, đưa Dashboard về trạng thái trống hoàn toàn.
   - Khi bấm "Bắt đầu" ở Dashboard: Luôn đóng phòng cũ (nếu có), reset `_meetingUrl = null`, điều hướng WebView2 vào `https://meet.google.com/new` để luôn nhận về 1 mã phòng mới.
   - Fallback tự sinh tại Lobby: Nếu vào Lobby mà chưa có link (`_currentMeetingUrl == null`), Lobby tự động kích hoạt tạo link mới ngầm ngay lập tức.

---

## User's Direction

- Bấm **"Bắt đầu"** luôn tự động tạo 1 link Meet mới 100%.
- Bấm **"HỦY / QUAY LẠI DASHBOARD"** ở Lobby thì hủy hẳn phòng: Xóa session, đóng trạng thái trên Backend để Dashboard trở về trạng thái trống hoàn toàn.

---

## Key Areas to Refactor

1. **MeetAutomationService (`meet_automation_service.dart`):**
   - Trong `generateAndJoinRealMeetRoom()`: Luôn gán `_meetingUrl = null` trước khi load `https://meet.google.com/new`.
   - Reset URL subscription để không nhận lại URL cũ từ bộ nhớ đệm WebView.
2. **ClassroomLobbyScreen (`classroom_lobby_screen.dart`):**
   - Bổ sung hàm `_handleCancelLobby()`: Gọi `localService.endClassroom()` và `_meetService.leaveClassroom()` trước khi `Navigator.pop()`.
   - Gán `_handleCancelLobby()` cho cả nút "HỦY / QUAY LẠI DASHBOARD" lẫn nút Back trên AppBar `LobbyHeader`.
   - Trong `initState()`: Nếu không có `_currentMeetingUrl`, tự động gọi `_handleGenerateNewMeetRoom()` để đảm bảo phòng luôn có link thật.
3. **ClassroomDashboardScreen (`classroom_dashboard_screen.dart`):**
   - Đảm bảo khi bấm "Bắt đầu", `_startClassroom` tự động dọn session cũ và khởi tạo link mới 100%.

---

## Risks & Mitigations

- **Rủi ro:** Gọi API backend `endClassroom` khi hủy ở Lobby có thể chậm nếu mạng lag.
  - *Giải pháp:* Chạy `endClassroom` song song hoặc hiển thị loading nhẹ trong tích tắc, sau đó pop ngay lập tức.
- **Rủi ro:** Google Meet mở tab mới hoặc load chậm hơn timeout.
  - *Giải pháp:* Tăng nhẹ timeout và tiêm script tự động nhận diện mã phòng `xxx-yyyy-zzz` ngay khi URL thay đổi.
