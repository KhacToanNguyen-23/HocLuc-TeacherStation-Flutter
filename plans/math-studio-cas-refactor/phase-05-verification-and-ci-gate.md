# Phase 5: Kiểm Thử Toàn Diện & Cổng Kiểm Soát Kiến Trúc (CI Gate)

## Context & Objectives
Đóng gói lại plugin `.hlep`, chạy toàn bộ các bài kiểm thử toán học, kiểm tra tính toàn vẹn của mã nguồn và xác thực 12/12 Invariants kiến trúc trong `AGENTS.md`.

## Scope of Work
1. Kiểm tra lại toàn bộ file trong `plugins/math_studio`:
   - Xác thực `manifest.json` chuẩn Schema v2.1.
   - Kiểm tra giới hạn dòng: Không file nào vượt quá 400 dòng.
   - Không có import chéo hoặc hardcode tên plugin trong `lib/`.
2. Chạy test suite:
   - `node scripts/test_symbolic_cas.mjs`: Test đạo hàm ký hiệu $y'$ và rút gọn biểu thức.
   - `node scripts/test_math_cas.mjs`: Test giải tích, cực trị, tiệm cận, tích phân.
   - `node scripts/test_curve_manipulator.mjs`: Test kéo nắn cực trị nghịch đảo.
   - `node scripts/test_app_logic.mjs`: Test luồng Store và xuất SVG.
3. Đóng gói plugin và chạy cổng kiểm soát kiến trúc:
   - `node scripts/validate_plugins.mjs --fix` (Tạo `plugins/math_studio.hlep` đồng bộ 100%).
   - `node scripts/run_architecture_check.mjs` (12/12 Invariants PASS).

## Verification Commands
- `node scripts/validate_plugins.mjs --fix`
- `node scripts/run_architecture_check.mjs`

