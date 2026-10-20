# Phase 03: God Class Decomposition via Facade Pattern

## Goal
Break down monolithic classes (>2,500 lines) using the **Facade & Composition Pattern** so that all consumer widgets maintain 100% compatibility while internal state is cleanly partitioned.

---

## Detailed Tasks

### 1. Refactor `StudioState` with Sub-Controllers (Facade Pattern)
- Current State: `studio_state.dart` + 5 `part` files (~2,500 LOC) combining:
  - Canvas strokes & history
  - Smart pen oval detection & snap
  - PDF document lifecycle & annotations
  - Audio translation & mic mute listener
  - Plugin contributed tools
- Strategy:
  - Create dedicated controller classes:
    - `SmartPenStateController`: manages answer classification, oval detection, and answer selection history.
    - `PdfStageStateController`: manages document opening, page bounds, and annotation attachments.
    - `AudioSyncController`: manages translation state, speech-to-text bridge, and mic mute synchronization.
  - Keep `StudioState` as a unified **Facade**:
    - `StudioState` composes the sub-controllers.
    - Existing getters (`tool`, `smartSnapEnabled`, `saveAnswerCirclesEnabled`, `page`, etc.) and methods delegate directly to the sub-controllers.
    - Sub-controllers notify `StudioState`, which triggers `notifyListeners()`.
    - Zero disruption or refactoring needed for consuming canvas widgets (`StrokeCanvas`, `StudioTopBar`, `PdfStageViewer`).

### 2. Decompose Massive Presentation Dialogs / Screens
- Files:
  - `SelectClassroomDialog` (828 LOC)
  - `AuthFormCard` (856 LOC)
- Extract discrete sub-widgets (e.g. `LoginFormView`, `OtpSignupFormView`, `ClassroomRoomListTile`).
- Reduce screen files to declarative orchestrators under 400 LOC.

---

## Verification Commands
```powershell
flutter test test/architecture_test.dart
flutter test
```

