# Plan: In-Board Subject Tool Palette & S-V-O Handwritten Chalk Tool

Mode: Hard
Risk: normal — multi-file, canvas touch clustering & chalk annotation, non-destructive, fully testable

## Overview
Tính năng này nâng cấp trải nghiệm giảng dạy bộ môn Tiếng Anh (và các môn tương lai) từ dạng thanh gõ câu / modal rời rạc sang **Khay công cụ bộ môn dạng dock nổi (`SubjectToolPalette`)** trực tiếp trên mặt bảng phấn và tệp tài liệu PDF. Giáo viên chỉ cần chọn công cụ S-V-O và chạm ngón tay / click chuột vào dòng chữ viết tay trên bảng hoặc câu văn trong tệp PDF, hệ thống sẽ tự động gom nét, bóc tách cấu trúc S-V-O và vẽ các nét gạch chân phấn màu cùng ký hiệu $S$ (xanh `#89b4fa`), $V$ (hồng `#f38ba8`), $O$ (cam `#fab387`) chân thực như giáo viên tự cầm phấn gạch chân. Cụm ký hiệu này có thể ẩn/hiện đáp án qua nút mắt (👁️) trên khay dock, kéo thả di chuyển linh hoạt, và tự động lưu/khôi phục cùng bài giảng `.hls`.

---

## Research Findings & Architecture Decisions

### 1. Subject Tool Dock Architecture (`SubjectToolPalette`)
- Thay thế hoàn toàn widget cũ `InBoardExtensionBar` (vốn có thanh input nhập text và modal) bằng dock nổi nhỏ gọn `SubjectToolPalette`.
- Vị trí: Đặt nổi trên `StageContainer` với khả năng kéo thả (`onPanUpdate`), kích thước thanh mảnh (~320px x 42px).
- Nút tính năng:
  - Huy hiệu bộ môn (Icon + Tên môn Tiếng Anh).
  - Nút kích hoạt công cụ: **Công cụ S-V-O** (`activeSubjectTool == 'svo'`).
  - Nút con mắt: **Ẩn / Hiện đáp án** (`chalkAnnotationsVisible`).
  - Nút xóa toàn bộ chú thích trên trang hiện tại (`clearAnnotations`).
  - Nút đóng dock (`closePlugin`).

### 2. Smart Chalk S-V-O Model & Chalkboard Renderer
- Model `SmartChalkAnnotation`:
  - `id`: chuỗi định danh duy nhất (`svo-{timestamp}`).
  - `source`: `'chalkboard'` hoặc `'pdf'`.
  - `pageIndex`: trang bảng phấn hoặc trang PDF.
  - `rawText`: chuỗi câu văn ("I go to school.").
  - `bounds`: `Rect` normalized vùng bao của câu.
  - `tokens`: danh sách `ChalkWordToken` (từ vựng, vai trò `subject` / `verb` / `object`, màu phấn, `relativeRect`).
  - `isVisible`: trạng thái hiển thị (đồng bộ với nút mắt).
  - `offset`: độ dời khi giáo viên kéo di chuyển.
- Renderer ngòi phấn chân thực (`ChalkUnderlinePainter`):
  - Vẽ nét gạch chân có độ nhám/hạt tự nhiên của phấn bảng (stippled stroke / textured path).
  - Vẽ nhãn $S, V, O$ đặt ngay ngắn dưới nét gạch chân với màu pastel chuẩn: S (xanh `#89b4fa`), V (hồng `#f38ba8`), O (cam `#fab387`).

### 3. Spatial Clustering & Touch Detection trên Bảng Phấn
- Khi `activeSubjectTool == 'svo'`, thao tác chạm vào `InteractiveChalkboard` / `StrokeCanvas` chuyển sang chế độ hit-testing:
  - Tìm tất cả các `BoardStroke` nằm trong bán kính tương tác xung quanh điểm chạm.
  - Thuật toán gom cụm nét vẽ (Spatial Clustering): Gom các nét vẽ cùng dòng chữ (dựa trên chênh lệch tung độ $\Delta y < 0.05$ và độ gần hoành độ $\Delta x$), tính toán `boundingRect` toàn câu và chia đoạn từng từ.
  - Ánh xạ nội dung câu văn: Sử dụng bộ phân tích cú pháp `EnglishSentenceAnalyzer` kết hợp từ điển mẫu và bộ từ loại (Pronouns, Nouns, Verbs).
  - Tự động sinh `SmartChalkAnnotation` ngay chân chữ viết tay trong $< 400\text{ ms}$.

### 4. PDF Sentence S-V-O Detection
- Trong `PdfStage`, khi `activeSubjectTool == 'svo'`, click/tap vào trang PDF:
  - Xác định vị trí điểm chạm trên trang PDF hiện tại.
  - Trích xuất dòng chữ / câu văn tiếng Anh tại vị trí chạm (hoặc câu mẫu gần nhất trong tài liệu).
  - Sinh `SmartChalkAnnotation` cho trang PDF (`pdfChalkAnnotations[pageNumber]`) và hiển thị trực tiếp trên lớp overlay của `PdfStage`.

### 5. State Management & Bài Giảng Persistence
- Thêm vào `StudioState`:
  - `String? activeSubjectTool`: công cụ môn đang chọn (`'svo'` hoặc `null`).
  - `bool chalkAnnotationsVisible = true`: trạng thái ẩn/hiện toàn cục.
  - `Map<int, List<SmartChalkAnnotation>> pageChalkAnnotations`: danh sách chú thích trên từng trang bảng phấn.
  - `Map<int, List<SmartChalkAnnotation>> pdfChalkAnnotations`: danh sách chú thích trên từng trang PDF.
- Phương thức: `addChalkAnnotation`, `removeChalkAnnotation`, `toggleChalkAnnotationsVisibility`, `updateChalkAnnotationOffset`.
- Lưu trữ: Tích hợp vào `exportLessonJson()` và `restoreFromJson()` để lưu đầy đủ vào file bài giảng `.hls`.

---

## Phases

- [x] Phase 01: Subject Tool Palette Dock (`phase-01-subject-tool-palette.md`)
- [x] Phase 02: Smart Chalk S-V-O Model & Chalkboard Renderer (`phase-02-smart-chalk-svo-renderer.md`)
- [x] Phase 03: Handwriting Stroke Clustering & Chalkboard Touch Trigger (`phase-03-handwriting-stroke-clustering.md`)
- [x] Phase 04: PDF Sentence Touch Detection & S-V-O Overlay (`phase-04-pdf-sentence-svo.md`)
- [x] Phase 05: End-to-End Integration & Verification Suite (`phase-05-e2e-integration.md`)

---

## Red-Team Review & Risk Mitigation
- **Rủi ro xung đột cử chỉ (Gesture Conflict):** Khi giáo viên muốn tiếp tục vẽ phấn mà không chạm kích hoạt S-V-O -> *Giải pháp:* Nút công cụ S-V-O trên Palette hoạt động như một toggle active mode. Khi bật S-V-O, cursor chuyển thành icon chọn/wand; khi giáo viên chọn công cụ Pen/Highlighter/Erase trên thanh Studio toolbar thì tự động hủy kích hoạt S-V-O tool để vẽ phấn bình thường mà không bị vướng.
- **Rủi ro chữ viết tay rời rạc không đủ nét thành câu:** -> *Giải pháp:* Thuật toán Spatial Clustering có cơ chế fallback: nếu không nhận diện được chữ cái rời rạc, thuật toán căn cứ vào số lượng khối nét và bounding box để gạch chân S-V-O theo tỷ lệ 1:1:1 hoặc đối chiếu với câu mẫu gần nhất của bài giảng, đảm bảo luôn sinh kết quả trực quan mượt mà trong $<400$ms.
- **Rủi ro co giãn/Zoom canvas & PDF làm lệch vị trí gạch chân:** -> *Giải pháp:* Toàn bộ tọa độ trong `SmartChalkAnnotation` được lưu trữ dưới dạng Normalized Coordinates ($[0.0, 1.0]$) tương tự `BoardStroke`, tự động co giãn chính xác 100% theo tỷ lệ màn hình và ma trận thu phóng của InteractiveViewer / PdfViewerController.
- **Đảm bảo khả năng chạy Offline & Tốc độ $\le 400$ms:** -> *Giải pháp:* Sử dụng `EnglishSentenceAnalyzer` thuần túy trong Dart để xử lý cú pháp tức thì mà không phụ thuộc vào kết nối mạng hay tiến trình Python sidecar, đáp ứng hoàn hảo cả Flutter Web và Flutter Windows.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-11 16:52
**Phase in progress:** Completed Hybrid S-V-O-A Architecture (spaCy + Cách 1 handwriting + Cách 2 dock quick-type)
**Status:** Hoàn thành toàn diện, 68/68 tests pass 100%, analyzer 0 issues

### Decisions made this session
- Cài đặt và tích hợp thành công Open-Source spaCy NLP (`en_core_web_sm`) tại Python Sidecar Backend (`plugins/english_assistant/engine/service.py`) qua endpoint `/analyze-svo`.
- Phân tích cú pháp chuyên sâu bóc tách đầy đủ Subject (S), Verb (V), Object (O) và Adverbial (A, màu xanh pastel `#a6e3a1`).
- Xử lý câu đơn từ (ví dụ chỉ có "I"): chỉ sinh duy nhất nhãn Subject ($S$), tuyệt đối không gán ép Verb hay Object ảo.
- Triển khai song song cả 2 cách theo ý tưởng người dùng:
  - **Cách 1 (Viết tay trên bảng):** Gom cụm nét vẽ, tính toán bounds thực tế, gửi phân tích cú pháp và gạch chân ôm sát chân nét chữ (`strokeHeight + 2px`).
  - **Cách 2 (Gõ/chọn câu trên Dock):** Thêm nút `[✏️ Nhập câu]` trên Dock với Modal dialog hỗ trợ cả nhập câu tự do lẫn chip mẫu chọn nhanh, gạch chân xuất hiện ngay lập tức trên bảng.
- Cơ chế Deduplication thông minh: Giới hạn tối đa 1 phân tích duy nhất tại 1 khu vực/câu, ngăn chặn hoàn toàn việc tap nhiều lần sinh nhiều đường gạch chồng chéo nhau.
- Bộ test tự động `test/hybrid_svo_ocr_test.dart` (6/6 pass), toàn bộ 68/68 tests của dự án vượt qua 100%, `flutter analyze` 0 issues.

### Next immediate action
Báo cáo giải pháp và hướng dẫn người dùng trải nghiệm thực tế cả 2 cách trên ứng dụng.

