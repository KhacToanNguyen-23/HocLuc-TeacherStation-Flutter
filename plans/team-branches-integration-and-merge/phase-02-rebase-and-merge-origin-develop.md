# Phase 02: Đồng bộ origin/develop (Chứa PR #9 Soạn giáo án của Quốc Thái)

## Mục tiêu
Đưa commit của bạn lên trên đỉnh của `origin/develop` mới nhất (commit `7dab0ac`), nơi Quốc Thái đã tích hợp tính năng Soạn giáo án và tách thanh Studio TopBar.

## Các bước thực hiện
1. Thực hiện rebase:
   ```powershell
   git pull --rebase origin develop
   ```
2. Nếu có xung đột nhỏ ở `studio_top_bar.dart` hoặc `studio_screen.dart`:
   - Giữ cả logic `isPlanning` của Thái và `onOpenStudentsDrawer` của bạn.
   - Khi `isPlanning == true`: Ẩn nút học sinh, hiển thị badge "Chế độ soạn bài" và nút lưu giáo án.
   - Khi `isPlanning == false`: Hiển thị nút mở `StudioStudentsDrawer` với badge số học sinh chờ duyệt.
3. Chạy test xác nhận:
   ```powershell
   flutter test test/classroom_lobby_screen_test.dart test/studio_admission_banner_test.dart test/studio_students_drawer_test.dart
   ```
