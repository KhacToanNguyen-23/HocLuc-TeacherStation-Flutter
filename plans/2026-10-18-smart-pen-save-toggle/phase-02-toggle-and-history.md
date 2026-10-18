# Phase 02 — Toggle, routing, and undo semantics

## Story

Covers **P2 — Choose whether answer circles are saved** from `plans/smart-pen-answer-snap/spec.md`.

## Goal

Expose the agreed default-on control and route each newly created answer circle to persisted or session-only storage without changing existing gesture detection.

## Work

- Add a runtime save-answer-circles setting to `StudioState`, initialized to `true`; do not include it in lesson serialization.
- Add the control beside Smart Snap in both vertical and horizontal branches of `StudioDrawingToolbar`, with clear tooltip and active state.
- Route creation based on the setting at the moment the oval is created. Existing saved ovals stay persisted when the setting changes. Temporary ovals stay temporary when saving turns back on.
- Extend Smart Pen undo/redo entries to store atomic before/after snapshots for both the persisted group and its temporary override state (none, temporary circle, or suppression). A temporary answer group shadows or suppresses an old persisted answer only in-session.
- Keep notifications and visible undo behavior for temporary edits. Mark lesson dirty and invoke persistence only when the operation changes persisted data; preserve an already-dirty lesson state during temporary-only operations.
- When a save-enabled selection replaces a group, retain the existing behavior of replacing the persisted selection and clear any temporary overlay for that group.

## Acceptance Tests

- Fresh Studio state has save-answer-circles enabled; setting it on/off does not change Smart Snap state.
- Both toolbar layouts expose and update the setting.
- Saving on persists new ovals and sets dirty as before.
- Saving off creates visible/undoable temporary ovals only; a previously clean lesson remains clean, and an already dirty lesson stays dirty.
- Off-to-on does not move or serialize earlier temporary ovals; the next circle is persisted.
- Toggle changes alone do not add/remove/alter saved circles.
- Undo/redo across a persisted circle and temporary overlay restores the expected displayed state and persistent backing data.
- Undo/redo through saved A → save-off temporary B → save-on persisted C restores saved A plus temporary B on undo and persisted C with no override on redo.
- With save off and a saved A, tapping A suppresses it only in-session; tapping A again restores it without changing lesson/export data.

## Files Likely Affected

- `frontend/lib/models/studio_state.dart`
- `frontend/lib/widgets/studio/studio_drawing_toolbar.dart`
- `frontend/lib/widgets/pdf_stage.dart`
- `frontend/test/smart_pen_annotation_test.dart`
- `frontend/test/smart_pen_gesture_test.dart`

## Verification

From `frontend/`:

```powershell
flutter test test/smart_pen_annotation_test.dart
flutter test test/smart_pen_gesture_test.dart
flutter analyze lib/models/studio_state.dart lib/widgets/studio/studio_drawing_toolbar.dart lib/widgets/pdf_stage.dart
```

Extend the existing Smart Pen toolbar coverage in `smart_pen_gesture_test.dart` to assert the save toggle in both layouts; do not depend on a nonexistent standalone toolbar test file.

## Dependencies / Exit Criteria

Depends on Phase 01. Do not continue until route-at-creation, group undo/redo, and dirty-state semantics are covered.
