# Phase 03 — Persistence/export boundaries and acceptance validation

## Story

Covers **P2 — Choose whether answer circles are saved** from `plans/smart-pen-answer-snap/spec.md`.

## Goal

Prove that only persisted annotations are serialized and exported, including secondary PDF-export entry points and legacy lesson restoration.

## Work

- Audit every `pdfAnnotations` consumer: lesson JSON, restore, imported-document snapshot/copy, PDF painting, export availability, and ink export. Keep temporary storage outside these paths.
- Add tests for lesson export/reopen and PDF export. Assert temporary circles are absent while normal persisted circles and freehand strokes remain present.
- Test export availability: a temporary-only circle must not cause the app to offer/save an annotated PDF; persisted annotation availability remains unchanged.
- Verify legacy JSON without a new toggle/provenance key treats existing Smart Pen circles as persisted and restores the runtime toggle default to enabled.
- Verify temporary circles are discarded on PDF close/replacement, including undo/redo history cleanup.
- Verify temporary overlays and suppressions do not enter `activeDoc.annotations` during document switching and are discarded when their imported document is removed or replaced.

## Acceptance Tests

- Save/reopen after creating a temporary circle does not restore it.
- Exported PDF from a temporary-only session contains no circle overlay; a previously persisted circle still exports as before when a temporary choice is active.
- PDF export can still be initiated for persisted annotations, and temporary-only annotations do not trigger the persisted-annotation availability branch.
- Legacy lesson data containing `pdfAnnotations` with Smart Pen metadata restores and exports those circles unchanged.
- Switching between imported documents does not copy temporary circles/suppressions into either document's persisted annotations; removing or replacing a document clears its session-only overrides and associated undo/redo history.
- Ordinary ink annotations and freehand paths round-trip and export unchanged.
- Required architecture test passes.

## Files Likely Affected

- `frontend/lib/models/studio_state.dart`
- `frontend/lib/services/pdf_annotation_exporter.dart` (only if an explicit persisted-only API is needed; prefer no exporter change when the storage boundary is clean)
- `frontend/test/smart_pen_annotation_test.dart`
- `frontend/test/pdf_integration_test.dart` or a focused PDF export test

## Verification

From `frontend/`:

```powershell
flutter test test/smart_pen_annotation_test.dart
flutter test test/pdf_integration_test.dart test/handout_export_test.dart
flutter test test/architecture_test.dart
flutter analyze lib/models/studio_state.dart lib/services/pdf_annotation_exporter.dart
```

## Dependencies / Exit Criteria

Depends on Phase 02. Finish only after lesson/PDF tests cover both temporary-only and mixed persisted/temporary state, and architecture verification passes.
