# Brainstorm: Giải quyết Xung đột Chồng lấn Highlight & Nâng cấp Deep Grammar NLP Engine

**Date:** 2026-10-14

## Ideas Explored

1. **Greedy Suppression (Khắc chế tuyệt đối - Flat Non-overlapping Spans):**
   - Sắp xếp spans theo `Priority (Grammar > Collocation > C1 > B2)` rồi `Length giảm dần`.
   - Cụm lớn nuốt cụm nhỏ (ví dụ `passive smoking` nuốt `smoking`).
   - *Đánh giá:* Giao diện PDF rất sạch, không bao giờ đè màu, nhưng làm mất thông tin từ vựng đơn lẻ khi giáo viên muốn dạy cả hai.

2. **Visual Channel Separation (Phân tách kênh đồ họa thị giác - Lồng ghép Concentric Layer UI) [CHỌN]:**
   - Phân tách độc lập thuộc tính đồ họa giữa các tầng:
     - **Tầng Ngữ pháp (Grammar):** Khung viền nét đứt bao ngoài (Dashed Outer Bracket/Border), nền trong suốt 100%.
     - **Tầng Cụm từ (Collocation):** Nền màu pastel nhẹ dạng viên thuốc (Soft green fill `#86efac` alpha 0.22).
     - **Tầng Từ vựng (CEFR B2/C1):** Viền bo mờ hoặc màu chữ nổi bật, nằm êm ái bên trong cụm mà không bị xung đột hay đổi màu nền.
   - *Đánh giá:* Cho phép nhìn thấy cấu trúc ngữ pháp bao quanh cụm collocation và từ vựng B2 cùng lúc mà không hề bị đè màu.

3. **spaCy Transformer (`en_core_web_trf`) vs spaCy Medium (`en_core_web_md`):**
   - `en_core_web_trf`: Bắt quan hệ phụ thuộc câu phức cực chuẩn, nhưng nặng ~450MB model, cần PyTorch (~800MB-1.5GB RAM), có thể gây giật lag trên laptop phổ thông của giáo viên.
   - `en_core_web_md` + `DependencyMatcher` + Rule XML Engine [CHỌN]: Nặng ~45MB, chạy CPU thuần cực nhanh (<150ms), khởi động tức thì, hỗ trợ 100% offline trên máy trạm của giáo viên.

4. **Tích hợp Corpus & Dataset Học thuật Chuẩn Quốc tế:**
   - Academic Collocation List (ACL) & Oxford Collocations Dictionary kết hợp ngưỡng PMI/t-score để loại bỏ các cụm ghép ngẫu nhiên (như `suffer enough`).
   - LanguageTool XML Rules cho các cấu trúc ngữ pháp phức tạp (Conditional, Relative Clauses, Inversion, Cleft Sentences, Gerunds).

## User's Direction

- **Giao diện & Xung đột:** Chọn **Phương án B (Visual Channel Separation)**. Phân tách kênh đồ họa thị giác: Cấu trúc ngữ pháp dùng viền nét đứt ngoài cùng không nền; Cụm từ Collocation dùng nền pastel xanh; Từ vựng đơn lẻ phân hóa hiển thị viền/màu trong cụm mà không đè màu lên nhau.
- **NLP & Kiến trúc Engine:** Chọn **Hướng 1 (Local Offline 100% trên máy giáo viên)**: Tối ưu bộ cài nhẹ, dùng `en_core_web_md` kết hợp `spacy.matcher.DependencyMatcher` và bộ quy tắc luật cú pháp (Grammar Rules / LanguageTool categories), độ trễ phân tích < 200ms, không phụ thuộc internet hay GPU nặng.

## Open Questions

- Định dạng xuất PDF (`pdf_annotation_exporter.dart`): Khi người dùng bấm `Highlight lên file` để in/xuất ra file PDF vật lý, cơ chế vẽ Syncfusion Graphics sẽ ánh xạ viền nét đứt (Grammar) và nền pastel (Collocation) như thế nào để giữ nguyên chuẩn thị giác tương đương trên Flutter canvas.
- Fallback Offline phía Client (Dart): Khi plugin Python Engine chưa sẵn sàng hoặc đang khởi động, bộ Matcher thuần Dart cần bổ sung thuật toán xử lý lồng ghép span tương đồng.

## Risks

1. **Hiệu năng Render trên Flutter Stack khi có nhiều Rects lồng nhau:** Việc vẽ đồng thời `CustomPaint` nét đứt và container nền bo góc cho 30-40 spans trong một đoạn văn có thể gây drop frame nếu không dùng `RepaintBoundary`.
2. **Đồng bộ hóa Tọa độ Từ (Text Normalization & Offset Alignment):** Phân tích bằng spaCy tokenization có thể trả về offset ký tự lệch 1-2 ký tự so với văn bản gốc nếu có dấu xuống dòng (`\r\n`), khoảng trắng kép hoặc ký tự đặc biệt trong PDF text layer.
