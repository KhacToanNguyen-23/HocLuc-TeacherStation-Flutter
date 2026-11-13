# Phase 4: Đóng Gói .hlep, Chạy Test Suite & Kiểm Thử Kiến Trúc

**Files:** `scripts/plugins/validate-plugin-packages.mjs`, `scripts/checks/run-architecture-check.mjs`, `scripts/tests/math-studio/test-app-logic.mjs`
**Stories Covered:** All success criteria

### Tasks:
1. Chạy test mô phỏng SVG và hàm số: `node scripts/tests/math-studio/test-app-logic.mjs`.
2. Đóng gói plugin và auto-fix file `.hlep`: `node scripts/plugins/validate-plugin-packages.mjs --fix`.
3. Kiểm tra 12 Bất biến kiến trúc: `node scripts/checks/run-architecture-check.mjs` (yêu cầu đạt 12/12 PASS).

