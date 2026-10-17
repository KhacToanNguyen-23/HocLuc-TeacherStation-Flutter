# Phase 02 — Retry pending activation on app resume

**Stories:** S2 (P1), S3 (P1)

## Outcome

When the post-create response identifies a `PROVISIONED` course, the workspace retains that course as pending and gives the teacher an in-app instruction to accept it in Google Classroom. On each subsequent `AppLifecycleState.resumed` while that course is open, it calls the existing sync operation at most once. Other non-`ACTIVE` states are reported for attention and are not retried automatically.

## Work

1. Confirm the existing sync response contract for `ACTIVE` versus `PROVISIONED` and use the backend's Google course state as the activation source of truth.
2. Add a lifecycle observer to `GoogleWorkspaceScreen` and remove it on disposal.
3. Retain the pending course ID after a pending result. Clear it only when the course is active/synced or no longer eligible for retry.
4. On resume, trigger one sync only for the pending `PROVISIONED` course. Use the same course-scoped in-flight guard and result handler for automatic resume checks and the manual **Đồng bộ** action; ignore duplicate resume/manual events received while a request is in flight.
5. If the response remains pending, retain the pending target and show guidance to open/accept the course in Classroom. If active, update the UI and clear pending state. If the request errors, show an error distinct from pending and allow a later resume/manual retry.
6. Do not add periodic polling, OS notifications, or implicit course activation.

## Tests to add/update (do not run in planning)

- Pending post-create result arms only the corresponding course ID.
- Resume with a pending course triggers one sync call; resume without a pending course triggers none.
- Multiple resume notifications during an in-flight call do not cause concurrent duplicate requests.
- Manual sync overlapping an automatic resume attempt is coalesced or disabled and produces one request/result.
- Still-pending response preserves guidance and pending eligibility; active response updates roster and clears pending state.
- Error response is distinct from pending and allows a later retry.
- Observer is removed on dispose; completion after disposal does not update state.

## Acceptance

- S2 accepted condition passes: at most one retry on the next resume event while pending.
- S3 accepted condition passes: pending state directs the teacher to Classroom and never claims roster sync completed.

## Dependencies

Phase 01's pending/active/error result model.

## Phase 02 Results

- TDD RED was confirmed for resume-triggered sync and duplicate resume handling before adding the lifecycle observer.
- Added coverage for create-to-resume flow, no-pending behavior, selecting a pending course, repeated resume/manual exclusion, a still-pending result, API error retry, queued retry after reload, and disposal with a late response.
- GREEN: `flutter test --no-pub --reporter expanded test/google_workspace_test.dart` — 31 passed.
- Code review: no remaining concrete implementation defects. Selection tracking and queued retry during unrelated work were added after review; both now have focused tests.
- Hard-mode gate: pause here for user approval before starting Phase 03.
