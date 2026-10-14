# Spec: Phân tích Đề thi ĐGNL & Tự động Tạo Bài tập Cloze Test (Plugin Trợ giảng Tiếng Anh)

**Date:** 2026-10-12  
**Status:** Ready  
**Plugin Target:** `plugins/english_assistant` (`com.hocluc.plugin.english`)

---

## 1. Problem Statement
Giáo viên dạy luyện thi Đánh giá Năng lực (ĐGNL) tiếng Anh (V-SAT, HSA ĐHQG Hà Nội, ĐHQG TP.HCM, ĐH Sư Phạm) mất rất nhiều thời gian để:
1. Đánh giá độ khó và mật độ từ vựng học thuật của một đoạn văn bản đọc hiểu (để biết đoạn văn có chuẩn phân hóa 15%–25% B2–C1 hay không).
2. Phát hiện thủ công các điểm ngữ pháp phân loại cao (Đảo ngữ, Mệnh đề phân từ, Cleft sentence, v.v.) và các cụm Academic Collocations.
3. Cắt từng câu, tự xóa từ khóa, tra cứu từ gây nhiễu để soạn câu hỏi trắc nghiệm đục lỗ (Cloze Test) cho học sinh luyện tập.

Giải pháp là tích hợp module **"Phân tích ĐGNL & Soạn đề Cloze"** trực tiếp vào Plugin Trợ giảng Tiếng Anh (`english_assistant`), kết hợp **spaCy** và **Tập dữ liệu mở CEFR / Academic Collocations** với thuật toán rule-based: chạy siêu tốc (<100ms), hoàn toàn offline, 0% ảo giác (hallucination), và cho phép ghim trực tiếp bài tập lên bảng vẽ điện tử của TeacherStation.

---

## 2. User Stories

### [P1] Quét & Bóc tách Đa tầng (Multi-layer Highlight & POS Disambiguation)
- **Là một** giáo viên luyện thi ĐGNL,
- **Tôi muốn** dán một đoạn văn bản và xem kết quả bóc tách ngay lập tức với hệ thống màu phân tầng trực quan:
  - Cấu trúc ngữ pháp trọng tâm: Khung viền nét đứt (dashed border) màu xanh dương.
  - Cụm Collocation học thuật: Nền màu xanh lá nhạt.
  - Từ vựng CEFR (B2, C1, C2): Bôi đậm/highlight màu vàng cam.
- **Tiêu chí chấp nhận:**
  - Thời gian xử lý dưới **200ms** cho đoạn văn 300 từ.
  - Vị trí bôi màu (`start_char`, `end_char`) khớp chuẩn xác 100% với ký tự trong văn bản gốc.
  - Tích hợp **POS-aware CEFR Lookup**: Tra cứu theo cặp `(lemma, pos)` để tránh gắn nhầm cấp độ từ vựng (ví dụ: *address* [NOUN] là A1, không bị gán nhầm sang mức B2/C1 của [VERB]).

### [P1] Bảng Chỉ số Sư phạm Đo lường Độ chuẩn Đề thi (Pedagogical Metrics)
- **Là một** giáo viên chọn ngữ liệu đề thi,
- **Tôi muốn** xem bảng chỉ số đánh giá tổng quan đoạn văn,
- **Tiêu chí chấp nhận:**
  - Hiển thị thanh tỷ lệ **Lexical Coverage & Profile**: % từ A1–B1, % từ B2, % từ C1–C2.
  - Hiển thị thước đo đánh giá: Cảnh báo trực quan nếu dải B2–C1 nằm trong khoảng chuẩn **15% – 25%** (Đạt chuẩn đề ĐGNL), dưới 15% (Quá dễ), hoặc trên 30% (Quá hàn lâm/thiên về IELTS/SAT).
  - Hiển thị chỉ số **Lexical Density** (Mật độ Content Words / Tổng từ $\times 100\%$, dải tối ưu 50% – 60%).

### [P1] Tự động Sinh Bài tập Trắc nghiệm Đục lỗ (Rule-based Cloze Test Generator)
- **Là một** giáo viên soạn bài tập củng cố,
- **Tôi muốn** chuyển sang tab "Soạn bài tập Cloze" hoặc bấm vào một điểm đặc biệt để hệ thống tự động trích xuất câu và tạo câu hỏi đục lỗ `[ ______ ]`,
- **Tiêu chí chấp nhận:**
  - **Với Collocation:** Tự động đục lỗ động từ chính (Verb) hoặc giới từ đi kèm (Preposition). Tự động sinh 3 phương án gây nhiễu (distractors) từ bộ confusable preposition/verb chuẩn hóa.
  - **Với Cấu trúc Ngữ pháp:** Tự động đục lỗ từ khóa đảo ngữ hoặc trợ động từ, sinh các phương án gây nhiễu chuẩn ngữ pháp (ví dụ: *Hardly* đi kèm *when* vs *No sooner* đi kèm *than*).
  - **Với Từ vựng CEFR B2/C1:** Tự động đục lỗ từ vựng trong câu, hiển thị nhãn CEFR/từ loại, cho phép giáo viên tùy chỉnh phương án hoặc dùng cho bài tập điền từ tự luận.
  - Có nút copy nhanh danh sách câu hỏi dạng văn bản hoặc định dạng đề thi.

### [P2] Ghim Bài tập Cloze Lên Bảng Phấn (`BoardSticker`)
- **Là một** giáo viên đang đứng lớp trực tuyến,
- **Tôi muốn** bấm nút "📌 Ghim câu hỏi lên bảng" tại một câu Cloze Test vừa tạo,
- **Tiêu chí chấp nhận:**
  - Câu trắc nghiệm lập tức xuất hiện trên bảng phấn điện tử dạng thẻ `BoardSticker` có thể tương tác (hiển thị câu hỏi, 4 phương án A-B-C-D, nút bấm chọn đáp án và hiện lời giải thích).

---

## 3. Technical Requirements

### 3.1. Backend Sidecar Extension (`plugins/english_assistant/engine/`)
- Mở rộng tệp `service.py` (FastAPI sidecar port 18888) với 2 endpoint mới:
  1. `POST /api/dgnl/analyze`:
     - **Input:** `{ "text": string }`
     - **Output:** 
       - `metrics`: `{ "total_words": int, "content_words": int, "lexical_density": float, "cefr_profile": { "A1_B1": float, "B2": float, "C1_C2": float }, "evaluation": string }`
       - `highlights`: Danh sách span `{ "start": int, "end": int, "text": string, "category": string, "level": string, "type": string, "color": string, "note": string }`
       - `sentences`: Danh sách các câu kèm thông tin tokens.
  2. `POST /api/dgnl/generate-cloze`:
     - **Input:** `{ "text": string, "selected_types": ["grammar", "collocation", "vocabulary"] }`
     - **Output:** Danh sách `{ "id": string, "original_sentence": string, "masked_sentence": string, "target_type": string, "target_word": string, "options": [string], "correct_answer": string, "explanation": string }`

### 3.2. Lexical & Rule Data (`plugins/english_assistant/engine/data/`)
- Đóng gói dữ liệu từ điển nhẹ:
  - `cefr_lexicon.json` (hoặc `.sqlite`): Gồm ~7.000 mục từ vựng gán nhãn `(lemma, pos) -> level (A1..C2)`.
  - `academic_collocations.json`: Gồm ~2.400 cụm từ trích xuất từ Academic Collocation List (ACL) kèm quy tắc đục lỗ (động từ/giới từ) và distractors tương ứng.
  - `grammar_rules.py`: Định nghĩa các spaCy `Matcher` patterns cho top các cấu trúc ĐGNL:
    - Inversion (Đảo ngữ phủ định, Đảo ngữ điều kiện).
    - Participle Clauses (Hiện tại phân từ, Quá khứ phân từ, Having + V3).
    - Cleft Sentences (It is/was ... that ...).
    - Concession Clauses (No matter how/what, Adj/Adv + as/though).

### 3.3. Plugin UI (`plugins/english_assistant/ui/`)
- Cập nhật giao diện `index.html` và `app.js`:
  - Thêm thanh chuyển tab trên đầu: **[Phân tích S-V-O & Lỗi]** và **[Ôn thi ĐGNL & Cloze Test]**.
  - Khu vực văn bản đầu vào: Ô nhập liệu nhanh kèm các nút chọn mẫu bài đọc mẫu (Sample Passages chuẩn đề ĐGNL).
  - Vùng hiển thị văn bản đa tầng: Highlight tương tác, khi di chuột hoặc click vào một điểm nổi bật sẽ hiện popup thông tin và nút **"Tạo câu hỏi từ điểm này"**.
  - Khối thống kê: Biểu đồ thanh ngang Lexical Density & CEFR Coverage có huy hiệu đánh giá chuẩn ĐGNL.
  - Tab danh sách câu hỏi Cloze Test: Xem trước câu hỏi trắc nghiệm, nút chỉnh sửa, nút sao chép đề, nút "Ghim lên bảng".

---

## 4. Success Metrics
- **Tốc độ:** Đoạn văn 300 từ trả về toàn bộ kết quả phân tích + tạo Cloze Test trong dưới **150ms**.
- **Kích thước gói:** Bộ dữ liệu từ điển CEFR và Collocations đóng gói thêm không vượt quá **5MB**.
- **Độ chính xác:** 100% tọa độ span khớp chính xác với ký tự text; các phương án distractors cho Collocation và Ngữ pháp bảo đảm 100% tính chính xác ngữ pháp tiếng Anh.
- **Tương thích:** Tích hợp mượt mà vào `english_assistant.hlep` hiện tại mà không làm hỏng các tính năng S-V-O và OCR sẵn có.
