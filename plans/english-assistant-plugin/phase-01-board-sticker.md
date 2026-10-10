# Phase 01: BoardSticker Canvas Model, Rendering & Persistence

**Canonical Phase ID:** `phase-01-board-sticker`  
**Stories Covered:** P1 (Ghim lên bảng dưới dạng Sticker, Lưu trữ .hls)  
**Priority:** P1  

---

## Objective
Xây dựng mô hình dữ liệu `BoardSticker`, widget hiển thị thẻ trên `InteractiveChalkboard`, hỗ trợ kéo thả vị trí, xóa thẻ, và lưu trữ trạng thái thẻ vào file bài giảng `.hls` (JSON serialization trong `StudioState`).

---

## Scope & Implementation Tasks

1. **Tạo model `BoardSticker` (`frontend/lib/models/board_sticker.dart`):**
   - Thuộc tính:
     - `String id`: UUID hoặc timestamp định danh duy nhất.
     - `String type`: Loại thẻ (ví dụ: `'english_svo_card'`).
     - `Rect normalizedRect`: Vị trí và kích thước chuẩn hóa (`0.0..1.0` so với kích thước bảng).
     - `String rawText`: Câu văn gốc.
     - `List<Map<String, dynamic>> tokens`: Danh sách token `{text, role, pos, dep}`.
     - `List<String> issues`: Danh sách cảnh báo ngữ pháp từ LanguageTool.
   - Phương thức `toJson()` và `fromJson(Map<String, dynamic> json)`.

2. **Cập nhật `StudioState` (`frontend/lib/models/studio_state.dart`):**
   - Thêm `Map<int, List<BoardSticker>> _pageStickers = {};`
   - Getter `List<BoardSticker> get currentStickers => _pageStickers.putIfAbsent(page, () => []);`
   - Phương thức `addSticker(BoardSticker sticker)`: Thêm thẻ vào trang hiện tại, đánh dấu `dirty = true`, `notifyListeners()`.
   - Phương thức `removeSticker(String id)`: Xóa thẻ theo id.
   - Phương thức `updateStickerRect(String id, Rect newRect)`: Cập nhật vị trí khi kéo thả.
   - Cập nhật `save()` để lưu trữ `pageStickers` vào snapshot json `'stickers': ...`.

3. **Tạo widget `BoardStickerCard` (`frontend/lib/widgets/board_sticker_card.dart`):**
   - Hiển thị khối nhãn màu S-V-O đẹp mắt:
     - `[S] SUBJECT`: Màu xanh lam nhạt (`#89b4fa`).
     - `[V] VERB`: Màu hồng nhạt (`#f38ba8`).
     - `[O] OBJECT`: Màu cam đào (`#fab387`).
     - Khối lỗi ngữ pháp `⚠️ ...`
   - Header mini có icon pin `📌`, nút gỡ `[X]`.
   - Bọc trong `GestureDetector` / `Listener` để kéo thả (`onPanUpdate`) cập nhật `normalizedRect`.

4. **Tích hợp vào `InteractiveChalkboard` (`frontend/lib/widgets/interactive_chalkboard.dart`):**
   - Render danh sách `widget.studio.currentStickers` bên trong `Stack` của `InteractiveViewer`, quy đổi từ `normalizedRect` sang pixel thực tế theo `LayoutBuilder` kích thước bảng.

---

## Files Affected
- `frontend/lib/models/board_sticker.dart` (new)
- `frontend/lib/models/studio_state.dart`
- `frontend/lib/widgets/board_sticker_card.dart` (new)
- `frontend/lib/widgets/interactive_chalkboard.dart`
- `frontend/test/board_sticker_test.dart` (new)

---

## Dependencies
- Không phụ thuộc các phase khác. Là nền tảng hiển thị cho toàn bộ hệ thống sticker.

---

## Tests and Acceptance Criteria
- Chạy `flutter test test/board_sticker_test.dart`:
  - Tạo `BoardSticker`, serialize `toJson()` và deserialize `fromJson()` khớp 100%.
  - Thêm sticker vào `StudioState`, đổi trang khác không thấy, quay lại trang cũ thấy nguyên vẹn.
  - Kéo thả thẻ cập nhật tọa độ chuẩn hóa.
  - Lưu và nạp snapshot `StudioState` khôi phục đầy đủ danh sách sticker.
