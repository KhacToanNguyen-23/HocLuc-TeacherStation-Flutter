# Frontend Architecture & Modular Boundaries

This document defines the high-level architecture, module boundaries, and folder conventions for the Teacher Station Flutter application (`frontend/`).

---

## 1. Architectural Style: Pure Clean Architecture (Feature-First)

The frontend is strictly organized as a Modular Monolith adhering to Clean Architecture principles. Root `frontend/lib/` contains **strictly three entities**:
- **`lib/main.dart`**: Application bootstrap, environment initialization, and top-level theme shell.
- **`lib/core/`**: Cross-cutting foundation shared across features (`network/`, `platform/`, `theme/`, `constants/`, `utils/`, `ui/`).
- **`lib/features/<module>/`**: Self-contained domain modules with clear responsibilities:
  - `presentation/screens/`: High-level full-screen pages.
  - `presentation/widgets/`: Module-specific UI components and dialogs.
  - `services/`: Business logic, network clients, state orchestration.
  - `domain/models/`: Domain entities and state representations.

> [!IMPORTANT]
> Flat root directories such as `lib/screens/`, `lib/models/`, `lib/services/`, `lib/widgets/`, `lib/theme/`, `lib/utils/`, and `lib/constants/` are **strictly forbidden** and enforced by automated CI architecture invariant tests.

---

## 2. Domain Feature Modules

### `lib/features/plugin_engine/`
* **Purpose**: Microkernel plugin runtime host and sidecar manager.
* **Services**: `PluginManager`, `PluginStorageManager`, `PluginMarketplaceService`, `PluginWebServer`, `ProcessSupervisor`, `HostBridge`.
* **Domain Models**: `PluginManifest`, `SubjectPlugin`.
* **Presentation**: `FloatingPluginWindow`, `PluginHostDrawer`, `FlatHost`.
* **Boundary Rules**: Zero hardcoded plugin IDs; plugins communicate exclusively via the dynamic loopback HTTP server and HostBridge RPC.

### `lib/features/auth/`
* **Purpose**: Teacher authentication & Google identity management.
* **Services**: `GoogleConnectionFlow`.
* **Presentation Screens**: `LoginScreen`.
* **Presentation Widgets**: `AuthFormCard`, `AuthHeroPanel`, `FlatAuthModal`, `GoogleWebviewLoginDialog`.

### `lib/features/classroom_meet/`
* **Purpose**: Live virtual classroom orchestration, Google Meet automation, and hardware media streaming.
* **Services**: `GoogleMeetAuthService`, `GoogleWorkspaceApi`, `MeetAutomationService`, `TeacherMediaService`, `MediaDeviceService`, `AudioTranslationService`, `SystemMicrophoneService`, `TeachingLauncher`, `WebviewEnvironmentService`.
* **Domain Models**: `MeetEvents`, `PlanningMeta`, `TeachingTarget`.
* **Presentation Screens**: `ClassroomDashboardScreen`, `ClassroomLobbyScreen`, `GoogleWorkspaceScreen`.
* **Presentation Widgets**: `GoogleMeetView`, `MeetAdmissionButton`, `MeetAdmissionShell`, `MeetWebView`, `FloatingPip`, `CreateClassroomDialog`, `SystemMicrophoneControls`, `dashboard/`, `lobby/`, `workspace/`.

### `lib/features/studio_board/`
* **Purpose**: Teaching canvas, handwriting ink engine, PDF viewer stage, and smart pen integration.
* **Services**: `PdfAnnotationExporter`, `PdfAnnotationHandoutExporter`, `SmartPenAnswerIndex`, `SmartPenAnswerClassifier`, `StrokeClusterer`, `EnglishAnalyzer`, `DgnlService`.
* **Domain Models**: `StudioState`, `BoardSticker`, `SmartChalkAnnotation`, `SmartPenAnswerSelection`, `SmartPenOvalAnnotation`, `StudioBoardModels`.
* **Presentation Screens**: `StudioScreen`, `StudioScreenActions`.
* **Presentation Widgets**: `InteractiveChalkboard`, `PdfStage`, `FloatingPdfWindow`, `FloatingTimer`, `GridPainter`, `PresentationSurface`, `RegionSnippingOverlay`, `SmartChalkOverlay`, `StageContainer`, `StrokeCanvas`, `SubjectToolPalette`, `studio/`.

### `lib/features/exams/`
* **Purpose**: V-ACT & HSA exam paper preparation, grading, and session management.
* **Services**: `ExamApi`, `ExamFile`, `ExamFiles`, `ExamOAuthClient`, `ExamSessionService`.
* **Presentation Screens**: `ExamWorkspaceScreen`, `ExamPaperEditor`, `QuestionReviewDialog`.
* **Presentation Widgets**: `ExamStudioButton`, `ExamWidgets`.

---

## 3. Test Suite Organization

Tests in `frontend/test/` strictly mirror the application structure:
- **`frontend/test/architecture_test.dart`**: Sole root test file acting as the architecture guardian (12 automated invariants).
- **`frontend/test/features/<module>/`**: Feature-specific unit and widget tests.
- **`frontend/test/e2e_browser/`**: Puppeteer / Playwright / Node.js browser automation scripts (`*.cjs`).
- **`frontend/test/support/` & `frontend/test/fixtures/`**: Test helpers, mock servers, and static test data.

---

## 4. Enforced Invariants (CI Gate — 12/12 Invariants)

CI on GitHub Actions and pre-commit hooks strictly enforce all 12 invariants:
1. **Bất biến 1**: Không có chuỗi hardcode tên riêng plugin trong `lib/`.
2. **Bất biến 2**: Không có cổng tĩnh cố định 18888 trong `lib/`.
3. **Bất biến 3**: Không import chéo trực tiếp từ `lib/` vào `plugins/`.
4. **Bất biến 4**: Tất cả plugin trong `plugins/` phải có `manifest.json` Schema v2.1 hợp lệ và gói `.hlep` đồng bộ.
5. **Bất biến 5**: `ProcessSupervisor` phân bổ cổng động không bị trùng lặp.
6. **Bất biến 6**: Chống God Class (Frontend <= 900 dòng, Backend <= 600 dòng).
7. **Bất biến 7**: Không có file `.dart` mồ côi (Dead Code) và không giữ `Map<String, Uint8List>` trong RAM của `InstalledPlugin`.
8. **Bất biến 8**: Cấm file code trôi nổi trực tiếp trong `lib/widgets/` và `lib/services/`.
9. **Bất biến 9**: Cấm file test nằm phẳng ở thư mục gốc `test/` (ngoại trừ `architecture_test.dart`).
10. **Bất biến 10**: Cấm khai báo dependency `path:` ma (thư mục không tồn tại) trong `pubspec.yaml`.
11. **Bất biến 11**: Cấm tồn tại thư mục phẳng `lib/screens/` và `lib/models/` tại root.
12. **Bất biến 12**: Cấm tồn tại thư mục phẳng `lib/theme/`, `lib/utils/`, `lib/constants/` tại root (buộc dùng `lib/core/`).
