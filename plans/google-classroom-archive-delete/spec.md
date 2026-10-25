# Spec: Archive and delete Google Classroom courses

**Date:** 2026-10-20  
**Status:** Implemented; reversible live Classroom archive/restore verified with the primary teacher. Live permanent deletion was skipped per user choice because no disposable course was available; co-teacher behavior remains unverified live.

## Problem Statement

HocLuc currently deletes its course record and calls Google Classroom course deletion directly. Google Classroom requires a class to be archived before it can be deleted, so the current flow does not match Classroom's lifecycle and can fail for classes that are still active. Teachers need an archived area where they can restore a class or permanently delete it when Google permits.

## User Stories

- **[P1]** As a teacher, I want to archive an active class from HocLuc so that it leaves my active class list in both HocLuc and Google Classroom while its posts and student work are preserved.
  Accepted when: a successful archive updates the Google Classroom course state to `ARCHIVED`, keeps the HocLuc course record, and shows the class in the archived area after reload.

- **[P1]** As a teacher, I want to see archived classes in a separate area so that I can manage them without confusing them with active classes.
  Accepted when: active and archived courses appear in distinct lists based on the reconciled `classroomState`; archived courses do not offer active teaching, sync, edit, or invite actions.

- **[P1]** As a teacher, I want to restore an archived class so that I can use it again.
  Accepted when: a successful restore updates Google Classroom to `ACTIVE` and returns the class to the active list after reload.

- **[P1]** As a teacher, I want to permanently delete an archived class so that I can remove its posts and comments from Classroom when I no longer need them.
  Accepted when: permanent deletion is offered only from the archived area, calls Google Classroom deletion first, and removes the HocLuc record only after Google confirms deletion or reports the course is already gone.

- **[P1]** As a teacher, I want clear feedback when my Google account cannot archive or delete a course so that HocLuc does not claim a change succeeded when Google rejected it.
  Accepted when: Google permission or API errors leave the course record and its last confirmed state visible, with a retryable error message.

## Functional Requirements

1. FR-01: Add an archive action for active Google Classroom courses. Use the Classroom API to change `courseState` to `ARCHIVED`; do not delete local course data during archival.
2. FR-02: Add a distinct archived-courses area in the HocLuc Google Workspace class screen. Classify courses by the confirmed Google `classroomState`.
3. FR-03: Add a restore action in the archived area. Change the course state to `ACTIVE` through Google Classroom and move it to the active list only after success.
4. FR-04: Offer permanent deletion only in the archived area. Require a confirmation that states posts and comments will be lost and that deletion cannot be undone.
5. FR-05: For permanent deletion, call Google Classroom first. Delete the HocLuc course record only after success or a `NOT_FOUND` response; preserve the record on other failures.
6. FR-06: Treat Google Classroom as the authority for teacher permissions. Only the primary teacher can permanently delete; co-teachers may archive if Google grants the operation. Surface Google permission errors without bypassing them.
7. FR-07: Keep archived classes out of operations that require an active course, including invitations, synchronization, editing, scheduling, and starting lessons.
8. FR-08: For a HocLuc record with no Google `courseId`, keep local deletion available in the active list. Label the confirmation as local-only and do not imply a Google archive or delete occurred.
9. FR-09: Refresh/reconcile the course state on load or before a lifecycle action so changes made directly in Google Classroom do not leave the app's active and archived lists stale. If refresh fails, show cached data read-only and disable all actions that call Google until refresh succeeds.
10. FR-10: Keep Google-backed `PROVISIONED` courses in the current active list, explain that they must first be activated in Google Classroom, and do not offer archive or remote delete until then.
11. FR-11: After archive or restore PATCH, read the course state back from Google. If that verification fails, retain the previous confirmed state/group, mark the operation unverified, and allow retry.

## Non-Functional Requirements

- Performance: Lifecycle calls use the existing Google API request timeout; one archive or restore action issues one state mutation and one read-back, while delete performs the required state check and one delete request.
- Security: All mutations use the connected teacher's OAuth token through the backend. The Flutter client never receives Google credentials. Google enforces the connected account's Classroom role.
- Availability: On network, permission, or Google API failure, keep the stored course record and report the operation as incomplete so the teacher can retry.

## Success Criteria

- [x] An active course archived from HocLuc is shown in the archived area and has Google state `ARCHIVED` after a reload. Live primary-teacher API and refreshed UI confirmation were performed on 12AA.
- [x] A restored course is shown in the active area and has Google state `ACTIVE` after a reload. Live primary-teacher API confirmation was performed on 12AA.
- [x] Permanent delete is only reachable for archived courses, and Google failure never causes local course data to be removed. Automated backend/widget coverage; live permanent deletion was skipped per user choice.
- [ ] A co-teacher permission denial and a primary-teacher delete are reported using the actual Google response; HocLuc does not treat a local UI role as proof of Google permission.
- [x] A course without a Google ID can be deleted locally from the active list without making a Google request or claiming a remote change. Automated backend/widget coverage.
- [x] A `PROVISIONED` course remains in Active and cannot be archived or remotely deleted until activated in Classroom. Automated backend/widget coverage.
- [x] A failed state refresh leaves cached courses visible, disables actions that call Google, and does not change their last confirmed group. Automated backend/widget coverage.
- [x] A failed read-back after a successful PATCH leaves the previous group in place and marks the course state unverified. Automated backend/widget coverage.

## Out of Scope

- Bulk archive, restore, or delete.
- Deleting class files or folders from Google Drive.
- Managing classes created outside HocLuc unless they are already represented in HocLuc's course store.
- Removing individual students from an archived class.

## Assumptions

- The feature applies to courses listed in HocLuc's Google Workspace screen and backed by the existing Google course store.
- “Xóa” means Google's permanent course deletion after archive; it removes access to Classroom posts and comments, while Drive class files remain available under Google's documented behavior.
- Archived classes can be restored through the same connected Google account.
- The existing `classroom.courses` OAuth scope is sufficient for state updates and deletion; implementation should verify current consent handling rather than request an unrelated scope.

