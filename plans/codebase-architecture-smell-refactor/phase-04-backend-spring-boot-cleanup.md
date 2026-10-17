# Phase 4: Backend Spring Boot Service Decomposition

**File:** `plans/codebase-architecture-smell-refactor/phase-04-backend-spring-boot-cleanup.md`
**Target:** `backend/api/.../GoogleClassService.java` (37KB)

---

## 1. Goal
Split the 37KB monolithic `GoogleClassService.java` into cohesive, single-responsibility services:
- `GoogleRosterService.java`: Student invitations and roster queries.
- `GoogleCourseworkService.java`: Announcements and lesson coursework assignments.
- `GoogleScheduleService.java`: Calendar event creation and Meet room linking.

---

## 2. Verification
- `mvn -B clean test` in `backend/api`.
