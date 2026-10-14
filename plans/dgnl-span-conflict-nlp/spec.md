# Spec: DGNL Span Conflict Resolution & Deep Grammar NLP Pipeline

**Date:** 2026-10-14
**Status:** Ready

---

## Problem Statement
Khi quét và bóc tách đa tầng một đoạn văn trên PDF, các điểm kiến thức thuộc các tầng khác nhau thường có độ dài và vị trí ký tự giao thoa hoặc lồng nhau (ví dụ: cấu trúc ngữ pháp `used to + V` bao trùm từ `used to` và `suffer`, hoặc `passive smoking` bao trùm từ vựng `smoking`). Việc vẽ nhiều khối màu đè lên nhau gây xỉn màu, che khuất chữ in và làm giảm tính sư phạm. Đồng thời, cơ chế regex đơn giản hiện tại chưa thể nhận diện được đa dạng các cấu trúc ngữ pháp phức tạp trong đề thi ĐGNL/THPT.

---

## User Stories

- **[P1]** Là một giáo viên tiếng Anh, tôi muốn các điểm ngữ pháp, cụm từ collocation và từ vựng phân hóa khi nằm lồng nhau vẫn hiển thị rõ ràng, tách bạch (ngữ pháp là khung viền ngoài, collocation là nền pastel, từ vựng giữ định dạng bên trong) để tôi giảng bài trực quan mà không bị nhòe hay đè màu.
  - *Accepted when:* Đoạn văn có `used to suffer` và `passive smoking` hiển thị cấu trúc ngữ pháp bằng khung viền nét đứt màu xanh dương, cụm collocation bằng nền pastel xanh lá, và các từ B2 bên trong không bị màu đè lẫn lộn.
- **[P1]** Là một giáo viên sử dụng ứng dụng trên laptop phổ thông, tôi muốn hệ thống phân tích ngữ pháp sâu hoàn toàn offline với độ trễ thấp (< 250ms) để việc giảng dạy diễn ra trơn tru mà không cần mạng internet hay GPU nặng.
  - *Accepted when:* Plugin English Assistant sử dụng mô hình `en_core_web_md` kết hợp `DependencyMatcher` và rule-based matching, trả về kết quả phân tích trong < 250ms cho đoạn văn 100-300 từ.
- **[P2]** Là một giáo viên, tôi muốn khi lọc riêng từng tầng (tab Ngữ pháp, Collocation, B2, C1), hệ thống chỉ tập trung nổi bật tầng tương ứng và tự động đưa các tầng khác về trạng thái làm mờ (ghosted) để học sinh tập trung tối đa vào bài giảng.
  - *Accepted when:* Bấm vào tab "Ngữ pháp (2)", chỉ 2 cấu trúc ngữ pháp giữ độ nét 100%, các span khác tự động giảm opacity về 15%.
- **[P3]** _(Out of scope cho giai đoạn này: Huấn luyện riêng mô hình Transformer tiếng Anh đề thi ĐGNL và sinh bài tập tương tác thời gian thực bằng mô hình Generative AI on-device)_.

---

## Functional Requirements

1. **FR-01: Visual Channel Separation Rendering (Phân tách Kênh Đồ họa):**
   - Tầng Ngữ pháp (`category == 'grammar'`): Render bằng khung viền nét đứt bao quanh (`CustomPaint` với `_DashedBorderPainter`), nền trong suốt hoàn toàn (`Colors.transparent`), padding mở rộng 2px ra ngoài so với chữ để bao bọc các từ con bên trong.
   - Tầng Cụm từ (`category == 'collocation'`): Render bằng khối nền mờ bo góc (`BoxDecoration` màu pastel `#86efac` với alpha 0.22 - 0.35, `borderRadius: 4.0`), không dùng gạch chân đáy phẳng.
   - Tầng Từ vựng (`category == 'vocabulary'`): Render bằng khối màu pastel ấm (`#f9e2af` cho B2, `#cba6f7` cho C1). Nếu nằm hoàn toàn trong một cụm Collocation đã có màu nền, chuyển sang chế độ viền bo mỏng tinh tế (`Border.all(color: accentColor, width: 1.0)`) để không bị hiện tượng chồng màu đục.
2. **FR-02: Span Hierarchy & Spatial Relationship Detection:**
   - Xây dựng module nhận diện quan hệ hình học/ký tự giữa các spans trong một đoạn văn: `contains(A, B)`, `overlaps(A, B)`, `disjoint(A, B)`.
   - Phân cấp ưu tiên: `Grammar (Level 1 - Container)` > `Collocation (Level 2 - Phrase)` > `CEFR C1/C2 (Level 3 - Target Vocab)` > `CEFR B2 (Level 4 - Core Vocab)`.
3. **FR-03: Offline Deep Grammar Engine (spaCy DependencyMatcher):**
   - Nâng cấp `plugins/english_assistant/engine/dgnl_analyzer.py` sử dụng `en_core_web_md`.
   - Mở rộng các luật `DependencyMatcher` cho các cấu trúc trọng tâm đề thi:
     - Passive Voice (Bị động): `auxpass` + Head Verb.
     - Relative Clause (Mệnh đề quan hệ): `relcl` + Wh-pronouns/that.
     - Cleft Sentences (Câu chẻ): `It + be + ... + that/who`.
     - Inversion (Đảo ngữ phủ định): Negative adverbial + aux inversion.
     - Conditionals (Câu điều kiện loại 1, 2, 3, đảo ngữ điều kiện).
     - Gerund after Prepositions / Phrasal Verbs.
4. **FR-04: Academic Collocation Filtering (ACL & Oxford Collocation Validation):**
   - Lọc bỏ các cụm ghép thông thường (như `suffer enough`, `delighted that`) bằng tập dữ liệu Academic Collocation List (ACL) và Oxford Collocations Dictionary đã được chuẩn hóa.
   - Chỉ giữ lại các collocations đạt tiêu chuẩn học thuật hoặc thành ngữ cố định (Idiom/Phrasal Verb).
5. **FR-05: Client-side Fallback Alignment:**
   - Cập nhật hàm `DgnlService.fallbackAnalyze` phía Flutter để áp dụng cùng quy tắc phân tách kênh thị giác và thứ tự ưu tiên khi chạy offline không có Python engine.
6. **FR-06: PDF Physical Export Alignment:**
   - Trong `PdfAnnotationExporter`: Khi xuất vệt highlight vật lý vào file PDF, cấu trúc ngữ pháp được vẽ viền nét đứt dạng đồ họa vector, cụm collocation và từ vựng được vẽ nền bán trong suốt để đảm bảo bản in/PDF xuất ra đồng nhất với màn hình Flutter.

---

## Non-Functional Requirements

- **Performance:** Thời gian phân tích văn bản (spaCy + Matchers) cho đoạn văn 300 từ đạt < 200ms trên CPU tiêu chuẩn (Intel Core i5 / AMD Ryzen 5).
- **Footprint / Resource:** Bộ cài plugin offline không vượt quá 60MB (bao gồm `en_core_web_md` và datasets JSON), bộ nhớ RAM tiêu thụ khi phân tích < 150MB.
- **Rendering Frame Rate:** Flutter Stack render 30-50 spans lồng nhau duy trì ổn định 60fps trên màn hình desktop.
- **Availability:** 100% chức năng hoạt động offline mà không cần kết nối mạng bên ngoài.

---

## Success Criteria

- [ ] Không có bất kỳ vùng ký tự nào bị hiện tượng chồng đè 2 màu nền gây đổi màu đục hoặc xỉn chữ.
- [ ] Cấu trúc ngữ pháp bao trùm (`used to suffer`, `is going to be banned`) hiển thị đường nét đứt bao bọc bên ngoài; từ vựng/collocation bên trong hiển thị sạch sẽ, chữ in đề gốc vẫn đọc rõ ràng.
- [ ] Thư viện spaCy `en_core_web_md` nhận diện chính xác ít nhất 6 dạng cấu trúc ngữ pháp trọng điểm của đề thi ĐGNL/THPT.
- [ ] Danh sách Collocation không còn nhận nhầm các cặp Động từ + Trạng từ ngẫu nhiên (như `suffer enough`).
- [ ] Đạt 100% test pass trên bộ test tự động `dgnl_snip_highlight_test.dart` và test suite phía Python engine.

---

## Out of Scope

- Không sử dụng các mô hình Transformer cồng kềnh (PyTorch / GPU) đòi hỏi cấu hình máy trạm cao.
- Không can thiệp sửa đổi nội dung văn bản gốc của file PDF.

---

## Assumptions

- Môi trường Windows của giáo viên có Python runtime nhúng sẵn kèm trong plugin bundle hoặc hệ thống có thể gọi subprocess nội bộ.
- Phía Flutter luôn có bản fallback regex/heuristic offline trong trường hợp dịch vụ nền chưa hoàn tất khởi động.
