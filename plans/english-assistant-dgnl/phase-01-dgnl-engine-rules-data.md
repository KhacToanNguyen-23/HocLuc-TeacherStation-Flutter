# Phase 01: Dữ liệu Từ điển & Bộ Quy tắc Ngữ pháp spaCy

**ID:** `phase-01-dgnl-engine-rules-data`  
**Stories Covered:** P1 (Bóc tách cú pháp, Tra cứu CEFR, Quét Collocations)  
**Priority:** P1  

---

## 1. Objective
Tạo lập tập dữ liệu từ vựng CEFR dạng nhẹ (ánh xạ `(lemma, pos) -> level`), tập dữ liệu Academic Collocations List (ACL) kèm quy tắc đục lỗ distractors, và xây dựng mô-đun `grammar_rules.py` chứa các mẫu spaCy `Matcher` cho các cấu trúc phân loại trọng tâm của bài thi ĐGNL.

---

## 2. Scope & Implementation Tasks

1. **Tạo cấu trúc thư mục dữ liệu:**
   - Tạo thư mục `plugins/english_assistant/engine/data/`.
2. **Đóng gói `cefr_lexicon.json`:**
   - Xây dựng từ điển chứa hơn 5.000 từ vựng cốt lõi A1–C2 từ nguồn mở (CEFR-J / Cambridge EVP public subsets).
   - Cấu trúc: `{"ubiquitous|ADJ": "C1", "deteriorate|VERB": "B2", "address|NOUN": "A1", "address|VERB": "B2", ...}`.
3. **Đóng gói `academic_collocations.json`:**
   - Trích xuất danh mục Academic Collocation List (~2.400 cụm từ cố định học thuật).
   - Mỗi mục lưu thông tin:
     - `phrase`: ví dụ `"take into account"`
     - `mask_type`: `"preposition"` hoặc `"verb"`
     - `target_word`: `"account"`
     - `distractors`: `["mind", "view", "sight"]`
     - `explanation`: `"Cụm cố định 'take into account' = cân nhắc, xem xét."`
4. **Xây dựng `plugins/english_assistant/engine/grammar_rules.py`:**
   - Khởi tạo quy tắc Matcher cho:
     - **Inversion (Đảo ngữ phủ định):** `[Hardly/Scarcely/Seldom/Rarely/Never/No sooner] + [AUX] + [SUBJ]`.
     - **Conditional Inversion (Đảo ngữ điều kiện):** `[Should/Were/Had] + [SUBJ] + [VERB/to V]`.
     - **Participle Clause (Mệnh đề phân từ):** `[Having + VBN/VBD] + [,] + [SUBJ]`, `[VBG/VBN] + ... + [,] + [SUBJ]`.
     - **Cleft Sentence (Câu chẻ):** `[It] + [is/was] + ... + [that/who]`.
     - **Concession (Nhượng bộ):** `[No matter how/what]`, `[ADJ/ADV] + [as/though] + [SUBJ] + [VERB]`.
   - Hàm `setup_grammar_matcher(nlp)` trả về đối tượng `Matcher` đã nạp đầy đủ pattern.

---

## 3. Files & Modules Affected
- `plugins/english_assistant/engine/data/cefr_lexicon.json` (Mới)
- `plugins/english_assistant/engine/data/academic_collocations.json` (Mới)
- `plugins/english_assistant/engine/grammar_rules.py` (Mới)

---

## 4. Dependencies
- Không phụ thuộc vào phase khác.
- Yêu cầu môi trường Python hỗ trợ `spacy` (`en_core_web_sm`).

---

## 5. Tests & Acceptance Criteria
- Đọc file `cefr_lexicon.json` và `academic_collocations.json` hợp lệ, nạp vào bộ nhớ < 100ms, dung lượng < 3MB.
- `grammar_rules.py` bắt chính xác 100% các câu mẫu:
  - *"Hardly had they arrived when the rain started."* -> Bắt `INVERSION_NEG`.
  - *"Having completed the assignment, the student went home."* -> Bắt `PARTICIPLE_CLAUSE`.
  - *"It was the unprecedented crisis that challenged the government."* -> Bắt `CLEFT_SENTENCE`.
