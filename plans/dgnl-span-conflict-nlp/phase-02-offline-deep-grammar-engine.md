# Phase 02: Offline Deep Grammar Engine & Academic Collocation Filtering

**Phase ID:** `phase-02-offline-deep-grammar-engine`
**Priority:** P1
**Objective:** Nâng cấp Python NLP engine (`plugins/english_assistant/engine/`) với mô hình `en_core_web_md` và `spacy.matcher.DependencyMatcher` để phát hiện ít nhất 6 cấu trúc ngữ pháp nâng cao, đồng thời áp dụng bộ lọc Academic Collocation List (ACL) chuẩn hóa loại bỏ cụm rác.

---

## Detailed Tasks

1. **spaCy Pipeline & Model Loader:**
   - Trong `plugins/english_assistant/engine/dgnl_analyzer.py`:
     - Ưu tiên tải `spacy.load("en_core_web_md")`, nếu môi trường thiếu model `md` thì fallback mượt mà sang `en_core_web_sm` mà không làm crash server.
     - Cấu hình nlp pipe: vô hiệu hóa các pipe không cần thiết (`ner`) để tăng tốc độ phân tích lên tối đa.
2. **Deep Grammar Rules với DependencyMatcher:**
   - Trong `plugins/english_assistant/engine/grammar_rules.py`:
     - Xây dựng các mẫu cây phụ thuộc (`DependencyMatcher`) cho:
       - **Bị động (Passive Voice):** Token có quan hệ `auxpass` liên kết với Head Verb.
       - **Mệnh đề quan hệ (Relative Clause):** Head Noun liên kết với mệnh đề phụ thuộc `relcl`.
       - **Câu chẻ nhấn mạnh (Cleft Sentence):** Mẫu `It + be + [NP/PP] + that/who`.
       - **Đảo ngữ phủ định (Inversion):** Trạng từ phủ định (`hardly`, `scarcely`, `seldom`, `not until`, `no sooner`) đứng đầu câu đòi hỏi đảo trợ động từ.
       - **Cấu trúc thói quen & Dự định:** `used to + V`, `be going to + V`.
       - **Danh động từ sau giới từ & Phrasal Verbs phổ biến**.
3. **Academic Collocation List (ACL) & Noise Filtering:**
   - Cập nhật `plugins/english_assistant/engine/data/academic_collocations.json`:
     - Chỉ lưu các collocation học thuật chuẩn (Adjective + Noun, Verb + Noun, Noun + Noun).
     - Loại bỏ các cụm thông thường dễ gây nhiễu sư phạm như `suffer enough`, `delighted that`.
     - Phân loại rõ ràng cấp độ B2/C1 cho từng cụm.
4. **Offline Heuristic Matcher đồng bộ phía Flutter:**
   - Trong `frontend/lib/services/dgnl_service.dart`:
     - Đồng bộ danh mục `collocs` trong hàm `fallbackAnalyze` tương ứng với ACL của engine Python để đảm bảo tính nhất quán kể cả khi engine ngoại vi chưa kịp khởi động.

---

## Affected Files

- `plugins/english_assistant/engine/dgnl_analyzer.py`
- `plugins/english_assistant/engine/grammar_rules.py`
- `plugins/english_assistant/engine/data/academic_collocations.json`
- `frontend/lib/services/dgnl_service.dart`

---

## Dependencies

- Yêu cầu Python runtime và gói `spacy` có sẵn trong môi trường của plugin.

---

## Tests and Acceptance Criteria

- Chạy test Python: `pytest plugins/english_assistant/engine/tests/` (hoặc script test độc lập).
- Kiểm tra văn bản đề mẫu chứa:
  - `"Passive smoking is a real problem"` -> Bắt được `Passive smoking` (Collocation) và `passive` (B2).
  - `"is going to be banned"` -> Bắt được cấu trúc Bị động tương lai.
  - Cụm `suffer enough` không còn bị gán nhãn là Collocation học thuật.
- Thời gian phân tích cho một đoạn văn 200 từ: < 200ms.
