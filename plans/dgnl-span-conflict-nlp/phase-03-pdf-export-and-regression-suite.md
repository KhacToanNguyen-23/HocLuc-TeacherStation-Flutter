# Phase 03: PDF Physical Export Alignment & Regression Suite

**Phase ID:** `phase-03-pdf-export-and-regression-suite`
**Priority:** P1
**Objective:** Đồng bộ hóa cơ chế xuất vệt highlight vật lý vào file PDF (`PdfAnnotationExporter`) theo đúng chuẩn Visual Channel Separation, và xây dựng bộ kiểm thử hồi quy end-to-end cho toàn bộ tính năng bóc tách đa tầng.

---

## Detailed Tasks

1. **Physical PDF Graphics Alignment (`PdfAnnotationExporter`):**
   - Trong [`pdf_annotation_exporter.dart`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/frontend/lib/services/pdf_annotation_exporter.dart):
     - **Tầng Ngữ pháp:** Vẽ bằng `page.graphics.drawRectangle(pen: sf.PdfPen(color, width: 1.5))` dạng nét đứt hoặc viền rỗng (không tô brush nền) để giữ nguyên chuẩn trong suốt khi người dùng mở PDF bằng Adobe Reader hoặc in ra giấy.
     - **Tầng Collocation & Vocab:** Vẽ bằng `sf.PdfSolidBrush` với độ trong suốt chuẩn `0.22 - 0.28`. Nếu từ vựng nằm trong collocation, chỉ vẽ viền pen mỏng quanh từ vựng để tránh chồng 2 lần cọ vẽ làm đen chữ in.
2. **Đồng bộ hóa Nét vẽ Bảng (`BoardStroke` trên `StrokeCanvas`):**
   - Trong `StrokeCanvas.paint()`: Đảm bảo các nét vẽ highlight được tạo ra từ `applyHighlightDirectlyToPdf` phản ánh đúng: Ngữ pháp là viền rỗng/nét đứt, Collocation là nền mờ, không bị đè màu khi lưu bài giảng vào cơ sở dữ liệu.
3. **Bộ kiểm thử Tự động Hồi quy Toàn diện (Regression Test Suite):**
   - Trong `frontend/test/dgnl_snip_highlight_test.dart`:
     - Test trường hợp đoạn văn có cấu trúc lồng nhau (Grammar lồng Collocation, Collocation lồng Vocab).
     - Test xuất byte PDF với các annotation không chồng chéo màu.
     - Test hoạt động của bộ lọc Tab và hiệu ứng làm mờ (ghosting).
     - Test độ bền dữ liệu khi tắt plugin hoặc chuyển trang.

---

## Affected Files

- `frontend/lib/services/pdf_annotation_exporter.dart`
- `frontend/lib/widgets/stroke_canvas.dart`
- `frontend/test/dgnl_snip_highlight_test.dart`

---

## Dependencies

- Phụ thuộc vào `phase-01-visual-channel-separation`.

---

## Tests and Acceptance Criteria

- Chạy: `flutter test test/dgnl_snip_highlight_test.dart` -> 100% tests pass.
- Chạy: `flutter analyze` -> 0 issues found.
- Xuất file PDF thực tế và mở bằng Syncfusion PDF parser kiểm tra số lượng text annotations và appearance graphics stream hợp lệ.
