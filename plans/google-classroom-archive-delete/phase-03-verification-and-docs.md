# Phase 03: Verification, documentation, and rollout checks

**Covers:** All P1 stories and operational constraints.

**Status:** Complete within the user-approved validation scope. Documentation, code review, automated tests, repository gates, and the primary teacher's live backend lifecycle round-trip are complete. Latest evidence: plugin validator passed (2 plugins), architecture 12/12, analyzer clean, Flutter suite 406/406, `GoogleIntegrationTest` 61/61, full Maven suite 137/137, and course 12AA was restored to `ACTIVE`, confirmed by list reload, archived again, and confirmed `ARCHIVED` by a second reload. User confirmed the refreshed Flutter screen shows 12AA under Archived. User has no disposable course and asked to skip live permanent deletion; no secondary/co-teacher account was supplied, so actual co-teacher permission behavior remains unverified live. Automated tests cover deletion success, already-missing courses, and permission failure preserving the local row.

## Files

- `docs/google-workspace-integration.md`
- Any implementation files or tests found to need correction during review.

## Tasks

1. [x] Document archive, restore, permanent delete, primary-teacher restriction, local-only deletion, and what Google retains after deletion.
2. [x] Review the complete diff for lifecycle bypasses, stale state, partial failures, and unintended impact on active lesson/calendar flows.
3. [x] Run the repository's required checks from `AGENTS.md`: plugin validator, architecture test, analyzer, and relevant backend/frontend tests. No plugin packaging is needed unless plugin files change.
4. [x] Using the primary teacher's connected account, call the HocLuc restore/archive operations for 12AA and reload after each. Google and HocLuc API responses confirmed `ARCHIVED → ACTIVE → ARCHIVED`. Live permanent deletion is skipped per user instruction; backend tests cover successful deletion, already-missing courses, and permission failure preserving the local row.
5. [x] User confirmed the refreshed Flutter screen shows 12AA in Archived after the live Restore → Archive round-trip. Co-teacher verification was unavailable because no secondary account was supplied; actual role/policy behavior remains unverified live.
6. [x] Check the existing `classroom.courses` OAuth scope against Google's `courses.delete` requirements; no new scope is needed. Live permanent deletion was explicitly skipped because there is no disposable course.

## Acceptance

- All required repository gates pass with their output recorded.
- The primary teacher can archive and restore an archived class through HocLuc; live deletion remains untested by user choice, with automated success/failure coverage.
- Google remains the permission authority for co-teachers; denied operations preserve the local row in automated tests. Actual co-teacher behavior remains unverified live.
- Documentation accurately states the effect on Classroom content and Google Drive files.

