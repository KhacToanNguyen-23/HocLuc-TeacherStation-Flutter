# Plan: Clean Architecture & Code Smell Refactoring

**Mode:** Hard
**Risk:** normal — Multi-file architectural refactoring preserving 100% existing logic, API contracts, and UI behavior.

---

## Executive Summary

This plan addresses foundational architecture violations and code smells across the Flutter Desktop/Web client and Spring Boot backend:
1. **Zero Logic Regression**: All refactoring preserves 100% existing external behavior, API JSON contracts, UI styling, and state behavior.
2. **Architecture Defense Compliance**: Fixes inter-feature coupling (`auth` ⇄ `classroom_meet` ⇄ `exams`), core-to-feature dependency leaks (`local_service.dart` importing `planning_meta.dart`), and domain layer pollution (`StudioState`).
3. **De-Golfing & Code Smells**: Restores readability to minified Java files, eliminates silent error swallowing across 39+ catch blocks, and resolves Mojibake string encoding.
4. **God Class Decomposition**: Breaks monolithic `StudioState` (>2,500 lines across 6 `part` files) using a clean **Facade & Composition Pattern** without breaking any widget consumers.

---

## Phases Overview

| Phase | Title | Scope | Verification |
| :--- | :--- | :--- | :--- |
| **01** | [Quick Wins & Zero-Risk Sanitization](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/clean-architecture-and-code-smell-refactor/phase-01-quick-wins-and-sanitization.md) | Backend Mojibake, Java code-golf formatting, and logging empty catch blocks | `mvn test`, `flutter test test/architecture_test.dart` (PASS: 123 tests) |
| **02** | [Architecture Decoupling & Boundary Enforcement](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/clean-architecture-and-code-smell-refactor/phase-02-architecture-decoupling-and-boundaries.md) | Decouple `LocalService` (core→features leak), relocate `GoogleMeetAuthService`, isolate `plugin_engine` | `flutter test test/architecture_test.dart`, `node scripts/validate_plugins.mjs` |
| **03** | [God Class Decomposition via Facade Pattern](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/clean-architecture-and-code-smell-refactor/phase-03-god-class-facade-decomposition.md) | Decompose `StudioState` with sub-controllers, extract large widget build methods | `flutter test` |
| **04** | [Backend Layering & Unified Error Strategy](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/clean-architecture-and-code-smell-refactor/phase-04-backend-error-handling-and-layering.md) | Spring `@ControllerAdvice`, typed error models, Bean Validation | `mvn test`, `flutter test` |

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-19 21:55
**Phase in progress:** None (All 4 Phases Complete)
**Status:** All 4 Phases complete & verified. 129 backend tests passing, 397 frontend tests passing, 12/12 architecture invariants passing, 0 analyzer issues, plugins 100% valid.

### Decisions made this session
- Formatted `ExamRepository.java`, `ExamAuth.java`, `PaperService.java`, `ResultService.java`, and `ExamErrorHandler.java` to standard multi-line Google Java Style while keeping lines <= 600.
- Preserved exact combinatorics knapsack search and quota matching algorithms.
- Replaced empty catch blocks with structured diagnostics logging via `FrontendLogger` in Flutter and `LoggerFactory` in Spring Boot.
- Restored correct UTF-8 Vietnamese strings in `ClassroomService.java`.
- Decoupled `LocalService` from planning domain models; extracted `PlanningRepository`.
- Centralized `GoogleMeetAuthService` inside `features/auth/services/`.
- Created `PluginHostBridge` interface in `features/plugin_engine/domain/models/`, reducing `plugin_engine`'s dependencies on `studio_board` to zero.
- Decomposed `StudioState` (serialization extracted into `studio_state_serialization.dart`, 644 LOC).
- Decomposed `SelectClassroomDialog` (extracted sub-sections into `select_classroom_sections.dart`, 350 LOC).
- Decomposed `AuthFormCard` (extracted sub-views into `auth_form_views.dart`, 418 LOC).
- Created `GlobalExceptionHandler` with RFC-7807 problem details handling `ResponseStatusException`, `MethodArgumentNotValidException`, `GoogleFailure`, `IllegalArgumentException`, and `HttpMessageNotReadableException`.
- Integrated `spring-boot-starter-validation`, annotated `LoginRequest`, `RegisterRequest`, and `OtpAuthRequest` with Jakarta Bean Validation constraints and added `@Valid` to `AuthController`.
- Added unit tests in `GlobalExceptionHandlerTest` and validation tests in `AuthControllerTest`.

### Next immediate action
All phases completed with 100% test coverage and zero logic regressions. Ready for code review and PR merge.

---

## Safety & Invariant Gates

Every phase must pass:
1. `flutter test test/architecture_test.dart` (12/12 passing invariants)
2. `node scripts/validate_plugins.mjs` (0 errors, 100% synced)
3. `mvn test -f backend/api/pom.xml` (all Spring Boot unit & integration tests pass)
4. `flutter test` (all frontend tests pass)

