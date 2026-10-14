# Plan: Phân tích Đề thi ĐGNL & Tự động Tạo Bài tập Cloze Test (Plugin Trợ giảng Tiếng Anh)

**Date:** 2026-10-12  
**Slug:** english-assistant-dgnl  
**Mode:** --hard  
**Risk:** normal — multi-component plugin extension (FastAPI Python sidecar + Webview UI), self-contained within plugin ecosystem.  
**Spec:** `plans/english-assistant-dgnl/spec.md`  

---

## Architecture Overview

```
[Văn bản đầu vào (Đoạn văn đọc hiểu ĐGNL)]
                       │
                       ▼
    [FastAPI Sidecar (Port 18888, service.py)]
      ├─ spaCy Pipeline (en_core_web_sm)
      │    ├─ Tokenization, POS Tagging, Dependency Parsing
      │    │
      │    ├─► 1. Grammar Rule Matcher (grammar_rules.py)
      │    │      └─ Inversion, Participles, Cleft, Concession...
      │    │
      │    ├─► 2. Academic Collocations Matcher (ACL Matcher)
      │    │      └─ PhraseMatcher 2.400 cụm học thuật + Distractor rules
      │    │
      │    └─► 3. POS-aware CEFR Lexicon Lookup
      │           └─ Tra cứu (lemma, pos) -> A1..C2 profile
      │
      ├─► [POST /api/dgnl/analyze]
      │      └─ Multi-layer Spans + Pedagogical Metrics (Coverage & Density)
      │
      └─► [POST /api/dgnl/generate-cloze]
             └─ Rule-based Cloze Test (Masking + Curated Distractors + Explanations)
                       │
                       ▼
  [Plugin UI (ui/index.html + app.js + style.css)]
      ├─ Tab "Ôn thi ĐGNL & Cloze Test"
      ├─ Multi-layer Highlight Viewer (Borders / Backgrounds / Badges)
      ├─ Pedagogical Gauge (Thước đo độ chuẩn 15%–25% B2–C1 đề ĐGNL)
      ├─ Bộ thẻ câu hỏi Cloze Test tương tác
      └─ Nút "📌 Ghim câu hỏi lên bảng phấn" (Bridge sang TeacherStation)
```

---

## Phase Roadmap

- [x] **Phase 01 — Dữ liệu Từ điển & Bộ Quy tắc Ngữ pháp spaCy (`phase-01-dgnl-engine-rules-data`)**
  - Đóng gói tập dữ liệu CEFR Lexicon (nhãn lemma + pos) và Academic Collocations List (ACL).
  - Viết bộ quy tắc `Matcher` cho các cấu trúc ngữ pháp trọng tâm đề thi ĐGNL (Đảo ngữ, Phân từ, Câu chẻ, Nhượng bộ).
  - File tác động: `plugins/english_assistant/engine/data/`, `plugins/english_assistant/engine/grammar_rules.py`.

- [x] **Phase 02 — Mở rộng FastAPI Sidecar Engine (`phase-02-dgnl-backend-api`)**
  - Hiện thực logic phân tầng ưu tiên highlight (`Grammar > Collocation > CEFR`).
  - Xây dựng thuật toán tính toán chỉ số sư phạm (Lexical Coverage A1–C2, Lexical Density).
  - Xây dựng thuật toán sinh bài tập Cloze Test rule-based với distractors an toàn cho Collocations và Ngữ pháp.
  - Cung cấp 2 endpoints mới: `/api/dgnl/analyze` và `/api/dgnl/generate-cloze`.
  - File tác động: `plugins/english_assistant/engine/service.py`, `plugins/english_assistant/engine/dgnl_analyzer.py`.

- [x] **Phase 03 — Giao diện Người dùng ĐGNL & Soạn Đề Cloze (`phase-03-dgnl-plugin-ui`)**
  - Bổ sung thanh chuyển Tab trên Plugin Header (`S-V-O & Lỗi` vs `Ôn thi ĐGNL`).
  - Render trực quan Multi-layer Highlight (khung viền cho ngữ pháp, nền cho collocation, bôi đậm cho từ vựng).
  - Hiển thị bảng chỉ số sư phạm với thước đo cảnh báo độ khó chuẩn ĐGNL.
  - Hiển thị danh sách câu hỏi trắc nghiệm đục lỗ kèm đáp án/giải thích và nút Ghim lên bảng phấn.
  - File tác động: `plugins/english_assistant/ui/index.html`, `ui/app.js`, `ui/style.css`.

- [x] **Phase 04 — Đóng gói Plugin .hlep & Kiểm thử Hoàn thiện (`phase-04-packaging-verification`)**
  - Cập nhật `manifest.json` lên phiên bản `1.1.0`.
  - Kiểm thử hiệu năng (<150ms cho đoạn văn 300 từ) và cơ chế fallback offline trong UI khi không bật Python.
  - Kiểm thử tương tác ghim câu hỏi Cloze lên bảng phấn (`INSERT_ANNOTATION`).
  - Đóng gói file `english_assistant.hlep` hoàn chỉnh.
  - File tác động: `plugins/english_assistant/manifest.json`, `plugins/english_assistant.hlep`.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-13 00:52
**Phase in progress:** All Phases Completed (01, 02, 03, 04)
**Status:** Feature fully cooked and verified. All 4 phases passing.

### Decisions made this session
- Updated `manifest.json` version to 1.1.0 and packaged into `plugins/english_assistant.hlep`.
- Executed both Python test suites (`test_rules.py` and `test_api.py`) with 100% pass and latency 32ms.
- Executed Flutter test suite (`english_assistant_e2e_test.dart`) and `flutter analyze lib/` with 0 issues.

### Next immediate action
- Code review verification and finalize git commit.


---

## Risks and Mitigations

1. **Dung lượng file dữ liệu:**
   - *Rủi ro:* Dữ liệu từ điển làm phình to gói plugin.
   - *Giải pháp:* Tinh gọn tập dữ liệu CEFR chỉ lưu các từ B1–C2 và các từ A1–A2 thông dụng có đa từ loại; tối ưu JSON/SQLite dưới 4MB.
2. **Xung đột khi nhiều span trùng nhau hoàn toàn:**
   - *Rủi ro:* Trình duyệt render bị lỗi thẻ HTML lồng nhau không hợp lệ.
   - *Giải pháp:* Tiền xử lý gộp span ở Python backend: gán span cha và nhúng danh sách `sub_spans` vào metadata, frontend dùng renderer dạng phân đoạn (text chunks) an toàn.
