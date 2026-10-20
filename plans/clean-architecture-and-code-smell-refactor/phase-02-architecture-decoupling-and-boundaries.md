# Phase 02: Architecture Decoupling & Boundary Enforcement

## Goal
Restore clean module boundaries and eliminate inverted dependencies and cyclic feature couplings in `frontend/lib/`.

---

## Detailed Tasks

### 1. Decouple `LocalService` (Core → Feature Leak)
- Problem: `frontend/lib/core/network/local_service.dart` imports `planning_meta.dart` from `features/classroom_meet/` and houses planning endpoints.
- Solution:
  - Keep `LocalService` strictly as an HTTP/RPC orchestration client (raw request/get/post/delete, authentication headers, bootstrap token).
  - Extract `PlanningRepository` / `PlanningApiService` into `frontend/lib/features/classroom_meet/services/planning_repository.dart`.
  - Remove `import '...planning_meta.dart'` from `local_service.dart`.
  - Update `ClassroomDashboardScreen` and `select_classroom_dialog.dart` to consume `PlanningRepository`.

### 2. Centralize Authentication & Break Circular Feature Imports
- Problem: `GoogleMeetAuthService` is located in `features/classroom_meet/services/` but is imported by `auth`, `exams`, and `classroom_meet`.
- Solution:
  - Relocate or export `GoogleMeetAuthService` via `features/auth/` (e.g. `features/auth/services/google_meet_auth_service.dart` or an abstract auth contract in `core/auth/`).
  - Update imports across:
    - `frontend/lib/features/auth/presentation/auth_form_card.dart`
    - `frontend/lib/features/exams/presentation/screens/exam_workspace_screen.dart`
    - `frontend/lib/features/exams/services/exam_oauth_client.dart`
  - Remove circular compile-time dependencies.

### 3. Decouple `plugin_engine` from `studio_board`
- Problem: `floating_plugin_window.dart` and `plugin_host_drawer.dart` in `features/plugin_engine/` directly import `StudioState` from `features/studio_board/`.
- Solution:
  - Define an abstract interface `PluginHostBridge` or pass explicit event callbacks (`onSnipRegionRequested`, `onToolActivated`) instead of passing the entire monolithic `StudioState`.
  - Keep the plugin subsystem pure and decoupled from the specific board canvas implementation.

---

## Verification Commands
```powershell
flutter test test/architecture_test.dart
node scripts/validate_plugins.mjs
flutter test
```

