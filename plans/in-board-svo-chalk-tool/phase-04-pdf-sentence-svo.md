# Phase 04 — PDF Sentence Touch Detection & S-V-O Overlay

**Phase ID:** `phase-04-pdf-sentence-svo`  
**Mapped Stories:** P1 (PDF Sentence S-V-O Touch Trigger & Direct Annotation)  
**Status:** `not_started`

---

## 1. Objectives
Mở rộng công cụ S-V-O sang tệp tài liệu PDF (`PdfStage`). Khi giáo viên mở giáo trình/tài liệu bài giảng dạng PDF và bật công cụ S-V-O, việc chạm/click vào một câu văn trong trang PDF sẽ tự động vẽ các nét gạch chân phấn màu và chữ $S, V, O$ chính xác ngay dưới dòng chữ của tài liệu, đồng bộ 100% với phóng to/thu nhỏ và lật trang PDF.

---

## 2. Scope & Implementation Details

1. **Lớp phủ Chú thích trên Trang PDF (`frontend/lib/widgets/pdf_stage.dart`):**
   - Trong `pageOverlaysBuilder` của `pdfrx`, bên cạnh `StrokeCanvas`, tích hợp thêm widget `SmartChalkOverlay` dành riêng cho từng trang PDF.
   - Nguồn dữ liệu chú thích được lấy từ `studio.pdfChalkAnnotations[page.pageNumber]`.
   - Các nét gạch chân phấn màu và ký hiệu $S, V, O$ di chuyển và co giãn hoàn hảo theo ma trận thu phóng (Zoom & Pan) của `PdfViewerController`.

2. **Xử lý Cử chỉ Chạm trên Trang PDF:**
   - Khi `studio.activeSubjectTool == 'svo'`:
     - Chặn thao tác vẽ nét bút thông thường trên PDF overlay.
     - Lấy tọa độ chuẩn hóa $[0.0, 1.0]$ của điểm chạm trên trang PDF.
     - Xác định câu văn tiếng Anh tại vùng chạm: Khớp vị trí dòng văn bản trong trang PDF (hoặc câu văn mẫu từ giáo trình bài giảng).
     - Gọi hàm phân tích cú pháp `EnglishSentenceAnalyzer.analyze(text: detectedSentence)`.
     - Tính toán tọa độ đặt nét gạch chân phấn màu ôm sát dưới dòng chữ tài liệu.
     - Lưu đối tượng `SmartChalkAnnotation` vào `studio.pdfChalkAnnotations[pageNumber]` và cập nhật giao diện.

3. **Cập nhật Quản lý Dữ liệu `StudioState` (`frontend/lib/models/studio_state.dart`):**
   - Bổ sung `Map<int, List<SmartChalkAnnotation>> pdfChalkAnnotations`.
   - Bổ sung hàm `analyzePdfSentenceAt(int pageNumber, Offset normPoint, {String? sampleText})`.
   - Bổ sung hàm `clearPdfChalkAnnotations(int pageNumber)`.
   - Cập nhật `exportLessonJson()` và `restoreFromJson()` để lưu trữ và khôi phục các chú thích S-V-O trên tệp PDF.

---

## 3. Files Affected
- `frontend/lib/widgets/pdf_stage.dart` *(Cập nhật lớp phủ chú thích và cử chỉ chạm)*
- `frontend/lib/models/studio_state.dart` *(Cập nhật quản lý chú thích PDF & serialization)*
- `frontend/test/pdf_sentence_svo_test.dart` *(Kiểm thử tính năng chạm phân tích S-V-O trên trang PDF)*

---

## 4. Dependencies
- Phụ thuộc vào `SmartChalkAnnotation` và `SmartChalkOverlay` (Phase 02).
- Tích hợp với `PdfStage` và `pdfrx`.

---

## 5. Tests & Acceptance Criteria
- [ ] Chạy lệnh `flutter test test/pdf_sentence_svo_test.dart` pass 100%.
- [ ] Trong `PdfStage`, khi S-V-O tool đang bật, chạm vào một dòng chữ trên trang 1 sẽ tự động sinh chú thích S-V-O vào `pdfChalkAnnotations[1]`.
- [ ] Chuyển sang trang 2 hoặc quay lại trang 1, các nét gạch chân S-V-O hiển thị đúng theo từng trang tương ứng.
- [ ] Bấm nút con mắt trên dock, các chú thích S-V-O trên PDF ẩn/hiện đồng bộ.
- [ ] Lưu và tải lại bài giảng, các chú thích trên PDF được giữ nguyên vẹn.

---

## 6. Risks & Notes
- Nền PDF có thể màu trắng sáng, làm giảm độ tương phản của một số màu phấn pastel: Áp dụng hiệu ứng viền bóng mờ (subtle dark outline/halo) xung quanh nét phấn và chữ $S, V, O$ để luôn nổi bật trên cả nền tối bảng đen lẫn nền trắng tài liệu PDF.
