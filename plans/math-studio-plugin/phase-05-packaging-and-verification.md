# Phase 5: Packaging, Validation & Architecture Verification Gate

**Plan:** [plan.md](plan.md)  
**Spec Stories:** All P1 Stories | **Requirements:** SC-01 $\to$ SC-07, CI verification

---

## 1. Mục Tiêu Phase 5
- Đóng gói toàn bộ mã nguồn plugin `plugins/math_studio/` thành tệp `plugins/math_studio.hlep`:
  - Thực thi lệnh: `node scripts/package_plugin.mjs math_studio`.
  - Kiểm tra file `.hlep` được tạo ra với chuẩn ZIP nén Store 0, dung lượng $< 200$ KB.
- Chạy công cụ kiểm định plugin:
  - `node scripts/validate_plugins.mjs`.
  - Đảm bảo 0 lỗi schema, 0 cảnh báo, độ tươi (freshness) đạt 100%.
- Kiểm thử toàn diện phía Host Flutter:
  - Cập nhật và bổ sung widget test cho Generic Sticker (`test/features/studio_board/board_sticker_test.dart`).
  - Kiểm tra cổng kiến trúc: `flutter test test/architecture_test.dart` (đảm bảo 12/12 Invariants PASS, bao gồm kiểm tra tính toàn vẹn của tệp `.hlep` và Zero Hardcoded Names).
  - Phân tích mã nguồn: `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).

---

## 2. Tiêu Chí Nghiệm Thu (Acceptance Criteria)
- [ ] Lệnh `node scripts/package_plugin.mjs math_studio` kết thúc thành công với mã thoát 0.
- [ ] Lệnh `node scripts/validate_plugins.mjs` báo cáo 0 lỗi.
- [ ] `flutter test test/architecture_test.dart` đạt 12/12 invariants PASS.
- [ ] `flutter analyze --no-fatal-infos` đạt 0 issues.
- [ ] Toàn bộ bộ test frontend `flutter test` vượt qua 100%.
