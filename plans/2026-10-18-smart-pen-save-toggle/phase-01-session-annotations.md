# Phase 01 — Session-only answer annotation state and visibility

## Story

Covers **P2 — Choose whether answer circles are saved** from `plans/smart-pen-answer-snap/spec.md`.

## Goal

Create a separate session-only storage lane for Smart Pen circles that must not enter persisted annotation consumers, while rendering the active temporary selection as part of the current PDF view.

## Work

- Add a temporary Smart Pen answer-group override collection keyed by source document identity, PDF page, and group; keep `pdfAnnotations` as persisted state. Overrides must represent no override, a temporary circle, or temporary suppression of a saved circle.
- Add a query/composition method used by the PDF view to show persisted annotations plus temporary overrides. A temporary circle shadows a persisted circle and suppression hides it only in the live view; neither changes the persisted state.
- Ensure temporary entries are not included in imported-document `annotations` snapshots or any API that returns persisted annotations.
- Clear temporary entries when the PDF source is replaced/closed. Preserve them when switching away and back to a still-loaded imported document.
- Leave all ordinary `BoardStroke` rendering and persisted annotation consumers unchanged.

## Acceptance Tests

- A temporary circle appears in the effective rendered annotation list but is absent from `pdfAnnotations`.
- A temporary circle for a group with a saved circle visually replaces that saved circle; removing the temporary overlay reveals the original saved circle with unchanged geometry/metadata.
- Suppressing a saved circle hides it only in the live view; clearing suppression restores it, and the persisted annotation remains unchanged throughout.
- Page and document keys prevent overlays from appearing on another PDF page/document.
- Replacing/closing the PDF discards the temporary overlay; switching imported docs in-session and returning preserves that document's overlay.
- Existing persisted annotation and freehand stroke rendering tests continue to pass.

## Files Likely Affected

- `frontend/lib/models/studio_state.dart`
- `frontend/lib/widgets/pdf_stage.dart`
- `frontend/lib/widgets/stroke_canvas.dart`
- `frontend/test/smart_pen_annotation_test.dart`

## Verification

From `frontend/`:

```powershell
flutter test test/smart_pen_annotation_test.dart
flutter analyze lib/models/studio_state.dart lib/widgets/pdf_stage.dart lib/widgets/stroke_canvas.dart
```

## Dependencies / Exit Criteria

No dependency. Do not continue until temporary state is provably outside `pdfAnnotations` and correct rendering/document lifecycle is covered.
