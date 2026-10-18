# Plan: Smart Pen answer-circle saving toggle

- Date: 2026-10-18
- Mode: --hard
- Risk: high-risk — changes PDF annotation lifecycle, lesson serialization, and exported PDF content
- Spec: `plans/smart-pen-answer-snap/spec.md`
- Scope: implement FR-12 only; Smart Pen indexing, gesture routing, oval rendering, answer replacement, and baseline undo are already implemented in `plans/2026-10-17-smart-pen-answer-snap/`.
- Status: All three phases implemented, verified, and reviewed

## Goal

Add a save-answer-circles toggle beside Smart Snap. It defaults on. New circles created with saving off remain visible and undoable for the current PDF session but are omitted from lesson JSON and exported PDF. Turning the toggle off must not change existing persisted circles. Turning it back on does not promote temporary circles retroactively. Ordinary pen strokes and existing persisted circles retain current behavior.

## Scope Challenge

- Exists? Smart Snap and PDF annotation save/export already exist; the save toggle does not.
- Minimum? Isolate only newly created non-persistent circles from persisted PDF annotations and expose the agreed toggle in both toolbar layouts.
- Complexity? Hard: persistence leaks or accidental deletion can change saved lesson/PDF content.

## Spec Stories

- **P2 — Choose whether answer circles are saved:** deliver the save toggle, its default-on behavior, session-only visible/undoable circles while off, no lesson/PDF persistence while off, and preservation of prior saved circles.

## Existing Architecture and Research Findings

- `StudioState.toggleSmartPenAnswer` currently adds/replaces `BoardStroke` entries in `pdfAnnotations` and marks `dirty = true`.
- `pdfAnnotations` is the common source for PDF rendering, imported-document snapshots, lesson `exportLessonJson` / `restoreFromJson`, PDF annotation painting, and export availability checks.
- `PdfAnnotationExporter` iterates `pdfAnnotations` for painting and uses it to decide whether an annotated PDF can be saved.
- The Smart Pen history is already document-keyed and undoable. The two toolbar layouts are in `studio_drawing_toolbar.dart`.
- The shared list makes a persisted flag plus filters possible, but every consumer and copy/switch path would need correct filtering. A missed consumer could leak temporary circles into a lesson or PDF.

## Recommended Design

Keep `pdfAnnotations` as the persisted source of truth, and add a separate document/page-keyed session-only collection for Smart Pen circles created while saving is off. The renderer composes the visible page from persisted strokes and active temporary Smart Pen overrides; lesson serialization, document snapshots, and PDF export continue to consume only `pdfAnnotations`. This fails closed for persistence: no temporary data reaches existing serialization/export paths unless code explicitly merges it.

For answer-group replacement, session-only state is a group override with three states: no override, temporary circle, or temporary suppression. A temporary circle visually supersedes that group's persisted circle for the current session while leaving the persisted circle untouched in storage/export. Tapping the temporary circle again clears its override and reveals the persisted circle. While saving is off, tapping the persisted answer when there is no override sets temporary suppression: the saved circle is hidden only for the current session and remains in lesson data/PDF export; tapping it again clears suppression. Selecting the persisted answer while a different temporary circle is active clears that override and reveals the saved answer. Re-selecting a different answer with saving on performs the existing persisted replacement and clears the group's temporary override. Temporary circles and suppressions created while off remain temporary after the toggle turns on; they are never implicitly promoted.

Undo/redo records one atomic before/after snapshot for the selected answer group across both lanes: the persisted group's circle state and the session override state (none, temporary circle, or suppression). This preserves sequences that cross the toggle boundary, such as saved A → temporary B → persisted C: undoing C restores saved A plus temporary B, and redoing C restores persisted C with no override.

The toggle is a runtime preference, defaults to `true`, is independent of Smart Snap, and is not itself lesson data. Temporary-only edits notify the UI and update Smart Pen undo history but do not set the lesson dirty flag or trigger autosave. If the lesson is already dirty, a temporary operation must not clear that state. Persistent operations retain current dirty/save behavior. Closing/replacing the source PDF clears temporary state and its history; switching imported documents preserves it only while that source document remains open in the current session.

## Phases

1. [x] **Phase 01 — Session-only answer annotation state and visibility** (P2 save-choice story): introduce temporary Smart Pen annotation storage keyed by source document and page; expose an effective visible-annotation composition that shadows a persisted circle only for the same answer group; clear temporary state on PDF replacement/close; preserve current rendering for all other annotations. See `phase-01-session-annotations.md`.
2. [x] **Phase 02 — Toggle, routing, and undo semantics** (P2 save-choice story): add default-on state and control in horizontal and vertical toolbars; route only newly created ovals according to toggle state; extend existing group undo/redo across persisted and temporary lanes; maintain dirty/autosave behavior according to whether persisted content changed. See `phase-02-toggle-and-history.md`.
3. [x] **Phase 03 — Persistence/export boundaries and acceptance validation** (P2 save-choice story): keep lesson JSON, imported-document snapshots, and all PDF export paths restricted to persisted annotations; verify behavior through save/reopen and PDF byte/render checks; validate legacy JSON and freehand compatibility. See `phase-03-persistence-validation.md`.

## Acceptance Criteria

- Default state is enabled on a fresh Studio session; toggle is visible beside Smart Snap in both responsive toolbar layouts and changes independently of Smart Snap.
- With saving enabled, new Smart Pen circles follow the existing behavior: they remain in `pdfAnnotations`, set the lesson dirty state, survive lesson export/restore, and are painted into PDF export.
- With saving disabled, new circles render and undo/redo during the active PDF session, but do not appear in `pdfAnnotations`, lesson JSON, imported-document persisted snapshots, export annotations, or export-availability checks.
- Temporary-only create/undo/redo does not set a previously clean lesson dirty; it never clears an already dirty lesson state.
- Turning the toggle off leaves existing persisted circles present in lesson JSON and PDF export. A temporary same-question choice can visually supersede one in-session; removing/undoing that temporary choice reveals the persisted circle again.
- Turning the toggle on leaves prior temporary circles temporary. Subsequent new circles are persisted.
- Existing saved circles and freehand PDF/board strokes round-trip and export exactly as before.
- Legacy lesson JSON with no new toggle or provenance field restores all existing annotations as persisted. The runtime toggle still starts enabled.
- Closing or replacing the PDF discards temporary circles; switching away from and back to an imported document during the same open session retains its temporary circles if that document remains loaded.
- With an existing saved answer A, saving off and tapping A temporarily suppresses it in the live view only; lesson data and exported PDF continue to contain saved A. Tapping A again restores its live visibility.
- Sequence saved A → saving off/select B → saving on/select C: undo restores persisted A plus temporary B; redo restores persisted C with no temporary override.
- Removing an imported document also removes its session-only circles and Smart Pen history; switching documents must not copy temporary state into `ImportedDocument.annotations`.

## Risks and Decisions

- **Persistence leak:** PDF painting and availability checks are separate from lesson JSON serialization. Preserve a hard storage boundary and test every consumer, including imported-document copy/switch flows.
- **Selection replacement ambiguity:** A temporary answer selection or suppression can change the current view while the export intentionally retains the old persisted selection. Keep both override states explicit and test reveal-on-clear/undo; do not mutate the persisted group for save-off actions.
- **Undo ordering:** Existing Smart Pen history snapshots only the persisted group. Extend each history entry to capture both persisted and session override state atomically, then test undo/redo across operations made with saving on and off; ensure ordinary undo ordering remains coherent.
- **Dirty state/autosave:** Temporary changes are visible but not saveable. Avoid marking a clean lesson dirty or scheduling a save for them, while preserving any pre-existing dirty state.
- **Document identity:** Resolve identity from active imported document ID when present, otherwise the PDF source identity/generation. Clear entries on replacement to prevent cross-document leakage.
- **Toggle scope:** It controls future creation only; it does not alter already persisted circles and is not serialized as lesson configuration.

## Verification Plan (planned; not run during planning)

Run focused annotation and exporter coverage, then the required architecture test. Commands are from `frontend/`:

```powershell
flutter test test/smart_pen_annotation_test.dart
flutter test test/pdf_integration_test.dart test/handout_export_test.dart
flutter test test/architecture_test.dart
flutter analyze lib/models/studio_state.dart lib/models/board_stroke.dart lib/widgets/pdf_stage.dart lib/widgets/stroke_canvas.dart lib/widgets/studio/studio_drawing_toolbar.dart lib/services/pdf_annotation_exporter.dart
```

Add the save-toggle cases to existing tests where practical; create a focused exporter test only if current exporter fixtures cannot assert that temporary overlays are absent. Do not start by broadening the Smart Pen classifier/gesture test suite: those phases are complete and outside scope.

## Implementation Constraints

- Do not change the existing Smart Snap toggle's behavior or the pen gesture classifier.
- Do not serialize the save-toggle runtime setting.
- Do not store transient circles in a structure copied by `exportLessonJson`, imported-document persistence, or `PdfAnnotationExporter`.
- Keep ordinary pen strokes and all non-Smart-Pen annotations on their current code paths.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-18 16:08
**Phase in progress:** complete
**Status:** All phases passed targeted tests, static analysis, architecture verification, and code review.

### Decisions made this session
- Temporary answer circles and suppressions are stored outside `pdfAnnotations`, keyed by current source document, page, and answer group.
- The PDF renderer receives an effective annotation list while gesture mutations continue targeting persisted annotations.
- Replacing one PDF clears temporary state for that PDF only; other loaded documents retain their session overlays.
- Save completion compares serialized lesson and config snapshots so temporary-only edits during an in-flight save do not dirty the lesson, while persisted changes during save remain dirty.
- Lesson restoration clears session-only overrides and Smart Pen history even if the incoming lesson has no PDF path; replacing one PDF clears only that document's temporary state and history.

### Next immediate action
No remaining implementation work.
