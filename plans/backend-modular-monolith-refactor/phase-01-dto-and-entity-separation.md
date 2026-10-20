# Phase 01: DTO & Entity Separation

## Goal
Clearly distinguish between Data Transfer Objects (Requests & Responses) and Domain Entities, eliminating empty `dto/` package and extracting inline records out of controllers into standalone DTO classes/records.

---

## Detailed Tasks

### 1. Extract Inline Controller DTO Records
- In `GoogleIntegrationController.java`:
  - `record Start(String email, Boolean forceConsent)` -> `GoogleConnectRequest`
  - `record Poll(String state, String pollToken)` -> `GooglePollRequest`
  - `record Create(String requestId, String title, String description, List<String> emails)` -> `GoogleCreateCourseRequest`
  - `record Invite(List<String> emails)` -> `GoogleInviteRequest`
  - `record MeetAccess(String email, Boolean allowed)` -> `GoogleMeetAccessRequest`
  - `record Schedule(String requestId, String start, String end)` -> `GoogleScheduleRequest`
  - `record StartLesson(String requestId)` -> `GoogleStartLessonRequest`

### 2. Move Auth DTOs
- Group `LoginRequest`, `RegisterRequest`, `OtpAuthRequest`, `AuthResponse` under `vn.teaching.modules.auth.dto`.

### 3. Maintain Entity Semantics
- Ensure `Classroom` and `Planning` remain pure domain entities without coupling to HTTP transport serialization quirks.

---

## Verification Commands
```powershell
mvn test-compile -f backend/api/pom.xml
mvn test -f backend/api/pom.xml
```

