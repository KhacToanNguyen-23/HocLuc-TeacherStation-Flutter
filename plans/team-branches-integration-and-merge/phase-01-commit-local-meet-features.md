# Phase 01: Đóng gói và Commit tính năng Local

## Mục tiêu
Tạo commit chuẩn cho toàn bộ các thay đổi chưa commit trên nhánh `develop` cục bộ liên quan đến:
1. Zero-Click Google Meet Automation (`meet_automation_service.dart`, `meet_bridge_script.dart`).
2. In-App Student Admission Drawer & Banner (`studio_students_drawer.dart`, `studio_admission_banner.dart`).
3. WebView Environment Persistence (`webview_environment_service.dart`).
4. Cập nhật Lobby & TopBar (`classroom_lobby_screen.dart`, `studio_top_bar.dart`, `lobby_meet_room_card.dart`).

## Các bước thực hiện
1. Kiểm tra trạng thái: `git status -s`.
2. Chạy test baseline:
   ```powershell
   flutter test test/meet_automation_service_test.dart test/meet_bridge_parser_test.dart test/classroom_lobby_screen_test.dart test/studio_admission_banner_test.dart test/studio_students_drawer_test.dart test/webview_environment_service_test.dart
   ```
3. Stage và commit:
   ```powershell
   git add frontend/ plans/ feature_list.json
   git commit -m "feat(meet): implement zero-click meet automation and in-app student admission drawer"
   ```
4. Verification:
   - `git status` trả về clean working tree.
