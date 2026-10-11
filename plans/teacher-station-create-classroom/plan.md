# Plan: UI Tạo Lớp Học & Quản Lý Phát Sóng (1-Click Classroom & Stream Control)

Mode: Fast
Risk: normal — UI components and service integration (CreateClassroomDialog, TopBar button, BroadcastControlBar stream switch)
Status: Completed

## Summary
Triển khai giao diện Tạo lớp học 1-Click:
1. Thêm nút `[ + Tạo lớp học ]` trên TopBar.
2. Dialog `CreateClassroomDialog` hiển thị link Meet vừa sinh ngầm kèm nút Copy.
3. Tách biệt việc tạo phòng Meet và phát sóng stream: Giáo viên vào lớp chuẩn bị xong, bấm `[ ▶ Bắt đầu dạy ]` thì mới bắt đầu stream màn hình bảng trắng.

## Phases
- [x] Phase 1: Tách biệt Service: `createMeetRoom()` vs `startBroadcasting()` trong `MeetAutomationService`.
- [x] Phase 2: Xây dựng widget `CreateClassroomDialog` (Link Google Meet, Copy button, Vào lớp).
- [x] Phase 3: Gắn nút `[ + Tạo lớp học ]` vào `studioTopBar` (`main.dart`).
- [x] Phase 4: Nâng cấp `BroadcastControlBar` với nút `[ ▶ Bắt đầu dạy ]` (Privacy-First Stream Toggle).
- [x] Phase 5: Kiểm tra toàn diện và verify với `flutter analyze`.
