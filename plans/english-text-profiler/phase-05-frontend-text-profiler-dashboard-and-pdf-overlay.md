# Phase 05: Frontend Text Profiler Dashboard & PDF Overlay

## Objective
Design and build the interactive Text Profiler Dashboard UI dialog and integrate 6-level CEFR highlighting and word inspection into the PDF passage overlay.

## Scope
- Create `TextProfilerDialog` in `frontend/lib/features/studio_board/presentation/widgets/text_profiler_dialog.dart`:
  - Tabbed dashboard:
    1. Tổng quan (Overview with grade gauge, difficulty badge, key numbers)
    2. Phân bố CEFR (A1–C2 interactive bar charts, percentages, legend)
    3. Độ khó Đọc hiểu (6 Readability metrics with expandable details, formulas, and limitations)
    4. Đa dạng Từ vựng (TTR, MATTR, MTLD, Academic tokens, frequent words)
    5. Độ phức tạp Cú pháp (Sentence distribution, clause patterns, passives)
    6. Độ bao phủ & Cần dạy trước (K1–K3 coverage, pre-teach vocabulary chips)
    7. Khuyến nghị Sư phạm (Actionable teacher checklist)
    8. Đối chiếu Đề thi (VSTEP B1/B2/C1 & ĐGNL readiness)
  - Glassmorphic styling consistent with Học Lực design system (`LiquidGlassContainer`, `AppTheme`).
- Update `pdf_dgnl_passage_overlay.dart` and `pdf_dgnl_passage_dialogs.dart`:
  - Add "Hồ sơ độ khó" (Text Profiler) button to passage header bar.
  - Support full 6-level CEFR filtering chips (A1, A2, B1, B2, C1, C2).
  - Add Word Inspection dialog/tooltip when clicking individual words (showing Lemma, CEFR Level, POS, and context).

## Affected Files
- `frontend/lib/features/studio_board/presentation/widgets/text_profiler_dialog.dart`
- `frontend/lib/features/studio_board/presentation/pdf_dgnl_passage_overlay.dart`
- `frontend/lib/features/studio_board/presentation/pdf_dgnl_passage_dialogs.dart`
- `frontend/lib/features/studio_board/services/dgnl_service.dart`

## Tests / Acceptance Criteria
- Teacher can click "Hồ sơ độ khó" from any scanned PDF passage and view the full profiler dashboard.
- Highlights on the PDF maintain exact alignment and zoom responsiveness.
- All 6 CEFR levels filter correctly on the overlay.

