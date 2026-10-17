# Phase 03 — Result messaging and edge-case hardening

**Stories:** S3 (P1), S4 (P1), S5 (P2)

## Outcome

Automatic checks provide clear, non-duplicated in-app feedback for pending activation, successful roster sync, and API/auth/network errors. The state remains coherent across resume and manual retry.

## Work

1. Review all automatic and manual sync completion paths for consistent state updates and user-facing wording.
2. Present pending activation guidance and clean/partial/error results in a status banner inside the course card. Keep pending guidance visible until activation is observed; do not use a snackbar or OS notification.
3. Ensure an automatic error is not rendered as pending and does not leave the UI stuck in a loading state.
4. Avoid duplicate or stale notices when several lifecycle callbacks or a manual sync overlap; preserve course-scoped state and ignore stale completions.
5. Confirm the manual **Đồng bộ** path remains available as an explicit fallback and uses the same result handling.

## Tests to add/update (do not run in planning)

- Each automatic outcome produces the appropriate in-card status banner.
- Pending guidance remains visible until activation is observed; no success claim appears while pending.
- Resume/manual overlap and stale completion do not produce contradictory or duplicate notices.
- Loading always returns to a terminal state after success, pending, or failure.
- Verify integration behavior for backend `PROVISIONED` then `ACTIVE` through existing `GoogleIntegrationTest`; add an assertion only if required contract coverage is missing.
- Run `flutter test test/architecture_test.dart` from the Flutter package root as required by repository instructions.

## Acceptance

- S4 accepted condition passes for pending, active/success, and error states using in-app messaging only.
- S5 accepted condition passes and no outcome leaves the course UI in an ambiguous loading state.
- Required repository architecture test passes when implementation is completed.

## Dependencies

Phases 01 and 02.

## Implementation Results

- Added course-card banners for sync progress, pending activation, clean success, partial results, and errors.
- Kept Classroom acceptance guidance visible for `PROVISIONED` courses, including after a failed check. Resume retry guidance is shown only for `PROVISIONED`; other states direct the teacher to manual retry.
- Routed manual and automatic checks through one course-scoped in-flight guard and result handler. Failed checks clear progress and remain retryable.
- Added widget coverage for progress, errors, manual retry, active-state retry copy, lifecycle retry, duplicate resumes, and disposal. Added no backend changes.
- Verification: focused sync failure/retry widget test passed; `google_workspace_test.dart` passed (33 tests); `architecture_test.dart` passed (5 tests). Backend `GoogleIntegrationTest` passed earlier (47 tests, 0 failures).
- Final Phase 03 code review: APPROVED, no findings.
