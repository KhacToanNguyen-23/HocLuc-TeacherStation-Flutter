# Phase 01 — Preserve create sync result and mark pending courses

**Stories:** S1 (P1), S5 (P2)

## Outcome

After a course is successfully created, HocLucStation uses the result returned by the existing backend create flow. The backend already checks activation and reconciles members when Google reports `ACTIVE`, so the frontend must not send a duplicate `/sync` call. A pending result is retained for the lifecycle retry phase.

## Work

1. Trace the create success path in `GoogleWorkspaceScreen` and confirm the backend create response already includes the result of its activation/sync attempt.
2. Preserve that request/response path and do not send a second sync call after successful creation.
3. Keep existing create failure behavior unchanged.
4. Model `PROVISIONED` as pending; model other non-`ACTIVE` states as needs-attention without auto-retry; model clean roster success only when `classroomState == ACTIVE` and `classroomWarnings` is empty; model active responses with warnings as partial/needs-attention. Do not use `syncedAt` alone to claim roster completion.
5. Ensure the course list/selected course reflects the create response and does not report roster completion while Google state is pending.

## Tests to add/update (do not run in planning)

- Successful create uses its existing returned sync result and triggers no duplicate frontend `/sync` call.
- Create failure preserves the existing error flow and does not send a duplicate frontend sync request.
- Sync progress and active/pending/error terminal states are distinguishable in the UI.
- Pending response does not show a completed roster state.
- Active response with `classroomWarnings` does not show an unqualified clean-success state.

## Acceptance

- S1 accepted condition passes: create response is reflected without manual action or duplicate sync request.
- S5 states have visible, distinct UI representations.
- Existing manual sync still uses the same operation.

## Dependencies

None.

## Phase 01 Results

- TDD RED was confirmed before the UI change: the focused status tests failed because the course card had no Classroom result banner.
- GREEN: `flutter test --no-pub --reporter expanded test/google_workspace_test.dart` — 23 passed.
- Code review: no blocking bugs or regressions. The reviewer noted a missing `ACTIVE` without `syncedAt` case; that test was added and passed.
- Hard-mode gate: pause here for user approval before starting Phase 02.
