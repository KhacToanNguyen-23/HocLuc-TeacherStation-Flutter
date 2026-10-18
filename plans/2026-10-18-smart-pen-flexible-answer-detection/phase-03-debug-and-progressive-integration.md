# Phase 03 - Debug diagnostics and progressive integration

## Stories

Covers **P2 - Diagnose missed labels** and **P3 - Retain progressive indexing**.

## Goal

Make classifier and linker decisions inspectable during explicit debug runs, and expose cross-page links as neighboring page indexes become ready without delaying current-page Smart Snap.

## Work

- Extend the existing `SMART_PEN_DEBUG` overlay to render raw extracted fragments and their bounds separately from accepted candidates.
- Add visually distinct accepted, rejected, partial-edge, linked, and unlinked statuses, with a short reason code for candidate and linker decisions.
- Keep text rendering behind the debug compile-time flag; do not log PDF text in normal or debug production logging.
- Connect the adjacent-page linker to the current serial visible-page-first scheduler/store. Recompute only links affected by a newly ready adjacent index, and refresh candidates without losing active user selection or queued-tap page identity.
- Keep a visible page locally usable while its neighbor is pending. Guard link refreshes and overlay state by document generation.
- Document how to enable debug mode and interpret extraction-versus-classifier-versus-linker states in developer notes or test output.

## Acceptance Tests

- With `SMART_PEN_DEBUG` enabled, test/widget output distinguishes raw fragment extraction, candidate acceptance/rejection, and adjacent-page link decisions with concise reasons.
- Without the flag, no text-debug layer or PDF-text logging is present; normal Smart Pen UI remains unchanged.
- A current-page candidate can be tapped before a neighbor index completes; a later valid link makes replacement group-aware without creating duplicate circles.
- Changing pages reprioritizes indexing according to the existing policy, and stale link completion after document replacement is ignored.

## Likely Files

- `frontend/lib/widgets/pdf_stage.dart`
- `frontend/lib/services/smart_pen_answer_index.dart`
- `frontend/test/smart_pen_index_test.dart`
- `frontend/test/smart_pen_gesture_test.dart`

## Verification

```powershell
flutter test test/smart_pen_index_test.dart test/smart_pen_gesture_test.dart
flutter analyze lib/widgets/pdf_stage.dart lib/services/smart_pen_answer_index.dart
```

## Dependencies / Exit Criteria

Depends on the marker candidate API from Phase 01 and linker API from Phase 02. Current-page behavior must remain available throughout neighbor indexing.
