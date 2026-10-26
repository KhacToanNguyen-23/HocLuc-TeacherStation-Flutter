# Phase 4: Verification Tests & Architecture Gate

## 1. Goal
Xác nhận toàn bộ hệ thống hoạt động chính xác, pass 100% các bài test và không vi phạm bất biến kiến trúc (AGENTS.md).

## 2. Tasks
1. Chạy bài kiểm thử logic ứng dụng:
   - `node scripts/test_app_logic.mjs`
   - `node scripts/test_math_studio.mjs`
   - `node scripts/test_curve_manipulator.mjs`
   - `node scripts/test_geometry_3d.mjs`
   - `node scripts/test_revolution_solid.mjs`
2. Chạy đóng gói và kiểm tra plugin:
   - `node scripts/validate_plugins.mjs --fix` (xác nhận 3/3 plugins valid, archive `plugins/math_studio.hlep` cập nhật mới nhất).
3. Chạy kiểm tra bất biến kiến trúc:
   - `node scripts/run_architecture_check.mjs` (xác nhận 12/12 Invariants PASS, 0 errors).

