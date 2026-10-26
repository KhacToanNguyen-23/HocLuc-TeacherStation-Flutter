# Phase 4: Kiểm Thử Toàn Diện, Đóng Gói Plugin .hlep & Architecture Gate

## Goal
Xác minh toàn bộ các bất biến kiến trúc của hệ thống, cập nhật bộ widget tests cho cơ chế Canva selection state và 8 chốt transform, đóng gói file `plugins/math_studio.hlep` phiên bản 2.1.0 và đảm bảo CI gate vượt qua 100%.

## Target Files
- `frontend/test/features/studio_board/board_sticker_test.dart`
- `scripts/validate_plugins.mjs`
- `scripts/run_architecture_check.mjs`
- `plugins/math_studio.hlep`

## Detailed Implementation Steps
1. **Cập nhật Widget Tests trong board_sticker_test.dart:**
   - Test kiểm tra trạng thái Deselected: sticker chỉ render nội dung SVG, không hiển thị transform handles hay floating bar.
   - Test kiểm tra trạng thái Selected: hiển thị đầy đủ 8 chốt kéo, cuống xoay và thanh Floating Action Bar.
   - Test kiểm tra tương tác tap các nút hành động `Sửa`, `Phát quay`, `Nhân bản`, `Xóa`.
2. **Đóng gói Plugin:**
   - Chạy `node scripts/package_plugin.mjs math_studio` để sinh gói `plugins/math_studio.hlep` v2.1.0 mới nhất.
3. **Chạy toàn bộ Verification Gates:**
   - `node scripts/validate_plugins.mjs` $\rightarrow$ 3/3 plugins valid, 100% in sync.
   - `node scripts/run_architecture_check.mjs` $\rightarrow$ 12/12 Invariants PASS.
   - Chạy các test đại số và hình học: `test_math_studio.mjs`, `test_curve_manipulator.mjs`, `test_geometry_3d.mjs`, `test_revolution_solid.mjs`.

## Acceptance Criteria
- [ ] `board_sticker_test.dart` đạt 100% PASS.
- [ ] Gói `plugins/math_studio.hlep` được đóng gói đồng bộ phiên bản 2.1.0.
- [ ] 12/12 Invariant Architecture Gate PASS.
- [ ] 0 lỗi analyzer, 0 lỗi cú pháp.

