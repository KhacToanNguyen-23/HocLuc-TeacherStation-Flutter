# Phase 02 - Adjacent-page group linker and canonical selection IDs

## Story

Covers **P1 - Link choices across adjacent pages**.

## Goal

Link only high-confidence continuations across adjacent pages and make current answer replacement and history operate atomically across the complete linked group.

## Work

- Add a document-scoped linker consuming ready page indexes and their edge partial groups. Restrict proposals to adjacent page numbers in the same PDF generation.
- Require a unique mutual match with complementary expected label order, edge proximity, compatible row/column arrangement, and no new question-heading evidence. Keep uncertain or duplicate-label matches separate.
- Create stable canonical group IDs from document generation plus stable group anchors/membership; avoid page-local ordinal collisions and avoid changing IDs merely because a distant page was indexed.
- Reconcile selections created before the neighbor index was ready: retain a document-scoped alias from the provisional local group ID to the canonical linked ID, migrate/rekey the existing answer-circle metadata and selection state without duplicating circles, and preserve the alias for history replay. Undo entries must restore the exact pre-link selection/page state; redo and subsequent selections must resolve through the canonical ID.
- Preserve page-local spatial hit testing, but resolve each eligible candidate through the canonical group map at tap time.
- Integrate linker output with existing `StudioState` answer selection. Verify that selecting on either page replaces the prior circle across pages and same-label taps toggle the correct selection.
- Ensure one cross-page selection action snapshots every affected page's persisted and temporary state in a single undo/redo entry. Reuse existing group-history machinery where possible; change it only if focused regression tests demonstrate a gap.
- Invalidate link and ID maps when PDF bytes/source generation changes; ignore stale asynchronous extraction/link results.

## Acceptance Tests

- A generated A/B then C/D page-break fixture becomes one group with a stable canonical ID. Selecting D on page two after A on page one leaves only D; selecting A afterward removes the old-page D circle.
- The cross-page replacement produces one undo entry. Undo restores the original selection on its original page; redo restores the replacement. Test both persisted and temporary answer-circle lanes.
- Discontinuous page labels, a new question heading, non-edge groups, duplicate/competing partial groups, and ties do not link.
- Indexing the same pages in different readiness orders produces the same canonical IDs for the same document generation.
- Ordering race: select an answer on page one while page two is unindexed; finish page-two indexing and link the groups; select the page-two answer; assert one circle remains. Undo restores the original page-one circle and redo restores the page-two circle, with no duplicate annotations.
- Replacing the source PDF while a neighbor index/link is pending cannot mutate the new document's groups or selections.

## Likely Files

- `frontend/lib/services/smart_pen_answer_index.dart` or a focused document-group-linker service
- `frontend/lib/widgets/pdf_stage.dart`
- `frontend/lib/models/studio_state.dart`
- `frontend/test/smart_pen_index_test.dart`
- `frontend/test/smart_pen_annotation_test.dart`

## Verification

```powershell
flutter test test/smart_pen_index_test.dart
flutter test test/smart_pen_annotation_test.dart
flutter analyze lib/services/smart_pen_answer_index.dart lib/models/studio_state.dart lib/widgets/pdf_stage.dart
```

## Dependencies / Exit Criteria

Depends on Phase 01. Do not proceed until unique-link/fail-closed behavior, stable IDs, cross-page replacement, and atomic persisted/temporary undo-redo all pass.
