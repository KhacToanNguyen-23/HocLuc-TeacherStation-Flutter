# Phase 5: Kiểm Thử, Đóng Gói .hlep & Bất Biến Kiến Trúc

## Goal
Chạy toàn bộ test suites, kiểm tra 12 bất biến kiến trúc và đóng gói `plugins/math_studio.hlep`.

## Requirements
1. Chạy `node scripts/tests/math-studio/test-app-logic.mjs` - Pass 100%.
2. Chạy `node scripts/tests/math-studio/test-curve-manipulator.mjs` - Pass 100%.
3. Chạy `node scripts/tests/math-studio/test-geometry-3d.mjs` - Pass 100%.
4. Đóng gói plugin và xác thực tính đồng bộ: `node scripts/plugins/validate-plugin-packages.mjs --fix` - 3/3 plugins valid.
5. Kiểm tra 12 Bất biến kiến trúc: `node scripts/checks/run-architecture-check.mjs` - 12/12 Invariants PASS.

## Success Criteria
- 0 lỗi phân tích (0 errors, 0 warnings).
- `math_studio.hlep` đồng bộ tuyệt đối với mã nguồn.
- Đầy đủ evidence báo cáo.

