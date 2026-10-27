# Phase 4: Kiểm thử Toàn diện, Đóng gói Plugin & CI Architecture Gate

**Goal:** Chạy kiểm thử toàn diện mọi bất biến kiến trúc, kiểm tra độ mượt, đóng gói `.hlep` và xác minh CI.

---

## Detailed Tasks

1. **Đóng gói plugin:**
   - Cập nhật phiên bản manifest lên `v2.0.0` (NoteRenderer UI/UX Edition).
   - Đóng gói: `node scripts/package_plugin.mjs math_studio`.
   - Kiểm tra linter plugin: `node scripts/validate_plugins.mjs`.

2. **Chạy bộ kiểm thử tự động:**
   - Chạy test JavaScript: `node scripts/test_math_studio.mjs`, `node scripts/test_revolution_solid.mjs`.
   - Chạy test widget Flutter: `flutter test test/features/studio_board/board_sticker_test.dart`.
   - Chạy Architecture Gate: `flutter test test/architecture_test.dart` (12/12 Invariants PASS).
   - Chạy Flutter static analyzer: `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

3. **Xác nhận tiêu chuẩn phòng học:**
   - Bộ nhớ RAM tiêu thụ $\le 15$ MB cho đối tượng đồ thị.
   - 60 fps mượt mà khi di chuyển, xoay hoặc co giãn trên mọi màn hình cảm ứng.

