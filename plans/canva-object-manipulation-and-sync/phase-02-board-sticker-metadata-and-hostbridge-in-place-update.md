# Phase 2: BoardSticker Metadata & HostBridge In-Place Update

## 1. Goal
Hỗ trợ lưu trữ tham số gốc của plugin trong `BoardSticker` và cho phép HostBridge cập nhật đè nội dung lên sticker đang có thay vì tạo sticker mới trùng lặp:
1. `BoardSticker` có trường `metadata: Map<String, dynamic>?` (chứa `formula`, `bounds`, `theme`, `view`, `a`, `b`, ...).
2. `StudioState` / `CanvasDrawingController` cung cấp hàm `updateSticker(BoardSticker updated)` để thay thế nội dung sticker cùng `id`.
3. `HostBridge._handleInsertAnnotation`:
   - Nếu `payload['stickerId']` hoặc `innerData['stickerId']` trùng với sticker hiện có trên trang: Cập nhật đè `title`, `svgContent`, `imageBase64`, `rawText`, `metadata` của sticker đó.
   - Giữ nguyên toạ độ `normalizedRect` và góc xoay `rotation` hiện tại của sticker trên bảng phấn.
   - Nếu không có `stickerId`: Thêm mới như bình thường và lưu `metadata`.

## 2. Changes
- `frontend/lib/features/studio_board/domain/models/board_sticker.dart`:
  - Thêm `final Map<String, dynamic>? metadata;`
  - Cập nhật `copyWith`, `toJson`, `fromJson`.
- `frontend/lib/features/studio_board/services/controllers/canvas_drawing_controller.dart`:
  - Thêm phương thức `updateSticker(BoardSticker updated)`.
- `frontend/lib/features/studio_board/domain/models/studio_state.dart`:
  - Expose `updateSticker(BoardSticker updated)` thông qua coordinator.
- `frontend/lib/features/plugin_engine/services/host_bridge.dart`:
  - Trong `_handleInsertAnnotation`, kiểm tra `stickerId`. Nếu tìm thấy `s.id == stickerId`, gọi `studio.updateSticker` đè nội dung, không gọi `studio.addSticker`.

