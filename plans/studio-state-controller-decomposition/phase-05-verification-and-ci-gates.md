# Phase 5: Kiểm định toàn diện, Profiling & Chốt chặn CI Invariants

## Mục tiêu
Chạy toàn bộ các chốt chặn kiểm thử, xác nhận không còn vi phạm kiến trúc, đảm bảo `flutter analyze` và `architecture_test.dart` đạt 100% không cảnh báo.

## Nhiệm vụ cụ thể
- [x] Chạy linter toàn diện:
  - `flutter analyze --no-fatal-infos` (yêu cầu: 0 errors, 0 warnings).
- [x] Chạy chốt chặn 12 bất biến kiến trúc:
  - `flutter test test/architecture_test.dart` (xác nhận pass 12/12 invariants, không còn file vượt quá 900 dòng, không còn chuỗi hardcode).
- [x] Chạy toàn bộ test suite frontend:
  - `flutter test` (xác nhận toàn bộ test suite pass 100%, 413/413 tests).
- [x] Kiểm tra tính toàn vẹn của Plugin ecosystem:
  - `node scripts/validate_plugins.mjs` (0 errors, 0 warnings, 100% synced).
- [x] Cập nhật tài liệu kỹ thuật và sơ đồ kiến trúc mới trong `docs/architecture/` nếu cần.

## Tiêu chí chấp nhận
- 12/12 Invariants trong `architecture_test.dart` đạt PASS.
- 0 analyzer warnings/errors.
- Toàn bộ test suite frontend chạy thông suốt.
