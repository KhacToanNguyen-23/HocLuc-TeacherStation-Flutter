# Plan: Google Classroom Auto Sync After Class Creation

- Date: 2026-10-17
- Mode: --hard
- Risk: high-risk — external Google Classroom API state plus frontend lifecycle-driven sync
- Spec: `plans/google-classroom-auto-sync/spec.md`
- Status: complete

## Goal

Remove the required manual **Đồng bộ** click after accepting a Google Classroom course. Keep the existing create flow, which already checks/updates activation and syncs members when Google reports `ACTIVE`. When it returns a pending course, retry the existing sync operation after the user returns to HocLucStation. Show the outcome in the app. Do not add periodic background polling or operating-system notifications.

## Spec Stories

- **S1 / P1 — Auto-sync after creation:** use and display the roster sync result already returned by the current create operation; do not issue a duplicate sync request from the frontend.
- **S2 / P1 — Retry when returning to the app:** if the post-create sync reports that the course is not active, one subsequent app resume triggers at most one sync attempt for that pending course.
- **S3 / P1 — Explain pending activation:** show an in-app instruction to open Classroom and accept/activate the course; do not imply roster sync completed.
- **S4 / P1 — Report automatic check result in-app:** show the result for pending, successful sync, or an actionable error. No OS notification.
- **S5 / P2 — Expose sync progress/result:** distinguish syncing, complete, pending/not ready, and failed states in the course UI.

## Scope and Design

The existing `GoogleWorkspaceScreen` is a `StatefulWidget` without a lifecycle observer. The current manual sync callback calls `POST courses/{id}/sync`. The Classroom course URL is opened with `openExternalUrl` while the workspace remains mounted. Backend `GoogleClassService.create()` may return a pending course; `sync()` reads the course from Google when stored `classroomState != ACTIVE`, and reconciles the roster only when Google returns `courseState == ACTIVE`. `PROVISIONED` means not yet activated.

Use the existing create and sync APIs. The create endpoint already attempts activation and roster sync when the returned course is active; display that response and do not repeat the sync request. If its result says `PROVISIONED`, retain the course ID as the pending activation target and show the Classroom instruction. Observe Flutter `AppLifecycleState.resumed`; for a `PROVISIONED` target, issue one sync attempt per resume event, with a course-scoped in-flight guard shared with manual sync. Update the selected course and show an in-app result. Do not automatically retry other non-`ACTIVE` states such as `DECLINED`, `ARCHIVED`, or `SUSPENDED`. Classify clean roster success only when active, `classroomWarnings` are empty, and the backend reports `classroomSyncedAt`; surface active responses with warnings as partial/needs-attention rather than clean success. Do not infer roster success from `classroomState` or Calendar's `syncedAt` alone. Keep errors distinct from pending state and allow a later resume or manual sync to retry. Avoid periodic polling, new packages, and OS notifications unless implementation research proves they are necessary.

## Phases

1. [x] **Phase 01 — Preserve create sync result and mark pending courses** (covers S1, S3): use the result the backend already returns and avoid a duplicate sync request; represent pending activation for resume handling. See `phase-01-create-sync.md`.
2. [x] **Phase 02 — Retry pending activation on app resume** (covers S2, S3): track the pending course, observe lifecycle resume, guard duplicate/in-flight requests, and explain the next Classroom action in-app. See `phase-02-resume-retry.md`.
3. [x] **Phase 03 — Result messaging and edge-case hardening** (covers S3, S4, S5): make pending/success/error outcomes clear and prevent stale, duplicate, or contradictory notices across resume and manual retry. See `phase-03-result-messaging.md`.

## Dependencies

- Phase 02 depends on Phase 01's pending/success/error result model.
- Phase 03 depends on Phases 01–02.
- Backend contract remains the source of truth: roster reconciliation is successful only after Google reports `ACTIVE`.

## Risks and Mitigations

- **A resume event can occur more than once or during an active request.** Guard by course ID and in-flight state; ignore overlapping resumes.
- **An extra post-create request can duplicate backend work.** The create endpoint already attempts member sync when Classroom reports `ACTIVE`; use its response and only retry when the state is pending.
- **The backend may return HTTP success with roster/invitation warnings.** Use `classroomState`, `classroomWarnings`, and the Classroom-specific `classroomSyncedAt` to distinguish pending, clean success, and partial/needs-attention; do not infer full roster completion from `ACTIVE` or Calendar's `syncedAt` alone.
- **Manual sync can overlap an automatic resume check.** Route both paths through the same course-scoped guard and result handler.
- **Google may still return `PROVISIONED` after the teacher returns.** Keep the course pending, report that it needs acceptance/activation, and wait for a later resume or manual sync; do not poll. Do not retry `DECLINED`, `ARCHIVED`, or `SUSPENDED` automatically.
- **API/auth/network failures can resemble a pending result if errors are collapsed.** Preserve error classification and show an actionable error separately from pending activation.
- **Stale asynchronous results can overwrite a newly selected course or a disposed screen.** Scope state updates to the request/course and lifecycle of the screen; cancel or ignore stale completions.
- **Platform lifecycle differs across desktop and web.** Use Flutter lifecycle notifications and verify behavior in widget tests; treat `resumed` as the trigger supported by the spec.

## Verification Plan (not run during planning)

Targeted tests to add/update:

- `frontend/test/google_workspace_test.dart`: successful creation displays the existing create result and does not send a duplicate `/sync`; pending response shows Classroom guidance; resume retries only a pending course; overlapping resume and manual sync do not duplicate requests; active responses with `classroomWarnings` are partial/needs-attention rather than clean success; success/error messaging is in-app; manual retry remains usable after errors; disposed/stale requests do not update the wrong UI.
- `backend/api` existing `GoogleIntegrationTest`: retain coverage that `PROVISIONED` is not roster-synced and a later `ACTIVE` response reconciles the roster. Extend only if the current test does not assert state persistence needed by the frontend.
- Required repository architecture check per `AGENTS.md`: `flutter test test/architecture_test.dart` (from the Flutter package root). These are verification instructions for implementation; no tests are run in this planning task.

## User Decisions

- Retry on each `AppLifecycleState.resumed` while the pending course is still open in the workspace.
- Keep pending state in the current workspace screen session; Classroom opens externally while that screen remains mounted.
- Show the sync result in a status banner inside the course card; do not use an OS notification or snackbar.
- Treat `PROVISIONED` as pending activation and retryable; other non-`ACTIVE` course states are not auto-retry states. When active, use `classroomWarnings` to distinguish clean sync from partial/needs-attention. If implementation needs finer warning categories, record and validate that as an implementation finding rather than parsing warning text.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-17 05:02 UTC
**Phase in progress:** complete
**Status:** Phases 01–03 are implemented, verified, and reviewed; finalization is complete.

### Decisions made this session
- Reused the create response and did not send a duplicate `/sync` request.
- Showed pending, clean active, partial active, and other Classroom states in the course card. Clean success requires `ACTIVE`, no Classroom warnings, and a `classroomSyncedAt` value.
- Added coverage for active responses with and without `classroomSyncedAt`, including that Calendar's `syncedAt` alone is insufficient.
- Added a lifecycle observer for `resumed`, retained a selected `PROVISIONED` course for the screen session, and routed manual/automatic sync through one course-scoped in-flight guard.
- Queued a resume retry if another workspace operation is running; the retry rechecks that the selected course is still pending when that operation finishes.
- Kept the pending guidance visible after sync errors, allowed retry on the next resume, and ignored responses after disposal.
- Added in-card progress and per-course sync errors; clean success requires `ACTIVE`, no Classroom warnings, and `classroomSyncedAt`.
- Limited resume-retry guidance to `PROVISIONED`; other sync errors direct teachers to the manual retry action.
- Verified the focused retry test, all 33 Google Workspace tests, and all 5 architecture tests.

### Next immediate action
None.
