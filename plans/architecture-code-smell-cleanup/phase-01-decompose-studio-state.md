# Phase 01: Phân Rã God Object `studio_state.dart` (2,112 dòng)

- **Covers:** Story 1 (P1) — Phân rã God Object `studio_state.dart` theo miền nghiệp vụ
- **Target Files:**
  - `frontend/lib/models/studio_state.dart` (Giảm từ `2,112 dòng` xuống `<850 dòng`)
  - `frontend/lib/models/studio_board_models.dart` (Mới — ~235 dòng: `StudioViewportMode`, `PdfDgnlHighlightSpan`, `PdfDgnlPassage`, `BoardStroke`, `ImportedDocument`)
  - `frontend/lib/models/studio_state_plugins.dart` (Mới — ~365 dòng: Quản lý Plugin, `openPlugin`, `closePlugin`, `closeFloatingPlugin`, `highlightPdfPassageFromAnalysis`, `startSnipping`, `handlePluginMessage`)
  - `frontend/lib/models/studio_state_annotations.dart` (Mới — ~500 dòng: Quản lý `BoardSticker`, `SmartChalkAnnotation`, `analyzeHandwritingAt`, `analyzeHandwritingWithVerifiedText`, `_refineAnnotationWithOcr`, `analyzePdfSentenceAt`, `addTypedChalkAnnotation`)

## Các Bước Thực Hiện
1. Tạo `frontend/lib/models/studio_board_models.dart` với `part of 'studio_state.dart';` chứa toàn bộ các kiểu dữ liệu (`StudioViewportMode`, `PdfDgnlHighlightSpan`, `PdfDgnlPassage`, `BoardStroke`, `ImportedDocument`).
2. Tạo `frontend/lib/models/studio_state_plugins.dart` với `part of 'studio_state.dart';` chứa `extension StudioStatePluginsExt on StudioState` cho toàn bộ phương thức điều khiển Plugin, DGNL highlight và Snipping.
3. Tạo `frontend/lib/models/studio_state_annotations.dart` với `part of 'studio_state.dart';` chứa `extension StudioStateAnnotationsExt on StudioState` cho toàn bộ phương thức xử lý Sticker, SmartChalk S-V-O-A và OCR.
4. Khai báo `part 'studio_board_models.dart';`, `part 'studio_state_plugins.dart';`, `part 'studio_state_annotations.dart';` trong `studio_state.dart`.

## Tiêu Chí Nghiệm Thu (Verification)
- `flutter analyze --no-fatal-infos lib/models/studio_state.dart` đạt 0 lỗi.
- `flutter test test/studio_test.dart test/hybrid_svo_ocr_test.dart test/casio_calculator_e2e_test.dart` pass 100%.

