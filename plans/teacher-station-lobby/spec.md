# Spec: Trang Sảnh Giáo Viên (Teacher Lobby) & Chuyển Hướng Vào Lớp

**Date:** 2026-10-10
**Status:** Approved

---

## Problem Statement
Giáo viên cần một màn hình sảnh đón tiếp (Lobby) khi vừa mở ứng dụng để chuẩn bị tâm thế, cho phép bấm 1 nút là tự động kích hoạt phòng học Google Meet và chuyển thẳng vào không gian Bảng vẽ (Whiteboard Studio) mà không phải qua nhiều bước trung gian.

---

## User Stories

- **[P1]** As a Giáo viên, I want to thấy Trang Sảnh khi vừa mở ứng dụng so that tôi có không gian khởi đầu trước khi bước vào giảng dạy.
  Accepted when: Khởi động app hiển thị `TeacherLobbyScreen` thay vì đưa thẳng vào bảng vẽ.

- **[P1]** As a Giáo viên, I want to bấm nút "Tạo lớp học mới" tại Sảnh so that hệ thống tự động khởi tạo Meet ngầm và chuyển thẳng tôi vào trang Bảng vẽ.
  Accepted when: Bấm nút ở Sảnh kích hoạt `createClassroom()` và tự động điều hướng sang `StudioScreen`.

- **[P1]** As a Giáo viên, I want to có thể bấm "Rời phòng / Đóng lớp" trên Bảng vẽ so that tôi kết thúc buổi dạy và quay trở về lại Trang Sảnh.
  Accepted when: Bấm nút thoát lớp trên Bảng vẽ đóng stream, reset phòng và điều hướng về `TeacherLobbyScreen`.

---

## Functional Requirements

1. FR-01: Tạo màn hình `TeacherLobbyScreen` (`frontend/lib/screens/lobby_screen.dart`):
   - Header: Tên trạm phát sóng Mộc, avatar/lời chào Thầy/Cô.
   - Hero Action Card: Nút lớn `[ 🚀 Tạo lớp & Vào dạy ngay ]`.
   - Card danh sách bài giảng gần đây (Recent lessons).
2. FR-02: Cập nhật route khởi đầu của `MaterialApp` trong `main.dart` trỏ về `TeacherLobbyScreen`.
3. FR-03: Khi bấm tạo lớp tại Sảnh: gọi `MeetAutomationService.createClassroom()`, đồng thời dùng `Navigator.push` chuyển sang `StudioScreen`.
4. FR-04: Nút "Đóng lớp" trên `BroadcastControlBar` của `StudioScreen`: gọi `leaveClassroom()` và `Navigator.pop(context)` để quay lại Trang Sảnh.

---

## Success Criteria

- [ ] Zero-Barrier Entry: 1-Click từ Sảnh chuyển thẳng vào Bảng vẽ với Meet đã kết nối ngầm.
- [ ] Safe Return: Rời lớp học giải phóng tài nguyên và trở về Trang Sảnh nguyên vẹn.

---

## Out of Scope
- Xác thực tài khoản / Login Auth API trong phase này.
