# Brainstorm: StudioState God Object Decomposition into Domain Controllers

**Date:** 2026-10-19

## Ideas Explored
1. **Full State Management Migration (Bloc / Riverpod):** Completely rewrite state management using Cubits or Providers. Dismissed because it introduces heavy external dependencies, large refactoring churn, and breaks 100+ existing tests across the codebase.
2. **Dynamic Webview Replacement with Native IPC:** Rewrite the Plugin system to replace loopback HTTP server with native IPC. Dismissed because the current dynamic port allocation is functioning smoothly and replacing it now is premature optimization.
3. **Domain Controllers with Coordinator & Facade (Selected):** Decompose the 3,000-line monolithic `StudioState` (currently pseudo-split across 6 `part of` files) into discrete, single-responsibility Domain Controllers (`CanvasDrawingController`, `PdfSmartPenController`, `AudioSyncController`, `StudioPluginBridgeController`), coordinated by a mediator, while maintaining a thin `StudioState` Facade for 100% backward compatibility.

## User's Direction
- Decompose `StudioState` into standard Domain Controllers (familiar from backend architecture paradigms).
- Achieve both goals simultaneously: (A) render performance optimization (drawing strokes/mic activity does not trigger broad tree rebuilds) and (B) strict separation of concerns (teammates/agents can implement deep features without git conflicts).
- Preserve `StudioState` as a backward-compatible Facade so existing tests and callers continue working without regression.
- Restrict scope strictly to `frontend/lib/features/studio_board/` — leave `plugins/` and `backend/` untouched.
- Retain the current loopback server with dynamic ports for plugins since it operates reliably.

## Open Questions
- How to route cross-controller actions (e.g. plugin snipping a PDF region onto canvas) without creating circular references? (Resolved: Use `StudioCoordinator` mediator pattern).
- How to ensure fine-grained leaf rebuilds without massive widget rewrite? (Resolved: Scope `ListenableBuilder` / `ValueListenableBuilder` to dedicated leaf surfaces like `StrokeCanvas`, `AudioMeter`, etc.).

## Risks
- **Memory leaks upon classroom teardown:** Sub-controllers maintaining active streams or listeners with `TeacherMediaService` or `ProcessSupervisor` if not systematically disposed via coordinator lifecycle.
- **Hidden state dependencies:** Unintended side effects if a sub-controller assumes state from another domain before the coordinator initializes it.
