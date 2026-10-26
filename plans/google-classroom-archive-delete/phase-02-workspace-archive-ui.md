# Phase 02: Workspace active/archive experience

**Covers:** Spec stories — archived class list, restore, delete only while archived, local-only deletion, clear failure feedback.

**Status:** Implemented; the Google Workspace widget suite passes (43 tests). Empty Active/Archived tabs remain selectable, while the first connected load chooses a group with courses. Account changes reset the initial tab choice. Inline review also found and corrected cached-state gating, including preserving local deletion while Google actions are locked.

## Files

- `frontend/lib/features/classroom_meet/presentation/screens/google_workspace_screen.dart`
- `frontend/lib/features/classroom_meet/presentation/workspace/workspace_course_detail.dart`
- `frontend/test/features/classroom_meet/google_workspace_test.dart`

## Tasks

1. Add separate Active and Archived sections/tabs to the existing Workspace class screen, derived from confirmed `classroomState` while retaining records with no Google ID and `PROVISIONED` courses in Active.
2. Add Archive for active Google-backed courses and Restore for archived courses, call the new backend routes, and update the correct list only after backend read-back confirms the state.
3. Show permanent Delete only for archived Google-backed courses. Keep local-only deletion available in Active for rows with no `courseId`; use confirmation copy that clearly says it affects HocLuc only.
4. Hide or disable start, schedule, edit, invite, and sync operations for archived courses. Keep archived detail limited to restore and permanent delete.
5. Show a cached-state warning on reconciliation failure and keep courses visible but read-only for all actions that call Google until a successful refresh. Keep local-only deletion available for courses without a Google ID.
6. For `PROVISIONED` courses, show guidance to activate the class in Google Classroom before archive or remote deletion; do not expose those actions.
7. Add widget tests for list grouping, action visibility, archive/restore movement, delete confirmation and API routing, local-only deletion, `PROVISIONED` guidance, and Google failure behavior.

## Acceptance

- A course appears in exactly one of Active or Archived based on its last confirmed Google state.
- Remote lifecycle actions call the matching endpoint and failed calls leave the course in its previous group.
- `PROVISIONED` courses remain in Active and offer activation guidance without archive/delete actions.
- Remote delete is not available from Active; local-only delete is available there and does not imply a Google operation.
- Archived course detail cannot start teaching or mutate its roster.
- If refresh fails, cached classes remain visible and Google-backed actions are disabled.

## Verification commands (implementation phase)

- `cd frontend; flutter test test/features/classroom_meet/google_workspace_test.dart`

