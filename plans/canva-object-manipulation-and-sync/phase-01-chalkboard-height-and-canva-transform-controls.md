# Phase 1: Chalkboard Height Fix & Canva Transform Controls

## 1. Goal
Sửa lỗi thiếu thuộc tính `height:` trên `Positioned` của Bảng phấn và hoàn thiện bộ thao tác **Transform Controls** chuẩn Canva trên `BoardStickerCard`:
1. **Resize / Scale (Phóng to / thu nhỏ đồng dạng):** Kéo 4 chốt góc vuông giữ nguyên tỉ lệ khung hình (Aspect Ratio Lock).
2. **Stretch / Resize (Kéo dãn 1 chiều):** Kéo 4 chốt cạnh độc lập (trái/phải dãn width, trên/dưới dãn height).
3. **Rotate (Xoay đối tượng):** Chốt xoay trên đỉnh với góc cực $\theta = \text{atan2}(dy, dx) - \text{initialAngle}$.
4. **Move / Drag (Di chuyển đối tượng):** Kéo rê trên thân đối tượng di chuyển mượt mà trên mặt bảng.
5. **Nội dung SVG/Ảnh:** Co dãn vừa vặn theo khung bao (BoxFit.contain trên toàn bộ diện tích).

## 2. Changes
- `frontend/lib/features/studio_board/presentation/interactive_chalkboard.dart`:
  - Thêm `height: (s.normalizedRect.height * size.height).clamp(120.0, size.height > 120 ? size.height : 120.0)`.
- `frontend/lib/features/studio_board/presentation/board_sticker_card.dart`:
  - Nâng cấp `_handleCornerResize`: tính tỉ lệ $w/h$, tính $\Delta$ kéo theo hướng góc, điều chỉnh cả $w$ và $h$ đồng dạng.
  - Tối ưu `_handleEdgeResize`: cho phép co dãn cạnh trên, dưới, trái, phải chính xác, giới hạn tối thiểu 0.05.
  - Nâng cấp Rotation: tính góc từ tâm thẻ card bằng `atan2`.
  - Tối ưu `_buildContent()`: khi card có height xác định từ `Positioned`, cho phép container mở rộng (`Expanded` hoặc `height: double.infinity`) để SVG hiển thị tối đa kích thước.

