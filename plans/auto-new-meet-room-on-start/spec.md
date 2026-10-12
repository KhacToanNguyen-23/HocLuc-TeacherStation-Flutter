# Spec: Auto Sinh Link Google Meet Mới Khi Bắt Đầu & Hủy Triệt Để Phòng Tại Lobby

**Date:** 2026-10-12
**Status:** Approved

---

## Problem Statement

Hiện tại khi giáo viên hủy phòng tại màn hình Lobby (bằng nút Hủy hoặc nút Back), phòng học vẫn tồn tại ở trạng thái `ONGOING` trên backend và session trong `MeetAutomationService` không được dọn sạch. Do đó khi quay lại bấm "Bắt đầu", hệ thống không tự động cấp ra một link Google Meet mới 100%. Giáo viên muốn: bấm "Bắt đầu" là tự động sinh 1 link mới, và bấm "Hủy" ở Lobby là hủy sạch phòng.

---

## User Stories

- **[P1]** As a giáo viên, I want khi bấm nút "Bắt đầu" trên Dashboard, hệ thống luôn tự động tạo một phòng Google Meet mới 100% với mã phòng độc lập, so that tôi luôn có một lớp học mới sẵn sàng cho học sinh.
  Accepted when: Bấm "Bắt đầu" luôn kích hoạt tạo phòng Google Meet mới thật và đưa link mới vào Lobby.

- **[P1]** As a giáo viên, I want khi bấm "HỦY / QUAY LẠI DASHBOARD" hoặc nút Back tại Lobby, phòng học vừa tạo sẽ bị hủy triệt để và giải phóng hoàn toàn, so that Dashboard của tôi trở về trạng thái trống (không bị kẹt phòng cũ đang diễn ra).
  Accepted when: Bấm Hủy tại Lobby gọi backend kết thúc/hủy phòng, đóng session WebView Meet, và quay về Dashboard với danh sách phòng trống.

- **[P1]** As a giáo viên, I want nếu màn hình Lobby mở lên mà chưa có link, Lobby tự động kích hoạt tiến trình tạo link mới ngầm, so that tôi không bao giờ rơi vào trạng thái "Chưa có link" vô vọng.
  Accepted when: `ClassroomLobbyScreen` tự động gọi `_handleGenerateNewMeetRoom()` nếu `_currentMeetingUrl` ban đầu là null.

- **[P2]** As a lập trình viên, I want bộ test `flutter test` tiếp tục pass 100% (45/45).
  Accepted when: Lệnh `flutter test` pass thành công.

---

## Functional Requirements

1. **FR-01 (MeetAutomationService URL Reset):**
   - Trước khi gọi `controller.loadUrl('https://meet.google.com/new')`, gán `_meetingUrl = null` và hủy subscription cũ.
   - Khi WebView điều hướng đến URL có dạng `meet.google.com/xxx-yyyy-zzz`, chỉ chấp nhận nếu đó là link Meet hợp lệ mới.
2. **FR-02 (Hủy phòng triệt để tại ClassroomLobbyScreen):**
   - Nút "HỦY / QUAY LẠI DASHBOARD" và nút Back của AppBar gọi `_handleCancelLobby()`.
   - `_handleCancelLobby()`:
     - Gọi `LocalService().endClassroom()` để đổi trạng thái phòng trên backend sang `COMPLETED` (hoặc giải phóng phòng).
     - Gọi `MeetAutomationService().leaveClassroom()` để reset WebView về `about:blank` và hủy session.
     - `Navigator.of(context).pop()`.
3. **FR-03 (Auto-generate Fallback trong Lobby):**
   - Trong `ClassroomLobbyScreen.initState()`, nếu `_currentMeetingUrl == null`:
     - Chạy `_handleGenerateNewMeetRoom()` sau frame đầu tiên để tự động sinh link Meet mới ngầm.
4. **FR-04 (Dashboard Clean Start):**
   - Khi bấm "Bắt đầu": Luôn dọn dẹp phòng cũ nếu có và tạo link mới 100%.

---

## Non-Functional Requirements

- **Response Time:** Thao tác Hủy tại Lobby diễn ra nhanh, không bị đơ UI.
- **Reliability:** 100% test suite `flutter test` pass.

---

## Success Criteria

- [ ] Bấm "Bắt đầu" từ Dashboard luôn tạo ra link Google Meet mới.
- [ ] Bấm "HỦY" tại Lobby lập tức giải phóng phòng học, quay về Dashboard thấy thẻ "Phòng học" ở trạng thái "Chưa có phòng học".
- [ ] `flutter test` pass 45/45.
