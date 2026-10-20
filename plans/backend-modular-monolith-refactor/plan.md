# Plan: Backend Modular Monolith Refactoring (Feature-First Clean Architecture)

**Mode:** Hard
**Risk:** Normal — Multi-file Java package restructuring preserving 100% existing REST endpoints, JSON contracts, and database/file persistence logic.

---

## Executive Summary

The backend companion service (`backend/api`) currently mixes package-by-layer (`controller/`, `service/`, `model/`, empty `dto/`) with package-by-feature (`exam/`, `integrations/`), has no repository layer for file persistence (`ClassroomService` and `PlanningService` directly perform disk I/O), mixes DTOs with Entities in `model/`, and defines inline records in controllers.

This plan refactors the Spring Boot backend into a clean **Modular Monolith (Feature-First)** architecture matching the frontend's domain boundaries 1-1, establishing clear layers (`controller`, `service`, `repository`, `dto`, `entity`) within each feature module.

---

## Architecture Boundaries (Before vs After)

### Before (Fragmented Hybrid)
```
vn.teaching/
├── controller/ (Auth, Classroom, Planning, Plugin, Audio, Device, Bootstrap)
├── service/    (ClassroomService [I/O], PlanningService [I/O], AuthService, ...)
├── model/      (Lẫn lộn cả DTO LoginRequest lẫn Entity Classroom, Planning)
├── dto/        (TRỐNG)
├── exam/       (Controller + Service + Repo + Models + Config + Handler nhồi chung 1 thư mục)
├── integrations/ (Controller + Service + Store + Gateway nhồi chung 1 thư mục)
└── config/
```

### After (Modular Monolith / Feature-First)
```
vn.teaching/
├── CompanionServer.java (Root @SpringBootApplication component scan)
├── core/
│   ├── config/          (WebConfig, CompanionConfig, SecurityInterceptor, ...)
│   ├── exception/       (GlobalExceptionHandler)
│   ├── service/         (StorageService)
│   └── controller/      (BootstrapController, LessonController)
└── modules/
    ├── auth/
    │   ├── controller/  (AuthController)
    │   ├── service/     (AuthService)
    │   └── dto/         (LoginRequest, RegisterRequest, OtpAuthRequest, AuthResponse)
    ├── classroom/
    │   ├── controller/  (ClassroomController)
    │   ├── service/     (ClassroomService, GoogleMeetService)
    │   ├── repository/  (ClassroomRepository, FileClassroomRepository)
    │   └── entity/      (Classroom)
    ├── planning/
    │   ├── controller/  (PlanningController)
    │   ├── service/     (PlanningService)
    │   ├── repository/  (PlanningRepository, FilePlanningRepository)
    │   └── entity/      (Planning)
    ├── exam/
    │   ├── controller/  (ExamController, SharedAuthController, LocalWebviewSessionController, ...)
    │   ├── service/     (PaperService, ResultService, AnalyticsService, ExportService, ...)
    │   ├── repository/  (ExamRepository)
    │   ├── model/       (ExamModels, ExamAuth)
    │   ├── config/      (ExamWebConfig)
    │   └── exception/   (ExamException, ExamErrorHandler)
    ├── integrations/google/
    │   ├── controller/  (GoogleIntegrationController)
    │   ├── service/     (GoogleClassService, GoogleConnectionService, GoogleScheduleService)
    │   ├── repository/  (GoogleStore, GoogleGateway, GoogleHttpGateway)
    │   ├── dto/         (StartRequest, PollRequest, CreateCourseRequest, MeetAccessRequest, ...)
    │   └── exception/   (GoogleFailure, GoogleIntegrationErrors)
    ├── plugin/
    │   ├── controller/  (PluginMarketplaceController)
    │   ├── service/     (PluginMarketplaceService)
    │   └── dto/         (PluginCatalogItemDto)
    └── media/
        ├── controller/  (AudioController, DeviceController)
        └── service/     (AudioRuntimeService, DeviceService)
```

---

## Phases Overview

| Phase | Title | Scope | Verification |
| :--- | :--- | :--- | :--- |
| **01** | [DTO & Entity Separation](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/backend-modular-monolith-refactor/phase-01-dto-and-entity-separation.md) | Separate Request/Response DTOs from Entities, extract inline records from controllers into typed DTOs | `mvn test`, `mvn test-compile` |
| **02** | [Repository Layer Extraction](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/backend-modular-monolith-refactor/phase-02-extract-repositories.md) | Extract `ClassroomRepository` and `PlanningRepository` out of service classes to cleanly isolate disk I/O | `mvn test -Dtest=ClassroomSessionTest` |
| **03** | [Modular Monolith Package Reorganization](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/backend-modular-monolith-refactor/phase-03-modular-monolith-package-restructuring.md) | Relocate classes into `vn.teaching.modules.*` and `vn.teaching.core.*`, update all imports & test suites | `mvn test`, `flutter test test/architecture_test.dart` |
| **04** | [Full Verification & Architecture CI Gate](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/backend-modular-monolith-refactor/phase-04-verification-and-ci-hardening.md) | Verify all 129+ backend tests, 397+ frontend tests, 12 architecture invariants, and plugin schemas | `mvn test`, `flutter test`, `node scripts/validate_plugins.mjs` |

---

## Safety & Invariant Gates

Every phase must pass:
1. `mvn test -f backend/api/pom.xml` (all 129+ unit & integration tests pass)
2. `flutter test test/architecture_test.dart` (12/12 passing invariants, Java <= 600 LOC)
3. `node scripts/validate_plugins.mjs` (100% valid)
4. `flutter analyze --no-fatal-infos` (0 issues)

