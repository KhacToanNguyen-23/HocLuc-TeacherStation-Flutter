# Phase 04: Backend Layering & Robust Error Handling Strategy

## Goal
Standardize error contracts, eliminate in-band error carriers, and introduce clean Spring Boot ControllerAdvice without breaking Frontend JSON deserialization.

---

## Detailed Tasks

### 1. Unified `@ControllerAdvice` and Problem Details
- Create `vn.teaching.config.GlobalExceptionHandler` handling:
  - `ExamException`
  - `GoogleFailure`
  - `ResponseStatusException`
  - `MethodArgumentNotValidException` (Spring Validation)
  - Generic `Exception`
- Structure response JSON preserving backward compatibility:
  - For standard endpoints: include both legacy fields (`error`, `message`, `status`) and structured RFC 7807 `title` / `detail`.
  - Frontend parsing logic in `LocalService.dart` and `ExamApi.dart` continues to read `error` or `message` seamlessly.

### 2. Replace In-band Error Objects with Domain Exceptions
- In `ClassroomService.java`:
  - Instead of returning `Classroom.error(...)` (using entity as error container), throw explicit domain exceptions or return `Result<Classroom>` / `Optional<Classroom>`.
  - In `ClassroomController.java`, map domain results directly to proper HTTP status codes (400, 404, 409).

### 3. Add Declarative Bean Validation to Auth & Classroom DTOs
- Add `@NotBlank`, `@Size(min=6)` to `LoginRequest`, `RegisterRequest`, and `OtpAuthRequest`.
- Annotate controller endpoints with `@Valid` in `AuthController.java` and `ClassroomController.java`.
- Remove redundant manual `if (req == null || req.getIdentifier() == null ...)` checks in controllers.

---

## Verification Commands
```powershell
mvn test -f backend/api/pom.xml
flutter test test/architecture_test.dart
flutter test
```

