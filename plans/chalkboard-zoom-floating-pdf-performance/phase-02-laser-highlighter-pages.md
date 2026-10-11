# Phase 02 — Laser Trail, Highlighter & Multi-Page Undo/Redo

## Objective
Trang bị bộ công cụ giảng dạy chuyên sâu cho giáo viên: Con trỏ laser (Laser Trail) phát sáng tự tan biến sau 1.5 giây mà không làm bẩn bài giảng, Bút dạ quang (Highlighter) trong suốt làm nổi bật chữ, Chuyển trang bảng độc lập và Hệ thống Hoàn tác/Làm lại (Undo/Redo) chuẩn xác.

---

## Scope & Implementation Tasks

1. **Con trỏ Laser Trail tự tan biến (`stroke_canvas.dart` & `studio_state.dart`):**
   - Khi chọn `tool == 'laser'`: các điểm rê chuột/vung bút được ghi nhận kèm mốc thời gian: `LaserPoint(Offset point, DateTime createdAt)`.
   - Sử dụng một `Ticker` hoặc periodic timer cập nhật ở tần số 60fps để tự động loại bỏ các điểm cũ hơn `1500ms`.
   - Render vệt laser: đường nối các điểm laser còn lại với hiệu ứng phát quang rực rỡ (glow gradient), độ mờ (opacity) giảm dần theo thời gian từ 1.0 về 0.0 (fade-out mượt mà).
   - Ticker tự ngắt khi danh sách điểm rỗng để tiết kiệm tài nguyên CPU/GPU.
   - Laser trail chỉ vẽ trên overlay và **không bao giờ ghi vào lịch sử nét vẽ** của trang.

2. **Bút dạ quang (Highlighter) trong suốt:**
   - Khi chọn `tool == 'highlight'`:
     - Thiết lập `strokeWidth = 20.0px`.
     - Sử dụng `color.withValues(alpha: 0.35)` để nét vẽ có độ trong suốt dịu mắt.
     - Nét dạ quang làm nổi bật rõ ràng các dòng chữ, công thức hoặc hình vẽ nằm bên dưới mà không bị đè che mất nội dung.

3. **Quản lý đa trang bảng độc lập (Multi-Page):**
   - Cung cấp cơ chế lưu trữ danh sách các trang bảng riêng biệt: `List<List<BoardStroke>> pages`.
   - Thêm các phương thức: `nextPage()`, `prevPage()`, `addPage()`.
   - Bổ sung cụm nút điều hướng trang tinh tế trên giao diện: `< Trang 1 / 3 >` kèm nút `+` thêm trang mới.
   - Khi chuyển trang, toàn bộ nét vẽ của trang hiện tại được giữ nguyên, trang đích hiển thị đúng dữ liệu nét vẽ riêng của nó.

4. **Hệ thống Hoàn tác (Undo) và Làm lại (Redo) chuẩn xác:**
   - Trong `StudioState`: bổ sung cấu trúc `Map<int, List<BoardStroke>> redoPages = {};` để quản lý redo stack cho từng trang.
   - Phương thức `undo()`: lấy nét cuối cùng từ `strokes`, đưa vào `redoPages[page]`, invalidate cache và notify.
   - Phương thức `redo()`: lấy nét cuối cùng từ `redoPages[page]`, trả lại vào `strokes`, invalidate cache và notify.
   - Khi người dùng vẽ một nét mới: tự động xóa sạch `redoPages[page]`.
   - Hỗ trợ phím tắt: `Ctrl + Z` để Undo, `Ctrl + Y` hoặc `Ctrl + Shift + Z` để Redo.

---

## Files / Modules Affected
- `app/lib/models/studio_state.dart`
- `app/lib/widgets/stroke_canvas.dart`
- `app/lib/main.dart`
- `app/test/drawing_engine_test.dart`

---

## Dependencies
- Phụ thuộc Phase 01 (Dual-layer canvas architecture).

---

## Tests & Acceptance Criteria
- [x] Vệt laser sáng rực khi vung bút và tự biến mất hoàn toàn sau 1.5 giây.
- [x] Laser không để lại bất kỳ nét vẽ nào trong `strokes`.
- [x] Bút dạ quang hiển thị đúng độ trong suốt (alpha ≈ 0.35) và nét dày 20px.
- [x] Chuyển trang qua lại: nét vẽ của từng trang không bị mất và không bị lẫn sang trang khác.
- [x] Kiểm thử Undo/Redo: vẽ 3 nét -> undo 2 nét -> redo 1 nét -> vẽ nét mới -> redo stack bị reset chính xác.

---

## Risks & Notes
- Đảm bảo Ticker của Laser trail được `dispose()` đúng cách khi widget unmount để tránh rò rỉ bộ nhớ.
