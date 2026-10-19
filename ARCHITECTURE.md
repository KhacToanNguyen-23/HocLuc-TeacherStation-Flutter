# Frontend Architecture & Modular Boundaries

This document defines the high-level architecture, module boundaries, and folder conventions for the Teacher Station Flutter application (`frontend/`).

---

## 1. Architectural Style: Clean Architecture (Feature-First)

The frontend is organized as a Modular Monolith adhering to Clean Architecture principles:
- **`lib/core/`**: Cross-cutting foundation shared across features (network client, platform helpers, common UI tokens, logger).
- **`lib/features/<module>/`**: Self-contained domain modules with clear responsibilities, encapsulated presentation, and private or exported services.
- **`lib/models/`**: Domain entities and state representations.
- **`lib/screens/`**: Top-level application shell and screen routing.
- **`lib/theme/` & `lib/constants/`**: Design tokens and theming.

---

## 2. Domain Feature Modules

### `lib/features/plugin_engine/`
* **Purpose**: Microkernel plugin runtime host.
* **Services**: `PluginManager`, `PluginStorageManager`, `PluginMarketplaceService`, `PluginWebServer`, `ProcessSupervisor`, `HostBridge`.
* **Presentation**: `FloatingPluginWindow`, `PluginHostDrawer`, `FlatHost`.
* **Boundary Rules**: Zero hardcoded plugin IDs; plugins communicate exclusively via the loopback HTTP server and HostBridge RPC.

### `lib/features/auth/`
* **Purpose**: Teacher authentication & Google identity management.
* **Services**: `GoogleConnectionFlow`.
* **Presentation**: `AuthFormCard`, `AuthHeroPanel`, `FlatAuthModal`, `GoogleWebviewLoginDialog`.

### `lib/features/classroom_meet/`
* **Purpose**: Live virtual classroom orchestration, Google Meet automation, and hardware media streaming.
* **Services**: `GoogleMeetAuthService`, `GoogleWorkspaceApi`, `MeetAutomationService`, `TeacherMediaService`, `MediaDeviceService`, `AudioTranslationService`, `SystemMicrophoneService`, `TeachingLauncher`, `WebviewEnvironmentService`.
* **Presentation**: `GoogleMeetView`, `MeetAdmissionButton`, `MeetAdmissionShell`, `MeetWebView`, `FloatingPip`, `CreateClassroomDialog`, `SystemMicrophoneControls`, `dashboard/`, `lobby/`, `workspace/`.

### `lib/features/studio_board/`
* **Purpose**: Teaching canvas, handwriting ink engine, PDF viewer stage, and smart pen integration.
* **Services**: `PdfAnnotationExporter`, `PdfAnnotationHandoutExporter`, `SmartPenAnswerIndex`, `SmartPenAnswerClassifier`, `StrokeClusterer`, `EnglishAnalyzer`, `DgnlService`.
* **Presentation**: `InteractiveChalkboard`, `PdfStage`, `FloatingPdfWindow`, `FloatingTimer`, `GridPainter`, `PresentationSurface`, `RegionSnippingOverlay`, `SmartChalkOverlay`, `StageContainer`, `StrokeCanvas`, `SubjectToolPalette`, `studio/`.

### `lib/features/exams/`
* **Purpose**: V-ACT & HSA exam paper preparation and session management.
* **Services**: `ExamApi`, `ExamFile`, `ExamFiles`, `ExamOAuthClient`, `ExamSessionService`.
* **Presentation**: `ExamStudioButton`, `ExamWidgets`.

---

## 3. Test Suite Organization

Tests in `frontend/test/` mirror the application structure:
- **`frontend/test/architecture_test.dart`**: Sole root test file acting as the architecture guardian (10 invariants).
- **`frontend/test/features/<module>/`**: Feature-specific unit and widget tests.
- **`frontend/test/e2e_browser/`**: Puppeteer / Node.js browser automation scripts (`*.cjs`).
- **`frontend/test/support/` & `frontend/test/fixtures/`**: Test helpers, mock servers, and static test data.

---

## 4. Enforced Invariants (CI Gate)

CI on GitHub Actions and pre-commit hooks strictly enforce:
1. No hardcoded plugin IDs in `frontend/lib/`.
2. No direct imports from `frontend/lib/` into `plugins/`.
3. Dynamic sidecar port allocation (no hardcoded ports).
4. Manifest Schema v2.1 and `.hlep` freshness.
5. `ProcessSupervisor` dynamic port allocation.
6. God class limits (Frontend <= 900 lines, Backend <= 600 lines).
7. Zero dead code / orphan `.dart` files.
8. Zero loose files in `lib/widgets/` or `lib/services/`.
9. Zero flat test files at `test/` root (except `architecture_test.dart`).
10. Zero ghost path dependencies in `pubspec.yaml`.
