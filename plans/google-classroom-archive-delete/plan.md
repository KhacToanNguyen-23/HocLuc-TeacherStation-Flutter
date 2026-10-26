# Plan: Google Classroom archive and delete lifecycle

**Date:** 2026-10-20  
**Mode:** Hard (inline research/review; sub-agents unavailable by session policy)  
**Risk:** high-risk — changes remote Google Classroom state and includes irreversible course deletion.  
**Spec:** [spec.md](spec.md)

## Scope Challenge

- **Exists?** HocLuc already has a delete action and `GoogleClassService.delete` calls Classroom `courses.delete` before removing its stored course. There is no archive/restore flow or archived list.
- **Minimum?** Add backend archive/restore lifecycle operations, reconcile remote state, split active and archived courses in the existing Workspace screen, and make remote deletion available only for archived courses. Keep local-only deletion for courses with no Google `courseId`.
- **Complexity?** Hard: backend, Flutter UI, external API permission/state handling, and irreversible deletion.

## Spec Quality Check

- **[NEEDS CLARIFICATION] remaining:** none.
- **Success criteria measurable/testable:** pass; each criterion states a state transition, UI placement, or failure behavior.
- **P1/P2/P3 stories:** pass; all five user stories are marked P1.
- **Acceptance criteria testable:** pass; criteria identify API state and local-record outcomes.
- **Verdict:** PASS.

## Research

Research was performed inline because this session prohibits spawning agents.

- **Primary approach:** Keep lifecycle orchestration in `GoogleClassService`, expose archive/restore endpoints in `GoogleIntegrationController`, and let the existing Flutter Workspace screen manage active and archived groups. This matches the current backend ownership of OAuth and Google API calls.
- **Reconciliation:** Classroom `courses.list` can return courses in any state when `courseStates[]` is omitted, supports `teacherId=me`, and paginates. Reconcile only locally stored Google course IDs; do not import unrelated courses into HocLuc. Preserve cached course state and attach a refresh warning if the remote listing fails.
- **State updates:** Use `courses.patch` with `updateMask=courseState`. Google returns `PERMISSION_DENIED`, `NOT_FOUND`, or `FAILED_PRECONDITION` where appropriate. Store only the state confirmed by Google's response/read-back.
- **Deletion:** Google Help says a class must be archived before permanent deletion and only the primary teacher can delete it. Keep Google as the permission authority. Backend must check the live state before remote delete; on Google success or `NOT_FOUND`, remove the local record, and on any other error retain it.
- **Alternative considered:** Archive then immediately delete from the active list. Rejected because it skips the archived management area the user requested and combines reversible archive with irreversible deletion.

### Research sources

- [Google Classroom Help: Archive or delete a class](https://support.google.com/edu/classroom/answer/6149813)
- [Classroom API: courses.list](https://developers.google.com/workspace/classroom/reference/rest/v1/courses/list)
- [Classroom API: courses.patch](https://developers.google.com/workspace/classroom/reference/rest/v1/courses/patch)
- [Classroom API: courses.delete](https://developers.google.com/workspace/classroom/reference/rest/v1/courses/delete)

## Phase Overview

- [x] **Phase 1: Backend lifecycle and state reconciliation** — add remote state reconciliation, archive/restore operations, and server-side delete guards.
- [x] **Phase 2: Workspace active/archive experience** — add separate lists, state-specific actions, confirmations, and local-only deletion behavior.
- [x] **Phase 3: Verification, documentation, and rollout checks** — tests/docs/gates are complete; reversible primary-teacher live archive/restore was verified. Per user choice, live permanent deletion was skipped because there is no disposable course; no co-teacher account was available.

## Red-Team Review (inline)

- UI-only hiding is not an authorization boundary. Keep the archived-state check in the backend delete endpoint and let Google enforce the primary-teacher rule.
- A timeout may happen after Google completes a mutation. Re-read/reconcile before changing the local state; retrying a completed delete should treat Google `NOT_FOUND` as already deleted and then finish local cleanup.
- A failed state refresh must not silently relabel a class or enable a destructive action from stale state. Keep the last confirmed state visible with an error and require a successful live state check before archive, restore, or remote delete.
- **Resolved during validation:** keep Google-backed `PROVISIONED` courses in Active and require activation in Classroom before archive or remote delete.
- No database migration is expected: existing Google course state is stored in each course's JSON data. Verify the existing data path can retain a refresh error without overwriting the last confirmed state.

## Risks

- **Google role/policy differences:** a co-teacher may be allowed to archive but Google denies deletion. Show the API error, retain the class, and do not infer permission from HocLuc UI state.
- **Stale or partial state:** remote changes made outside HocLuc and transient Google errors can make the active/archive split inaccurate. Reconcile paginated state and preserve last-confirmed data on failure.
- **Irreversible deletion:** require a confirmation from the archived area that names the loss of Classroom posts/comments. Google Drive files remain available per Google Help.
- **Quota and latency:** list reconciliation adds Google API traffic on screen load. Paginate once per load and reconcile only stored IDs; if the remote list fails, leave the cached list usable for viewing while disabling remote lifecycle operations.
- **Courses stuck in non-active state:** Google-backed `PROVISIONED` courses stay Active and require the teacher to activate them in Classroom before archive or remote deletion.

## Validation Decisions (confirmed 2026-10-20)

1. For a Google course in `PROVISIONED` state with a `courseId`, keep it in Active and require the teacher to activate it in Classroom before archive or remote delete.
2. If state reconciliation fails on load, show cached lists but disable all actions that call Google until refresh succeeds.
3. If archive/restore PATCH succeeds but read-back fails, keep the previous group, mark the course state unverified, and allow retry.

## Handoff

Implementation, automated verification, repository gates, and the live primary-teacher restore/archive round-trip for 12AA are complete. The user confirmed 12AA appears in the Archived tab after refresh. Per user instruction, live permanent deletion was skipped because there is no disposable class; no co-teacher account was available for live verification. Backend tests cover deletion success, already-missing courses, and permission failure preserving the local row.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-20 11:08 ICT  
**Phase in progress:** complete  
**Status:** Backend lifecycle, workspace UI, documentation, 61 `GoogleIntegrationTest` cases, full automated suites, and repository gates are complete. Primary-teacher live Restore → Archive API round-trip and final Flutter Archived-tab state are confirmed. Live permanent deletion was skipped by user choice; co-teacher behavior was not checked live because no secondary account was available.

### Decisions made this session

- Reconcile existing HocLuc courses through paginated `courses.list?teacherId=me`; never import unrelated Classroom courses.
- Read remote course state before archive, restore, and permanent delete. Read it again after archive/restore PATCH before changing the confirmed local state.
- Treat Google `NOT_FOUND` as complete deletion so a retry can clean up a local row after an uncertain prior response.

### Next immediate action

No further action within the approved scope. Live permanent deletion requires a disposable Classroom course; live co-teacher verification requires a secondary account.

