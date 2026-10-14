# Brainstorm: Tích hợp Module Phân tích Đề thi Đánh giá Năng lực (ĐGNL) & Tự động tạo Cloze Test vào Plugin Trợ giảng Tiếng Anh

**Date:** 2026-10-12  
**Slug:** english-assistant-dgnl  
**Plugin Target:** `plugins/english_assistant` (`com.hocluc.plugin.english`)

---

## Ideas Explored

1. **Sinh câu hỏi & phân tích bằng LLM API (OpenAI/Gemini):**
   - *Đánh giá:* Linh hoạt trong diễn đạt nhưng chậm (1–3s), tốn chi phí token, phụ thuộc internet và dễ bị "ảo giác" (hallucination) làm lệch vị trí ký tự span khi highlight trên văn bản. *Đã loại bỏ.*
2. **Công cụ tách biệt (Standalone Plugin mới hoàn toàn):**
   - *Đánh giá:* Tạo một plugin riêng biệt độc lập (`com.hocluc.plugin.dgnl_english`). Nhược điểm là phải khởi chạy thêm 1 tiến trình Python sidecar riêng, tốn thêm RAM và phân mảnh trải nghiệm của giáo viên. *Đã thống nhất gộp vào plugin hiện có.*
3. **Mô hình kết hợp Rule-based spaCy + Tập dữ liệu mở CEFR/Collocations:**
   - *Đánh giá:* Xử lý trong vài chục mili-giây, hoàn toàn offline, 0 chi phí token, vị trí ký tự (`start_char`, `end_char`) chính xác 100%. Được chọn làm giải pháp cốt lõi.
4. **Sinh đáp án gây nhiễu (Distractors) ngẫu nhiên cho từ vựng đơn lẻ:**
   - *Đánh giá:* Lấy ngẫu nhiên từ cùng POS/CEFR từ CSDL có rủi ro từ được chọn vẫn vô tình đúng ngữ cảnh hoặc là từ đồng nghĩa. *Đã thống nhất ưu tiên sinh đáp án tự động chuẩn xác cho Collocation và Ngữ pháp trước; từ vựng CEFR hỗ trợ đục lỗ câu (Cloze blank) và cho phép giáo viên tùy chỉnh.*

---

## User's Direction

- **Kiến trúc tích hợp:** Tích hợp trực tiếp chức năng mới vào plugin `english_assistant` hiện có trong `plugins/english_assistant`, chia sẻ chung tiến trình Python FastAPI sidecar (`engine/service.py`) và nạp thêm mô-đun CEFR/Collocation.
- **Xử lý chồng lấn Span (Overlapping Spans):** Áp dụng mô hình **Multi-layer Hierarchy** trên giao diện:
  - Cấu trúc ngữ pháp trọng tâm: Khung viền (border) / gạch chân nét đứt (dashed underline).
  - Cụm Collocation học thuật: Đổ nền màu dịu (xanh lá nhạt).
  - Từ vựng CEFR (B2–C1): Bôi đậm / highlight màu chữ/màu nền cam.
  - Phân cấp ưu tiên dữ liệu: $\text{Grammar} > \text{Academic Collocation} > \text{Single CEFR Lemma}$.
- **Khử nhập nhằng từ loại (POS-aware Disambiguation):** Tra cứu CEFR theo khóa kép `(lemma, pos)` dựa trên nhãn POS của spaCy để loại bỏ hoàn toàn các trường hợp báo động giả (như *address* danh từ A1 vs động từ B2/C1).
- **Chỉ số sư phạm tổng quan (Pedagogical Metrics):**
  - **Lexical Coverage & Profile:** Đo lường tỷ lệ phân bố từ vựng theo dải A1–B1, B2, C1–C2. Chuẩn hóa theo ngưỡng đề ĐGNL (15% – 25% B2–C1 là lý tưởng).
  - **Lexical Density:** Tỷ lệ Content Words / Tổng số từ (ngưỡng tối ưu 50% – 60%).
- **Rule-based Cloze Test Generation (Ưu tiên 1):**
  - Tập trung tạo câu hỏi trắc nghiệm đục lỗ tự động chuẩn xác 100% cho **Collocations** (đục động từ chính hoặc đục giới từ) và **Cấu trúc ngữ pháp trọng tâm** (đục từ khóa đảo ngữ, trợ động từ).
  - Sinh 3 phương án gây nhiễu (distractors) từ danh mục cố định đã được kiểm định (confusable preposition / adverb / verb sets), bảo đảm không có tranh cãi về đáp án.
  - Từ vựng CEFR B2/C1 hỗ trợ cắt câu đục lỗ, cung cấp định nghĩa/nhãn cấp độ để giáo viên soạn đề tự luận hoặc bổ sung distractors.

---

## Open Questions

1. **Bộ dữ liệu từ vựng & Collocation đóng gói:**
   - Nguồn dữ liệu CEFR: Sử dụng CEFR-J / Octanove CEFR List dạng SQLite/JSON nén (~2-4MB).
   - Nguồn Collocation: Academic Collocation List (ACL - 2.469 cụm) đóng gói trong `engine/data/`.
2. **Cơ chế ghim bài tập lên bảng vẽ (`BoardSticker`):**
   - Phiên bản hiện tại của plugin đã có action `INSERT_ANNOTATION`. Cần xác định cấu trúc dữ liệu mới khi giáo viên bấm "Ghim câu hỏi Cloze lên bảng" để học sinh làm bài trực tiếp trong lớp học ảo.

---

## Risks

1. **Dung lượng gói `.hlep` khi đóng gói thêm database từ điển:**
   - *Giải pháp:* Dùng SQLite hoặc tệp JSON tối ưu hóa chỉ lưu các từ B1–C2 kèm POS, giữ dung lượng dưới 5MB.
2. **Độ bao phủ của Rule-based Matcher cho ngữ pháp:**
   - Các câu quá dài hoặc có nhiều mệnh đề chen ngang (parenthetical clauses) có thể làm giảm độ nhạy của `Matcher`.
   - *Giải pháp:* Thiết kế mẫu Pattern linh hoạt có khoảng cách token (`OP: "*"` hoặc `{"IS_PUNCT": True, "OP": "?"}`) cho top 10 cấu trúc thường gặp nhất trong đề thi ĐGNL (Đảo ngữ, Mệnh đề phân từ, Cleft sentence, Câu điều kiện hỗn hợp, Giả định cách).
