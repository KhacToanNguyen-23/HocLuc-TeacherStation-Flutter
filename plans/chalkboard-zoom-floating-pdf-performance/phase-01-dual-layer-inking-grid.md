# Phase 01 — Zero-Latency Dual-Layer Inking & Compact Grid

## Objective
Thu nhỏ kích thước ô ly bảng về 15px (tăng mật độ bài giảng gấp 2.5–3 lần) và tái cấu trúc engine vẽ nét theo kiến trúc 2 lớp (Dual-Layer) tách biệt nét cũ đã cache và nét đang vẽ dở, triệt tiêu hoàn toàn giật lag và độ trễ ngòi bút (Zero-latency 60fps).

---

## Scope & Implementation Tasks

1. **Cập nhật Grid ô ly chuẩn học đường (`grid_painter.dart`):**
   - Đổi `cellSize` mặc định từ `24.0` thành `15.0`.
   - Cập nhật chu kỳ đường kẻ chính: mỗi 5 ô ly (`colIndex % 5 == 0`, `rowIndex % 5 == 0`, tương đương 75px mỗi ô lớn chuẩn vở 5 ly Việt Nam).
   - Đảm bảo độ tương phản nét phụ `chalkboardSubGrid` nhẹ nhàng, tạo chiều sâu cho bảng đen.

2. **Tái cấu trúc Dual-Layer Inking Engine (`stroke_canvas.dart`):**
   - **Lớp 1 - CommittedStrokesPainter:**
     - Vẽ toàn bộ danh sách `strokes` đã hoàn thành bằng cách gọi trực tiếp `canvas.drawPath(stroke.getPath(), paint)`.
     - Tuyệt đối không gọi thuật toán `getStroke()` trong vòng lặp paint của các nét cũ.
     - Bọc lớp này trong `RepaintBoundary` riêng biệt, chỉ repaint khi có nét mới được thêm vào hoặc xóa đi (Undo/Erase).
   - **Lớp 2 - ActiveStrokePainter:**
     - Chỉ nhận danh sách điểm của duy nhất 1 nét đang được vung bút (`activePoints`).
     - Sử dụng `ValueNotifier<List<Offset>>` nội bộ để kích hoạt repaint chỉ riêng cho lớp này khi di chuyển bút (`onPanUpdate`), không kích hoạt `notifyListeners()` toàn cục gây rebuild cả màn hình.
     - Bọc lớp này trong `RepaintBoundary` riêng biệt.

3. **Cập nhật cơ chế hoàn tất nét vẽ (`studio_state.dart`):**
   - Khi `onPanEnd`: chuyển các điểm từ `activePoints` vào `BoardStroke`, gọi `stroke.getPath()` để tính toán spline 1 lần duy nhất và lưu vào `_cachedPath`.
   - Sau đó mới gọi `notifyListeners()` để cập nhật dữ liệu lưu trữ / undo stack.

---

## Files / Modules Affected
- `app/lib/widgets/grid_painter.dart`
- `app/lib/widgets/stroke_canvas.dart`
- `app/lib/models/studio_state.dart`
- `app/test/drawing_engine_test.dart`

---

## Dependencies
- Không phụ thuộc các phase khác. Đây là nền tảng cốt lõi cho trải nghiệm viết trên toàn ứng dụng.

---

## Tests & Acceptance Criteria
- [x] Chạy `flutter test test/drawing_engine_test.dart` vượt qua 100%.
- [x] Kích thước ô ly đo lường thực tế đạt đúng 15.0px.
- [x] `CommittedStrokesPainter` không gọi `getStroke` cho các nét cũ.
- [x] `ActiveStrokePainter` chỉ repaint riêng biệt mà không trigger rebuild của widget cha.
- [x] Tốc độ vẽ duy trì 60fps mượt mà kể cả khi có > 50 nét trên bảng.

---

## Risks & Notes
- Khi thay đổi kích thước container, các điểm `Offset` đang chuẩn hóa normalized (0.0 - 1.0) cần đảm bảo vẽ đúng tỷ lệ hiển thị.
