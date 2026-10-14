# Plan: DGNL Span Conflict Resolution & Deep Grammar NLP Pipeline

**Date:** 2026-10-14
**Mode:** --hard
**Risk:** normal — Multi-component feature spanning Flutter rendering widgets and Python plugin engine, no auth or database schema risk.
**Directory:** plans/dgnl-span-conflict-nlp/
**Spec:** plans/dgnl-span-conflict-nlp/spec.md

---

## Architecture Overview

```
                                [PDF Page Text]
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
        [FastAPI Python Engine]                 [Flutter Offline Fallback]
     spaCy en_core_web_md + Matchers             Regex & Heuristic Matchers
  (Grammar, ACL Colloc, CEFR C1/B2)         (Grammar, ACL Colloc, CEFR C1/B2)
                    │                                     │
                    └──────────────────┬──────────────────┘
                                       ▼
                       [Spatial Hierarchy Detection]
                      (Outer Grammar > Collocation > Vocab)
                                       │
                    ┌──────────────────┴──────────────────┐
                    ▼                                     ▼
       [Visual Channel Separation]             [PDF Physical Export]
    - Grammar: Dashed Border (0% fill)      - Graphics transparent rects
    - Collocation: Soft Pastel Fill (22%)   - Vector text markup annotations
    - Vocab: Hollow/Solid Pill Border       - Non-conflicting appearance stream
```

---

## Phase List

- [x] **`phase-01-visual-channel-separation`**: Triển khai giải pháp phân tách kênh đồ họa thị giác trên Flutter (`PdfDgnlPassageOverlay`), xử lý hiện tượng lồng ghép giữa Grammar, Collocation và Từ vựng B2/C1 không bị đè màu.
- [x] **`phase-02-offline-deep-grammar-engine`**: Nâng cấp Python NLP Engine (`dgnl_analyzer.py`, `grammar_rules.py`) với `DependencyMatcher` cho 6+ cấu trúc ngữ pháp trọng tâm đề thi và bộ lọc Academic Collocation List (ACL).
- [x] **`phase-03-pdf-export-and-regression-suite`**: Đồng bộ xuất vệt highlight sang `PdfAnnotationExporter` và xây dựng bộ kiểm thử tự động toàn diện (Flutter Widget + Python Engine tests).

---

## Traceability to Spec Stories

| Phase | Stories Covered | Acceptance Commands / Conditions |
| :--- | :--- | :--- |
| `phase-01-visual-channel-separation` | P1 (Visual Separation), P2 (Ghosting on filter) | `flutter test test/dgnl_snip_highlight_test.dart` pass with nested span assertions |
| `phase-02-offline-deep-grammar-engine` | P1 (Deep Grammar Offline), P2 (ACL Collocation) | `pytest plugins/english_assistant/engine/tests/` pass with >= 6 grammar rules |
| `phase-03-pdf-export-and-regression-suite` | P1 (Full Pipeline E2E), Success Criteria | All unit & integration tests pass, PDF export verification |

---

## Risks and Mitigations

- **Risk 1:** Offset lệch do ký tự đặc biệt / xuống dòng giữa spaCy tokenizer và PDF text layer.
  *Mitigation:* Dùng fuzzy substring matcher và chuẩn hóa khoảng trắng (`\s+`) khi map span offsets vào PDF coordinates.
- **Risk 2:** Tụt fps khi vẽ nhiều CustomPaint xếp chồng trên Flutter Stack.
  *Mitigation:* Bọc `RepaintBoundary` cho từng tầng và dùng `ConstrainedBox` hợp lý.

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-14 15:52
**Phase in progress:** None (All phases complete: phase-01, phase-02, phase-03)
**Status:** COMPLETE — All 3 phases verified and passing.

### Decisions made this session
- **Phase 01:** Implemented Visual Channel Separation (`PdfDgnlPassageOverlay`) with transparent outer dashed box for Grammar, pastel green fill for Collocation, and hollow crisp border for nested Vocab. Added contextual ghosting (`opacity: 0.14`).
- **Phase 02:** Upgraded offline NLP engine in `dgnl_analyzer.py` and `grammar_rules.py` with `en_core_web_md` and spaCy `DependencyMatcher` (Passive Voice, Relative Clause, Conditionals, Used to, etc.). Latency benchmarked at 68.3ms - 86.8ms. Cleaned noise like `suffer enough`.
- **Phase 03:** Added `isHollow` field & serialization to `BoardStroke` in `studio_state.dart`. Aligned `CommittedStrokesPainter` in `stroke_canvas.dart` to paint hollow strokes with outline style. Synchronized physical PDF export in `pdf_annotation_exporter.dart` (dashed pen for grammar, thin hollow pen for nested vocab, soft solid brush for collocations/standalone vocab).
- **Verification:** 9/9 Flutter tests passed in `test/dgnl_snip_highlight_test.dart`. Python tests passed (`test_rules.py`, `test_api.py`). Flutter analyze passed with 0 issues.

