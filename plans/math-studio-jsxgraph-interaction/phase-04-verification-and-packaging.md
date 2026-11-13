# Phase 4: Kiểm Thử, Đóng Gói .hlep & Kiểm Tra Bất Biến Kiến Trúc

## Goal
Kiểm tra toàn bộ test suites, đóng gói `.hlep` và kiểm tra 12 bất biến kiến trúc.

## Requirements
1. Chạy 5 test suites logic:
   - `node scripts/tests/math-studio/test-app-logic.mjs`
   - `node scripts/tests/math-studio/test-curve-manipulator.mjs`
   - `node scripts/tests/math-studio/test-geometry-3d.mjs`
   - `node scripts/tests/math-studio/test-math-studio.mjs`
   - `node scripts/tests/math-studio/test-revolution-solid.mjs`
2. Đóng gói plugin và kiểm tra Schema v2.1:
   - `node scripts/plugins/validate-plugin-packages.mjs --fix`
3. Kiểm tra 12 Bất biến kiến trúc:
   - `node scripts/checks/run-architecture-check.mjs`

## Success Criteria
- 100% test suites logic PASS.
- `plugins/math_studio.hlep` đồng bộ tuyệt đối.
- 12/12 Invariants PASS.

