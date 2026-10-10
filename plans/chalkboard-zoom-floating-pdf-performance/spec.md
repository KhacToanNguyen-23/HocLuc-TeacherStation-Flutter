# Spec: Chalkboard Compact Grid, Pan/Zoom, Free-Floating PDF, Laser Trail, Page Control & Zero-Latency Inking

**Date:** 2026-10-10  
**Status:** Ready  

---

## Problem Statement

Giáo viên khi giảng bài cần không gian viết rộng rãi và chứa được nhiều nội dung bài giảng hơn nhờ ô ly nhỏ gọn. Bảng đen cần hỗ trợ thu phóng (zoom) và di chuyển (pan) mượt mà bằng phím tắt/con lăn phù hợp với bảng vẽ stylus. Tài liệu PDF khi kéo ra bảng phải là cửa sổ nổi tự do, có thể đặt ở bất kỳ vị trí nào thay vì chia đôi màn hình cố định. Ngoài ra, giáo viên cần các công cụ tương tác mạnh mẽ: con trỏ laser tự biến mất sau 1–2 giây để tập trung chú ý của học sinh, bút dạ quang trong suốt làm nổi bật chữ, chuyển trang độc lập lưu đúng nét từng trang, và hệ thống Undo/Redo chính xác. Quan trọng nhất, cơ chế viết trên bảng và PDF phải triệt tiêu hoàn toàn độ trễ và giật lag, đạt trải nghiệm viết tự nhiên 60fps–120fps.

---

## User Stories

- **[P1]** Là một giáo viên, tôi muốn ô lưới bảng nhỏ hơn (15px) để có thể viết được nhiều chữ, công thức Toán - Lý - Hóa trên một khung hình mà không lo nhanh hết bảng.
  *Accepted when:* Ô ly hiển thị sắc nét với kích thước 15px, đường kẻ chính mỗi 5 ô (75px) rõ ràng, tăng mật độ viết lên ~2.5 lần so với ô 24px cũ.

- **[P1]** Là một giáo viên dùng bảng vẽ/chuột, tôi muốn giữ phím `Space` (hoặc nút phụ trên bút) để Pan bảng và lăn chuột (hoặc `Ctrl + Scroll`) để Zoom in/out bảng một cách tự nhiên.
  *Accepted when:* Bảng có thể phóng to từ 50% đến 300%, di chuyển vùng nhìn mượt mà, và tọa độ ngòi bút vẽ khớp chính xác 100% với điểm tiếp xúc trên canvas dù ở bất kỳ tỷ lệ zoom hay vị trí pan nào.

- **[P1]** Là một giáo viên, tôi muốn kéo tài liệu PDF từ khay tài liệu và thả tự do ở bất kỳ vị trí nào trên bảng dưới dạng cửa sổ nổi (floating draggable window).
  *Accepted when:* PDF hiển thị dạng thẻ nổi có thanh tiêu đề (drag handle) để giữ và kéo đi khắp mặt bảng; có nút điều hướng trang, nút đóng cửa sổ (không làm mất file trong khay) và nút kéo góc để thay đổi kích thước.

- **[P1]** Là một giáo viên, tôi muốn nét vẽ trên bảng và PDF hiển thị tức thì không có độ trễ hay giật lag khi vung bút nhanh.
  *Accepted when:* Kiến trúc render 2 lớp (Dual-layer) tách biệt nét đã hoàn thành (đã cache Path) và nét đang vẽ dở (RepaintBoundary riêng); loại bỏ hoàn toàn việc tính toán lại spline cho nét cũ; duy trì 60fps ổn định kể cả khi có > 100 nét trên bảng.

- **[P1]** Là một giáo viên, tôi muốn dùng Con trỏ Laser (Laser Trail) để khoanh tròn hoặc gạch chân định nghĩa/công thức mà đường vẽ tự động sáng lên rồi biến mất sau 1–2 giây, không để lại vết bẩn trên bài giảng.
  *Accepted when:* Khi chọn công cụ `laser`, thao tác vẽ tạo thành vệt sáng laser phát quang (glow effect); vệt vẽ tự động mờ dần và biến mất hoàn toàn sau 1.5 giây mà không lưu vào danh sách nét vẽ của bảng.

- **[P1]** Là một giáo viên, tôi muốn bút dạ quang (Highlighter) có độ trong suốt và làm nổi bật nội dung chữ hoặc công thức bên dưới mà không che lấp chữ.
  *Accepted when:* Khi chọn công cụ `highlight`, nét vẽ có độ dày lớn (18–24px) và độ trong suốt `alpha ≈ 0.35`, hiển thị rõ ràng nội dung chữ/nét vẽ nằm bên dưới.

- **[P1]** Là một giáo viên, tôi muốn chuyển trang (Page Next/Prev) trên bảng mà nét vẽ của từng trang được lưu giữ trọn vẹn, không bị lẫn nét sang trang khác.
  *Accepted when:* Bấm nút chuyển trang tiếp / trang trước thì toàn bộ nét vẽ của trang cũ được bảo lưu đúng vị trí; trang mới mở ra sạch sẽ hoặc hiển thị đúng các nét đã vẽ trước đó của trang đó.

- **[P1]** Là một giáo viên, tôi muốn hệ thống Hoàn tác (Undo) và Làm lại (Redo) hoạt động chuẩn xác từng trang.
  *Accepted when:* Bấm `Undo` (hoặc `Ctrl+Z`) sẽ hủy nét vẽ vừa vẽ gần nhất; bấm `Redo` (hoặc `Ctrl+Y` / `Ctrl+Shift+Z`) sẽ khôi phục lại nét vừa undo; ngăn ngừa mất mát nét vẽ ngoài ý muốn.

- **[P2]** Là một giáo viên, tôi muốn có nút bấm nhanh ở góc bảng để đưa mức zoom về lại 100% (Reset Zoom) và hiển thị chỉ số % zoom hiện tại.
  *Accepted when:* Bảng có widget nhỏ gọn ở góc dưới hiển thị tỷ lệ zoom (ví dụ: `100%`, `150%`) và nút bấm 1 chạm để reset về kích thước chuẩn ban đầu.

---

## Functional Requirements

1. **FR-01 (Compact Grid):**
   - Cập nhật `GridPainter` với `cellSize = 15.0px`, nét phụ `chalkboardSubGrid`, nét chính sau mỗi 5 ô ly (`colIndex % 5 == 0`, `rowIndex % 5 == 0`).
2. **FR-02 (Canvas Pan & Zoom):**
   - Tích hợp `InteractiveViewer` / `TransformationController` bao bọc vùng bảng đen.
   - Nhận diện phím `Space` được nhấn: khi giữ Space, con trỏ chuột chuyển sang `SystemMouseCursors.grab` và thao tác kéo sẽ di chuyển (Pan) canvas thay vì vẽ nét.
   - Hỗ trợ cuộn chuột `Ctrl + Scroll` hoặc con lăn để Zoom in/out trong dải `0.5x` đến `3.0x`.
   - Chuẩn hóa tọa độ nét vẽ qua `TransformationController.toScene(localOffset)` để nét vẽ không bị lệch khi canvas bị biến đổi ma trận.
3. **FR-03 (Free-Floating Draggable PDF Window):**
   - Thay thế cơ chế SplitView cứng nhắc bằng widget `FloatingPdfWindow` hiển thị trên `Stack` của bảng đen.
   - Thanh header đóng vai trò `DragHandle` cho phép giữ và kéo tự do vị trí `(dx, dy)` trên mặt bảng.
   - Có góc resize (Resize Handle) ở góc dưới-phải để giáo viên tùy chỉnh chiều rộng/cao của khung PDF.
   - Hỗ trợ vẽ ghi chú (annotation) trực tiếp trên trang PDF với tọa độ độc lập tương thích theo kích thước cửa sổ nổi.
4. **FR-04 (Dual-Layer Zero-Latency Inking):**
   - Tách `StrokeCanvas` thành 2 CustomPainter:
     - `CommittedStrokesPainter`: Chỉ vẽ các `BoardStroke` đã hoàn thành bằng cách gọi `canvas.drawPath(stroke.getPath(), paint)`. Không gọi `getStroke()` lại!
     - `ActiveStrokePainter`: Chỉ vẽ duy nhất 1 nét đang được kéo (`currentStrokePoints`) bọc trong `RepaintBoundary`.
   - Khi nhấc bút (`onPanEnd`), nét vẽ hoàn thành được đẩy sang danh sách committed strokes và tạo sẵn cache `Path`.
   - Hạn chế `notifyListeners()` toàn cục trong `onPanUpdate`. Chỉ cập nhật `ValueNotifier<List<Offset>>` cho active stroke painter để không làm rebuild toàn bộ cây widget của Studio.
5. **FR-05 (Laser Pointer Trail with Auto-Fade):**
   - Quản lý danh sách điểm laser kèm timestamp: `LaserPoint(Offset point, DateTime timestamp)`.
   - Sử dụng Ticker / AnimationController định kỳ (60fps) loại bỏ các điểm có tuổi thọ > 1.5 giây.
   - Hiệu ứng render: đường nối các điểm laser còn lại kèm hiệu ứng glow gradient (xanh ngọc sáng hoặc đỏ neon rực rỡ) và độ mờ giảm dần theo thời gian (fade out).
   - Tuyệt đối không lưu các điểm laser vào mảng lưu trữ `pages[page]`.
6. **FR-06 (Highlighter Tool with Translucency):**
   - Khi `tool == 'highlight'`:
     - Màu mực hiển thị dạng dạ quang (vàng chanh, xanh nõn chuối, cam neon...).
     - `Paint` sử dụng `color.withValues(alpha: 0.35)`.
     - Độ rộng nét `strokeWidth = 20.0px`.
     - Render bên dưới hoặc cùng lớp với blend mode trong suốt để nội dung chữ bên dưới không bị che lấp.
7. **FR-07 (Independent Multi-Page Management):**
   - Cung cấp danh sách các trang bảng `List<List<BoardStroke>> pages`.
   - Cung cấp nút `Trang trước` (`<`), `Trang sau` (`>`), và `Thêm trang mới` (`+`) với chỉ số hiển thị dạng `Trang 1 / 3`.
   - Khi chuyển trang, giải phóng nét vẽ cũ khỏi active buffer và hiển thị đúng danh sách nét của trang được chọn.
8. **FR-08 (Accurate Undo & Redo System):**
   - Trong `StudioState`, lưu trữ `List<BoardStroke> redoStack = []` cho mỗi trang.
   - Khi người dùng vẽ nét mới: xóa sạch `redoStack`.
   - Khi gọi `undo()`: lấy nét cuối cùng từ `strokes`, đưa vào `redoStack` và invalidate canvas.
   - Khi gọi `redo()`: lấy nét cuối cùng từ `redoStack`, đưa ngược lại vào `strokes` và invalidate canvas.

---

## Non-Functional Requirements

- **Performance:** Thời gian render frame vẽ dưới `16.6ms` (duy trì 60fps mượt mà, đạt 120fps trên màn hình hỗ trợ tần số quét cao).
- **Latency:** Độ trễ tiếp nhận điểm vẽ (Input latency) dưới `10ms`.
- **Memory:** Không tạo rác (garbage collection) hàng loạt từ việc sinh đối tượng `PointVector` và `Path` cho các nét cũ.
- **Cross-Platform:** Hoạt động ổn định cả trên Desktop Windows và Web Chrome.

---

## Success Criteria

- [ ] Lưới bảng đen hiển thị ô ly nhỏ 15px sắc nét, tăng mật độ viết lên gấp ~2.5 lần.
- [ ] Giữ Space kéo bảng (Pan) và lăn chuột (Zoom) trơn tru, nét vẽ không bị lệch tọa độ.
- [ ] Cửa sổ PDF có thể kéo thả tự do khắp bảng, đổi trang và resize kích thước dễ dàng.
- [ ] Vẽ liên tục 50–100 nét chữ/công thức không còn hiện tượng drop frame hay trễ đuôi nét bút.
- [ ] Vệt laser sáng rực khi vẽ và tự biến mất hoàn toàn sau 1.5 giây mà không lưu bẩn bài giảng.
- [ ] Bút dạ quang (Highlighter) trong suốt làm nổi bật chữ/công thức rõ ràng.
- [ ] Chuyển trang (Next/Prev) lưu độc lập từng trang; Undo và Redo hoạt động chính xác 100%.
- [ ] 100% Unit test và Widget test hiện tại pass không lỗi lầm.

---

## Out of Scope

- Nhận diện chữ viết tay OCR thành văn bản số.
- Đọc nhiều file PDF cùng lúc trên nhiều cửa sổ (phiên bản này hỗ trợ 1 cửa sổ PDF nổi đang hoạt động).

---

## Assumptions

- Giáo viên sử dụng chuột, bàn phím và bảng vẽ điện tử (Stylus Pen Tablet) trên môi trường Desktop hoặc Web.
- Phím `Space` là chuẩn mực phổ biến cho thao tác Pan trong các phần mềm đồ họa và bảng trắng.
