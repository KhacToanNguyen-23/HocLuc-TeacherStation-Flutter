# Phase 4: Verification Tests & Architecture Gate

## 1. Goal
Xác nhận toàn bộ hệ thống hoạt động chính xác, pass 100% các bài test và không vi phạm bất biến kiến trúc (AGENTS.md).

## 2. Tasks
1. Chạy bài kiểm thử logic ứng dụng:
   - `node scripts/tests/math-studio/test-app-logic.mjs`
   - `node scripts/tests/math-studio/test-math-studio.mjs`
   - `node scripts/tests/math-studio/test-curve-manipulator.mjs`
   - `node scripts/tests/math-studio/test-geometry-3d.mjs`
   - `node scripts/tests/math-studio/test-revolution-solid.mjs`
2. Chạy đóng gói và kiểm tra plugin:
   - `node scripts/plugins/validate-plugin-packages.mjs --fix` (xác nhận 3/3 plugins valid, archive `plugins/math_studio.hlep` cập nhật mới nhất).
3. Chạy kiểm tra bất biến kiến trúc:
   - `node scripts/checks/run-architecture-check.mjs` (xác nhận 12/12 Invariants PASS, 0 errors).

