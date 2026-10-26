# Phase 5: Kiểm Thử, Đóng Gói .hlep & Bất Biến Kiến Trúc

## Goal
Chạy toàn bộ test suites, kiểm tra 12 bất biến kiến trúc và đóng gói `plugins/math_studio.hlep`.

## Requirements
1. Chạy `node scripts/test_app_logic.mjs` - Pass 100%.
2. Chạy `node scripts/test_curve_manipulator.mjs` - Pass 100%.
3. Chạy `node scripts/test_geometry_3d.mjs` - Pass 100%.
4. Đóng gói plugin và xác thực tính đồng bộ: `node scripts/validate_plugins.mjs --fix` - 3/3 plugins valid.
5. Kiểm tra 12 Bất biến kiến trúc: `node scripts/run_architecture_check.mjs` - 12/12 Invariants PASS.

## Success Criteria
- 0 lỗi phân tích (0 errors, 0 warnings).
- `math_studio.hlep` đồng bộ tuyệt đối với mã nguồn.
- Đầy đủ evidence báo cáo.

