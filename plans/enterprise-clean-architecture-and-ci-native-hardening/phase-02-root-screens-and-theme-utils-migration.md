# Phase 02: Di dời Screens về Feature Presentation

## Mục tiêu
Loại bỏ hoàn toàn thư mục `lib/screens/` tại root, đưa 100% màn hình vào đúng `lib/features/<module>/presentation/screens/`.

## Các công việc cụ thể
1. **Di dời Screens vào Presentation Layer của Module:**
   - Tạo thư mục `screens/` bên trong `lib/features/<module>/presentation/`.
   - `lib/screens/login_screen.dart` ➔ `lib/features/auth/presentation/screens/login_screen.dart`
   - `lib/screens/classroom_dashboard_screen.dart`, `classroom_dashboard_rooms_and_history.dart`, `classroom_lobby_screen.dart`, `google_workspace_screen.dart` ➔ `lib/features/classroom_meet/presentation/screens/`
   - `lib/screens/studio_screen.dart`, `studio_screen_actions.dart` ➔ `lib/features/studio_board/presentation/screens/`
   - `lib/screens/exams/exam_paper_editor.dart`, `exam_workspace_screen.dart`, `question_review_dialog.dart` ➔ `lib/features/exams/presentation/screens/`
2. **Cập nhật Canonical Imports:**
   - Cập nhật `main.dart` import các màn hình từ `package:teaching_companion/features/.../presentation/screens/...`.
   - Cập nhật tất cả các màn hình gọi chuyển trang (Navigator / Router).
   - Cập nhật tất cả các file test trong `test/features/`.
3. **Xóa sổ thư mục `lib/screens/`:**
   - Xóa bỏ hoàn toàn thư mục `lib/screens/`.
   - Xác nhận `lib/` lúc này CHỈ CÒN `main.dart`, `core/`, `features/`.

## Tiêu chí hoàn thành (Verification)
- Thư mục `lib/screens/` hoàn toàn biến mất.
- `flutter test` (395/395 tests PASS).

