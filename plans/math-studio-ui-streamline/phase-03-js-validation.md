# Phase 3: JS Toggle, Đóng gói .hlep & Kiểm thử

**Files:** `plugins/math_studio/ui/app.js`, `scripts/plugins/validate-plugin-packages.mjs`
**Stories Covered:** P1, P2

### Tasks:
1. Trong `plugins/math_studio/ui/app.js`:
   - Bắt sự kiện `#btnToggleAdvanced`: toggle class `open` và `hidden`.
2. Kiểm thử tương tác trực tiếp:
   - Thao tác kéo nắn cực trị, thêm hàm số, quay khối tròn xoay.
3. Đóng gói và chạy các kiểm tra kiến trúc bắt buộc:
   - `node scripts/plugins/validate-plugin-packages.mjs --fix`
   - `node scripts/checks/run-architecture-check.mjs`
   - `node scripts/tests/math-studio/test-app-logic.mjs`

