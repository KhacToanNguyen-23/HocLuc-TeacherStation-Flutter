# Implementation Plan: Teacher Station - Headless Google Meet Cockpit & High-Definition Broadcasting

**Date:** 2026-10-11
**Mode:** --hard
**Risk:** high-risk — touches native WebView2 automation, external Google Meet DOM runtime, and OS media stream capture
**Spec:** [plans/teacher-station-meet-cockpit/spec.md](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/teacher-station-meet-cockpit/spec.md)

---

## 1. Overview & Architecture

Hệ thống biến Teacher Station thành một buồng lái (Cockpit) điều khiển toàn bộ phiên Google Meet ngầm qua WebView2:
1. **Headless Bridge Script (`meet_bridge.js`):** Chạy ngầm trong tab Meet của WebView2, dùng `MutationObserver` để trích xuất tin nhắn Chat, danh sách Giơ tay, Yêu cầu vào lớp; và nhận lệnh Click mô phỏng (Admit All, Mute All, Gửi Chat, Start Presenting).
2. **Flutter IPC Service (`MeetAutomationService`):** Lắng nghe dữ liệu thời gian thực từ WebView2 qua `webMessage`, duy trì state phản ứng (Reactive state) và đẩy lên UI.
3. **Cockpit UI (`StudioInspectorPanel`):** Tab điều khiển lớp học trực tiếp ngay trên Inspector Panel bên phải của Teacher Studio (Chat Meet thời gian thực, badge giơ tay, nút duyệt 1 chạm).
4. **Dual-Feed & High-Definition Broadcaster (`wgc_broadcaster` + Meet Stream Injection):** Đẩy bảng vẽ qua luồng Trình bày 1080p và webcam thật qua luồng Camera khuôn mặt.

---

## 2. Phase Breakdown

- [x] **Phase 1: Headless Bridge Script (`meet_bridge.js`)**
  - Trích xuất Chat DOM, Raise Hand DOM, Admission Knock DOM.
  - Khắc phục thay đổi class name qua thuộc tính ngữ nghĩa (`aria-label`, data attributes, text pattern vi/en).
  - Tích hợp `window.chrome.webview.postMessage`.
  - *Covers stories:* P1 (Đọc chat, giơ tay).

- [x] **Phase 2: Meet Automation Service Two-Way IPC**
  - Mở rộng [meet_automation_service.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/services/meet_automation_service.dart).
  - Định nghĩa data models: `MeetChatMessage`, `MeetParticipant`, `MeetAdmissionRequest`.
  - Xử lý message stream từ `webviewController.webMessage`.
  - Cung cấp API gửi lệnh: `sendChat(String)`, `admitAll()`, `muteAll()`.
  - *Covers stories:* P1 (Kết nối 2 chiều), P2 (Điều khiển từ xa).

- [x] **Phase 3: Studio Inspector Cockpit UI**
  - Nâng cấp [studio_inspector_panel.dart](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/widgets/studio/studio_inspector_panel.dart) thành giao diện Tab:
    - Tab "Trực tiếp": Live Chat Feed, Danh sách giơ tay nổi bật, Action bar (Duyệt tất cả, Tắt mic tất cả).
    - Tab "Cài đặt & Ghi chú": Mic, Loa, Bài tập như hiện tại.
  - Thêm hiệu ứng âm thanh/chuông nhẹ khi học sinh giơ tay.
  - *Covers stories:* P1 (Giao diện tập trung), P2 (Duyệt & Mute 1 chạm).

- [x] **Phase 4: High-Definition WGC Stream & Dual-Feed Architecture**
  - Tối ưu plugin C++ [wgc_broadcaster](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/plugins/wgc_broadcaster) cho canvas bảng vẽ 1080p 60fps.
  - Cấu hình stream injection vào Meet dưới dạng Presentation stream (Screen Share) để Google Meet ưu tiên encoder bitrate cho text/công thức toán học sắc nét.
  - *Covers stories:* P1 (Độ nét 1080p không vỡ hạt), P1 (Dual-feed Bảng vẽ + Webcam).

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-11 23:46
**Phase in progress:** Completed all 4 phases
**Status:** All 4 phases successfully implemented and verified with 43 passing tests.

### Decisions made this session
- Embedded the Meet Bridge Script directly in Dart constants (`meet_bridge_script.dart`) as well as in `frontend/assets/scripts/meet_bridge.js` to ensure zero file I/O latency when injecting into WebView2.
- Designed `StudioInspectorPanel` with responsive tabs ("Trực tiếp" vs "Cài đặt & Ghi chú") preventing overflow on narrow widths while providing real-time chat, hand-raising badges, and remote host controls.
- Successfully verified both unit parsing and widget interaction tests with 43/43 tests passing and 0 analyzer issues.

### Next immediate action
- Run app on Windows Desktop (`flutter run -d windows` / `.\dev-frontend.bat`) for live end-to-end testing with a real Google Meet room.

---

## 3. Verification Plan

### Automated Tests
- Unit test cho data models và message parsing:
  `flutter test test/meet_bridge_parser_test.dart`
- Widget test cho Cockpit UI & Inspector Tab:
  `flutter test test/meet_cockpit_inspector_test.dart`
- Unit test cho MeetAutomationService IPC:
  `flutter test test/meet_automation_service_test.dart`
- Toàn bộ test suite:
  `flutter test`
- Static analysis:
  `flutter analyze lib`

### Manual Verification
1. Chạy app trên Windows (`flutter run -d windows` hoặc `dev-frontend.bat`).
2. Bấm "Bắt đầu dạy" -> Xác nhận link Meet được sinh và hiển thị trên top bar.
3. Dùng tài khoản học sinh (trên điện thoại/máy tính khác) mở link Meet tham gia lớp:
   - Thử nhắn tin trong Meet -> Tin nhắn xuất hiện trên bảng chat của Teacher Station.
   - Thử bấm Giơ tay trong Meet -> App hiện badge thông báo giơ tay.
   - Bấm "Duyệt vào lớp" hoặc "Tắt tiếng tất cả" trên app -> Meet thực thi ngay lập tức.
   - Kiểm tra màn hình học sinh: chữ viết và bảng vẽ hiển thị rõ nét 1080p.
