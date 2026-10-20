# Spec: StudioState God Object Decomposition into Domain Controllers

**Date:** 2026-10-19
**Status:** Ready

---

## Problem Statement
The current `StudioState` is a 3,000-line monolithic God Object that has been syntactically fragmented across 6 `part of` files (`studio_state_annotations.dart`, `studio_state_pdf.dart`, `studio_state_smart_pen.dart`, `studio_state_plugins.dart`, `studio_state_serialization.dart`) simply to bypass line-count CI gates. This creates unnecessary coupling, triggers full-screen re-renders during high-frequency drawing/audio events, and makes parallel development on deep features prone to regressions.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher drawing on the 16:9 chalkboard, I want high-frequency pen strokes to only trigger rebuilds on the `StrokeCanvas` leaf widget, so that my drawing latency stays under 16ms (60-120fps) without re-rendering top bars, inspector drawers, or audio meters.
  Accepted when: Profiling verifies zero rebuilds outside `StrokeCanvas` during continuous drawing strokes.

- **[P1]** As a core team member working on Smart Pen or Audio, I want domain-isolated controllers (`CanvasDrawingController`, `PdfSmartPenController`, `AudioSyncController`, `StudioPluginBridgeController`), so that I can implement deep features without touching unrelated files or suffering git merge conflicts.
  Accepted when: Each domain logic resides in an independent `ChangeNotifier` class with zero private `part of` cross-access.

- **[P1]** As a developer or CI pipeline, I want existing tests and legacy call-sites to remain 100% operational through a thin backward-compatible `StudioState` Facade, so that test suites pass without breaking regression.
  Accepted when: `flutter test test/features/studio_board/` passes 100% without modification to existing test contracts.

- **[P2]** As an application host, I want all sub-controllers and listeners to be systematically disposed when leaving the classroom, so that memory leaks and dangling background timers are completely prevented.
  Accepted when: Coordinator `dispose()` tears down all domain listeners and unhooks from native media services cleanly.

- **[P3]** _(out of scope — noted for future: complete migration to Riverpod/Bloc across all application screens)_

---

## Functional Requirements

1. **FR-01: Discrete Domain Controllers Scaffolding**
   - Create `CanvasDrawingController` handling `BoardStroke`, undo/redo stacks, freehand smoothing, stickers, and shapes.
   - Create `PdfSmartPenController` handling PDF document caching, page indexing, smart pen gesture recognition, and oval answer snapping.
   - Create `AudioSyncController` managing `AudioTranslationService`, mic mute state, input level metering, and translation sync.
   - Create `StudioPluginBridgeController` implementing `PluginHostBridge` and handling iframe/webview communication, tool actions, and dynamic port RPCs.
   - Create `StudioWorkspaceCoordinator` managing session lifecycle, title/subject, planning mode, speaker notes, and dirty/save state.

2. **FR-02: StudioCoordinator Mediator**
   - Establish a mediator pattern where sub-controllers publish domain events (e.g. `onSnipRegionReceived`, `onPageChanged`) and the coordinator dispatches them without direct circular references between sub-controllers.

3. **FR-03: Backward-Compatible StudioState Facade**
   - Retain `StudioState` extending `ChangeNotifier` and implementing `PluginHostBridge` as a facade delegating calls directly to the respective domain controllers.

4. **FR-04: Elimination of Pseudo-Modular `part of` Files**
   - Remove the 6 `part 'studio_state_*.dart'` declarations and replace them with properly encapsulated classes with explicit public APIs.

---

## Non-Functional Requirements

- **Performance:** Drawing continuous strokes must not rebuild unrelated UI components (`StudioTopBar`, `StudioStudentsDrawer`, `StudioAudioMeter`). Frame time during drawing $\le$ 16ms on Windows Desktop.
- **Maintainability:** Each controller file must strictly adhere to the $\le$ 900 line CI architecture limit without using `part of` syntactic tricks.
- **Memory Safety:** Calling `dispose()` on `StudioState` / `StudioWorkspaceCoordinator` must release all `ChangeNotifier` listeners and cancel all `Timer` and `StreamSubscription` instances.

---

## Success Criteria

- [ ] All 6 `part 'studio_state_*.dart'` files are removed or refactored into independent domain controllers.
- [ ] `flutter test test/features/studio_board/` passes 100% (zero test regressions).
- [ ] `flutter test test/architecture_test.dart` passes 12/12 invariants.
- [ ] `flutter analyze --no-fatal-infos` returns 0 errors and 0 warnings.

---

## Out of Scope

- Changing the loopback HTTP server or plugin architecture for plugins in `plugins/`.
- Backend Spring Boot modifications.
- Introducing heavy third-party state management libraries (Bloc, Riverpod) in this iteration.

---

## Assumptions

- Sub-controllers can effectively communicate through standard Flutter `Listenable` and coordinator callback/event patterns.
- The existing UI widgets can either read the Facade `StudioState` or directly bind to specialized sub-controllers without changing their public widget constructor contracts.
