# Phase 04 — Free-Floating Draggable PDF Window & End-to-End Integration

## Objective
Thay thế chế độ chia đôi Split View 50/50 cứng nhắc bằng Cửa sổ PDF nổi tự do (Free-Floating Draggable & Resizable Window) trên mặt bảng đen; hỗ trợ kéo thả tệp từ khay tài liệu ra bất kỳ vị trí nào trên bảng; cho phép vừa viết bảng vừa chú thích trên tài liệu và kiểm thử toàn diện hệ thống.

---

## Scope & Implementation Tasks

1. **Xây dựng Widget Cửa sổ PDF Nổi (`floating_pdf_window.dart`):**
   - Đặt trên `Stack` bề mặt bảng với vị trí `Offset position` và kích thước `Size size` (mặc định width: `480px`, height: `620px`).
   - **Thanh Header (Drag Handle):**
     - Cho phép giáo viên giữ chuột/bút và kéo (`onPanUpdate`) để di chuyển cửa sổ PDF đi khắp mọi nơi trên bảng.
     - Tự động giới hạn (clamp) trong phạm vi màn hình để không bị kéo trôi mất.
     - Hiển thị tên tài liệu (truncate gọn gàng nếu tên dài kèm icon PDF đỏ).
     - Cụm nút điều hướng trang PDF: `< Trang 1/12 >`.
     - Nút Thu nhỏ / Phóng to toàn màn hình (Maximize/Restore).
     - Nút Đóng `✕`: đóng cửa sổ trên bảng nhưng tệp vẫn được lưu an toàn trong khay tài liệu bài giảng.
   - **Góc kéo Resize (Resize Handle):**
     - Đặt ở góc dưới cùng bên phải của cửa sổ.
     - Cho phép giáo viên kéo để tùy ý mở rộng hoặc thu nhỏ kích thước tài liệu (giới hạn min 320x240).
   - **Lớp hiển thị và Ghi chú PDF:**
     - Tích hợp `PdfStage` bên trong khung cửa sổ nổi, giữ nguyên khả năng vẽ ghi chú (annotations) trực tiếp lên từng trang tài liệu.

2. **Tích hợp Kéo-Thả từ Khay Tài liệu (`main.dart` & `drawer_questions.dart`):**
   - Khi giáo viên kéo một tệp PDF từ khay tài liệu (`Draggable<ImportedDocument>`) và thả vào bảng đen (`DragTarget`):
     - Hệ thống tự động mở cửa sổ `FloatingPdfWindow` với tài liệu đó.
     - Vị trí ban đầu của cửa sổ PDF xuất hiện ngay tại tọa độ mà giáo viên vừa thả chuột ra trên bảng.

3. **Kiểm thử End-to-End & Tích hợp Toàn diện:**
   - Cập nhật các test suite:
     - `test/pdf_integration_test.dart`: Kiểm tra tương tác ghi chú trên PDF độc lập.
     - `test/stage_switcher_test.dart`: Kiểm tra hiển thị và kéo thả cửa sổ PDF nổi.
     - `test/drawing_engine_test.dart`: Kiểm tra toàn bộ tính năng vẽ nét, laser và highlighter.
   - Chạy kiểm tra chất lượng code: `dart format`, `flutter analyze`, và `flutter test`.

---

## Files / Modules Affected
- `app/lib/widgets/floating_pdf_window.dart` (mới)
- `app/lib/widgets/stage_container.dart`
- `app/lib/widgets/drawer_questions.dart`
- `app/lib/models/studio_state.dart`
- `app/lib/main.dart`
- `app/test/pdf_integration_test.dart`
- `app/test/stage_switcher_test.dart`

---

## Dependencies
- Phụ thuộc Phase 01, Phase 02, Phase 03 để đảm bảo cửa sổ PDF tương tác nhịp nhàng với canvas đã hỗ trợ pan/zoom và dual-layer inking.

---

## Tests & Acceptance Criteria
- [x] Kéo thả file PDF từ khay tài liệu vào bảng: cửa sổ PDF xuất hiện ngay vị trí con trỏ.
- [x] Giữ thanh header kéo thả di chuyển tự do đến mọi vị trí trên bảng đen.
- [x] Kéo góc resize: cửa sổ co giãn mượt mà, nội dung PDF tự scale theo khung.
- [x] Đổi trang PDF và vẽ ghi chú lên trang: nét vẽ lưu trữ chính xác theo từng trang PDF.
- [x] Bấm nút đóng: cửa sổ PDF đóng lại, file vẫn còn trong khay tài liệu bài giảng.
- [x] Toàn bộ unit tests và widget tests pass 100%.

---

## Risks & Notes
- Khi canvas bảng đen đang zoom, cần đảm bảo tọa độ kéo thả cửa sổ PDF được tính toán tương thích với viewport người dùng để tránh bị nhảy vị trí.
