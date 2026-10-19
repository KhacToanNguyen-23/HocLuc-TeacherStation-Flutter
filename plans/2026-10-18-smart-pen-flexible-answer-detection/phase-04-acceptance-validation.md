# Phase 04 - Acceptance, history, and regression validation

## Stories

Validates all P1/P2/P3 stories in `plans/smart-pen-flexible-answer-detection/spec.md`.

## Goal

Confirm supported fixture coverage, conservative classification, cross-page atomic state behavior, and compatibility with the existing Smart Pen, persistence, and export workflows.

## Work

- Run the labeled synthetic corpus with each intended answer marker as one positive scoring instance and each labeled distractor marker/fragment as one negative instance. Report TP/FP/FN, precision, and recall overall and per layout/category; use at least 100 positive and 100 negative instances in the versioned corpus. If recall misses the provisional target, document the specific unsupported fixture and avoid relaxing precision safeguards to hide it.
- Exercise marker hit bounds and pointer mapping at 50%, 100%, and 200% zoom and page rotations where supported.
- Verify cross-page canonical IDs and replacement/undo/redo with both persistent circles and session-only circles, including toggle changes between selections.
- Exercise page-index readiness order, page navigation, queued taps, source replacement during extraction/linking, and generation invalidation.
- Verify ordinary pen drag, blank-space tap, Smart Snap off, textless page, and existing supported layout behavior.
- Confirm lesson serialization and PDF export still contain only persisted annotations according to the existing save-answer-circles contract; verify no schema changes are introduced.
- Run required architecture test and relevant analyzer/tests after focused suites pass.

## Acceptance Tests

- Precision is >=99%; recall is reported against the >=95% target with per-layout counts. Ambiguous/negative fixtures remain rejected even when the target tradeoff is tight.
- Cross-page selection replacement and undo/redo are atomic across affected pages and do not create duplicate group circles.
- Existing freehand, Smart Snap, save-toggle, lesson round-trip, PDF export, and architecture tests pass.
- Debug mode exposes diagnostic reasons while normal production logging contains no extracted PDF text.

## Verification

From `frontend/`:

```powershell
flutter test test/smart_pen_index_test.dart test/smart_pen_annotation_test.dart test/smart_pen_gesture_test.dart
flutter test test/pdf_integration_test.dart test/handout_export_test.dart
flutter test test/architecture_test.dart
flutter analyze lib/services/smart_pen_answer_index.dart lib/models/studio_state.dart lib/widgets/pdf_stage.dart
```

## Exit Criteria

All acceptance criteria are recorded with test evidence. If a corpus target is missed, revise supported-layout claims or fixture thresholds transparently and seek product direction before making recognition more permissive.
