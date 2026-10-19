# Phase 03 — Oval annotations, replacement, and undo

**Stories:** P2 undo/toggle; P2 same-question replacement; P2 natural animated oval.

## Tasks

1. Define a serializable oval representation compatible with the existing per-page PDF annotation/export model. Store deterministic, page-normalized geometry and ink style; preserve compatibility for existing freehand annotations.
2. Generate a slightly irregular hand-drawn oval around verified label bounds, with margin derived from the label geometry. Keep geometry deterministic for stable save/export and tests.
3. Render the oval in the PDF annotation overlay and animate only the path reveal. Ensure animation settles to precisely the persisted final geometry and remains legible at zoom levels.
4. Add selection behavior keyed to answer-group identity: same label toggles its oval off; another label in that group atomically removes/replaces the prior oval; distinct groups remain independent.
5. Integrate PDF oval add/remove/replace with Studio undo/redo as one atomic history operation per user action. Preserve undo/redo behavior for existing board strokes and ensure export includes final oval geometry.

## Acceptance / Verification

- Add, same-label toggle-off, and replacement each undo and redo as a single operation with no intermediate inconsistent state.
- Selecting an answer in one question does not remove circles from other questions/pages.
- Repeated generation for the same stable inputs yields identical saved oval geometry; animation changes only the rendered reveal state.
- Exported PDF contains the final oval and existing freehand annotations remain unchanged.
- Widget tests cover selection and animation completion; model tests cover serialization and history atomicity.

## Likely files

- `frontend/lib/models/board_stroke.dart` and/or `frontend/lib/models/studio_state.dart`
- `frontend/lib/widgets/pdf_stage.dart` and PDF annotation painters/overlays
- `frontend/lib/services/pdf_annotation_exporter.dart`
- New `frontend/test/smart_pen_annotation_test.dart`; extend `frontend/test/handout_export_test.dart`.

## Risks

- Existing board history may not capture mutations to per-page PDF annotation lists; prefer immutable history entries or explicit PDF annotation commands rather than mutating lists outside history.
- If extending `BoardStroke` would change persisted format or exporter assumptions, use a compatible annotation subtype/variant and add backward-compatibility tests before changing serialized fields.
