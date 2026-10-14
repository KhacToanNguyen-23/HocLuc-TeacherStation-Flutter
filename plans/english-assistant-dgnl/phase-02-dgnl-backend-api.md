# Phase 02: Mở rộng FastAPI Sidecar Engine

**ID:** `phase-02-dgnl-backend-api`  
**Stories Covered:** P1 (Endpoints Phân tích ĐGNL & Tự động tạo Cloze Test)  
**Priority:** P1  

---

## 1. Objective
Tích hợp các mô-đun dữ liệu và quy tắc ngữ pháp từ Phase 01 vào `plugins/english_assistant/engine/service.py`. Cung cấp hai REST API endpoints mới:
1. `POST /api/dgnl/analyze` (Phân tích highlight đa tầng + Chỉ số sư phạm ĐGNL).
2. `POST /api/dgnl/generate-cloze` (Sinh câu hỏi trắc nghiệm đục lỗ Cloze Test).

---

## 2. Scope & Implementation Tasks

1. **Khởi tạo và nạp dữ liệu trong `service.py`:**
   - Nạp `cefr_lexicon.json` và `academic_collocations.json` vào bộ nhớ khi FastAPI khởi động.
   - Khởi tạo `PhraseMatcher` cho Academic Collocations và `Matcher` từ `grammar_rules.py`.
2. **Hiện thực logic phân tích tại `POST /api/dgnl/analyze`:**
   - **Xử lý span:** Trích xuất các vị trí `start_char`, `end_char`, phân loại `grammar`, `collocation`, `vocabulary`.
   - **Multi-layer & Priority deduplication:** Phân cấp ưu tiên `Grammar > Collocation > Vocabulary`. Nếu từ vựng nằm trong cụm collocation, lưu lại dưới dạng `sub_spans` hoặc metadata đính kèm.
   - **POS-aware CEFR lookup:** Tra cứu khóa `f"{token.lemma_.lower()}|{token.pos_}"`, nếu không có mới fallback về `token.lemma_.lower()`.
   - **Tính toán chỉ số sư phạm:**
     - Content tokens: tokens có `pos_ in ("NOUN", "VERB", "ADJ", "ADV")`.
     - `lexical_density` = `(content_words / total_words) * 100%`.
     - `cefr_profile`: Tỷ lệ % từ vựng phân bổ theo các dải `A1_B1`, `B2`, `C1_C2`.
     - `evaluation`: Đưa ra đánh giá tự động: *"Chuẩn đề ĐGNL (B2-C1: 18%)"*, *"Ngữ liệu hơi dễ (B2-C1: 8%)"*, hoặc *"Ngữ liệu mang tính học thuật cao (B2-C1: 32%)"*.
3. **Hiện thực logic sinh đề tại `POST /api/dgnl/generate-cloze`:**
   - Nhận đoạn văn bản, duyệt qua từng câu (`doc.sents`).
   - Cắt câu chứa điểm ngữ pháp hoặc cụm collocation.
   - Thay thế từ mục tiêu bằng `[ _______ ]`.
   - Lấy 3 distractors đã định nghĩa trước, kết hợp đáp án đúng, xáo trộn thành danh sách 4 lựa chọn (A, B, C, D).
   - Với từ vựng CEFR: Tạo câu hỏi đục lỗ từ vựng, nhãn từ loại và CEFR level.
   - Trả về danh sách JSON cấu trúc chuẩn `cloze_tests`.

---

## 3. Files & Modules Affected
- `plugins/english_assistant/engine/service.py` (Chỉnh sửa: thêm endpoint, router, data loading)

---

## 4. Dependencies
- Phụ thuộc vào `phase-01-dgnl-engine-rules-data` (Cần có dữ liệu và grammar matcher).

---

## 5. Tests & Acceptance Criteria
- Gửi request `POST /api/dgnl/analyze` với văn bản:
  *"Hardly had the committee made a decision when an unprecedented crisis occurred."*
  - Trả về 200 OK trong < 150ms.
  - Highlight chứa: `Grammar: Inversion` (Hardly had the committee), `Collocation` (made a decision), `CEFR C1` (unprecedented, crisis).
  - Trả về đầy đủ chỉ số `lexical_density` và `cefr_profile`.
- Gửi request `POST /api/dgnl/generate-cloze`:
  - Trả về danh sách câu hỏi trắc nghiệm đục lỗ chứa ít nhất 2 câu hỏi (1 ngữ pháp, 1 collocation).
  - Mỗi câu hỏi có đầy đủ `masked_sentence`, 4 `options`, `correct_answer`, `explanation`.
