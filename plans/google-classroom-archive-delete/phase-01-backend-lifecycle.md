# Phase 01: Backend lifecycle and state reconciliation

**Covers:** Spec stories — archive class, restore class, safe permanent deletion, Google permission/error feedback.

## Files

- `backend/api/src/main/java/vn/teaching/integrations/GoogleClassService.java`
- `backend/api/src/main/java/vn/teaching/integrations/GoogleIntegrationController.java`
- `backend/api/src/test/java/vn/teaching/integrations/GoogleIntegrationTest.java`

## Tasks

1. Reconcile remote `courseState` for locally stored rows with a Google `courseId`, using paginated Classroom courses for the connected teacher and updating only rows already represented in HocLuc. If a completed list omits a locally stored ID, verify it with a direct course lookup; remove the local row only on Google `NOT_FOUND`, and preserve it with a per-course refresh error on other failures. Preserve the last confirmed state when refresh fails.
2. Add archive and restore service operations that patch only `courseState`, read the state back from Google, and update the stored row only after the read-back confirms the requested state. If read-back fails, preserve the previous confirmed state and return an unverified-operation error.
3. Add explicit archive and restore controller routes under `/api/integrations/google/courses/{id}`. Continue using the existing local-session and teacher-email checks.
4. Harden delete: local-only rows with no `courseId` may be removed locally; remote rows must be verified as `ARCHIVED` before calling Google delete. Treat remote success or `NOT_FOUND` as complete, and preserve local data on permission, network, or other API errors.
5. Ensure retry behavior reconciles the remote course after uncertain responses and does not overwrite stored state with an unconfirmed value.
6. Keep `PROVISIONED` remote courses in their current active state; do not archive or remotely delete them until Classroom reports `ACTIVE`.

## Acceptance

- Backend integration tests cover archive, restore with read-back, paginated/current-state reconciliation, `PROVISIONED` guards, archived-only remote delete, local-only delete, permission denial, `NOT_FOUND`, and failure preserving the stored course.
- External deletion reconciliation removes a local mapping after a direct Google 404; permission or network failures retain cached data.
- Google permission errors are passed through the existing sanitized error mapping; no role is inferred from frontend input.
- No database schema migration is introduced.

## Verification commands (implementation phase)

- `cd backend/api; mvn test -Dtest=GoogleIntegrationTest`

