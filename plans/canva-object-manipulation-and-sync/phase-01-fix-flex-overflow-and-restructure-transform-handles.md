# Phase 1: Fix Flex Overflow & Restructure Transform Handles with 28px Hit Area & Mouse Cursors

## 1. Goal
1. Sửa dứt điểm lỗi `BOTTOM OVERFLOWED BY 3.0 PIXELS` trên `BoardStickerCard`.
2. Tách biệt hoàn toàn `GestureDetector` thân thẻ và các chốt kéo trên `Stack`.
3. Mở rộng vùng bấm của chốt kéo lên 28px $\times$ 28px và thêm con trỏ chuột `SystemMouseCursors` tương ứng.
4. Hoàn thiện kéo 4 góc khóa tỷ lệ (Aspect Ratio Lock) và kéo 4 cạnh co dãn 1 chiều.

## 2. Changes
- `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`:
  - Trong `Container`, tính toán `contentH = (boxH - 3.0).clamp(0, double.infinity)` hoặc dùng `Expanded` để không bao giờ bị vượt quá chiều cao do viền 3px.
  - Tách thân card: `GestureDetector(behavior: HitTestBehavior.opaque, onPanUpdate: _handleCardMove)` bọc lấy phần nền thẻ.
  - Tách 8 chốt kéo và chốt xoay lên layer `Stack` phía trên cùng.
  - Nâng cấp `_buildCanvaHandle`:
    - Bọc trong `MouseRegion(cursor: cursor)`
    - Bọc trong `Container(width: 28, height: 28, color: Colors.transparent, alignment: Alignment.center)`
    - Bên trong là hình vuông chốt 9px màu trắng viền cam Catppuccin/Amber.

