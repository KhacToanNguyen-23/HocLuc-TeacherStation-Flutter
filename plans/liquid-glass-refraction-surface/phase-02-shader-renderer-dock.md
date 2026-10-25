# Phase 02 — Shared Host Shader Renderer and Dock

**Maps to:** P1 refractive dock, P1 accessibility  
**Depends on:** Phase 01 pass for dock sampling; if only WebView sampling fails, continue with dock-only scope and retain result-card fallback.

## Goal

Replace the current blur-only `LiquidGlassContainer` rendering path with a reusable fragment-shader renderer and use it for the board tool dock without changing manifest-driven tool contributions.

## Work

1. Add shader asset(s) and a reusable renderer in `frontend/lib/core/` following the existing shader asset/loading conventions. Check support at runtime and retain the current opaque/blur appearance as fallback.
2. Render the board-aware dock surface with `BackdropFilter` and clipped shader filtering only where the Phase 01 prototype verified stage sampling. Keep shader bounded to the dock shape.
3. Use Clear/Frosted/Solid as named configurations for tint/opacity, refraction, blur, rim, and specular intensity. Keep the existing preset cycle and update all visible host surfaces within the 50 ms target.
4. Keep the dock control accessible: keyboard activation, visible focus, accurate semantic state, no unnecessary lighting animation, and honor reduced-motion settings.
5. Compare profile timings against Phase 01 in both scenes. Only pause expensive refraction during active drag if measurements show it is needed; restore it immediately at drag end.

## Acceptance criteria

- On supported Windows Impeller, clipped dock shader visibly refracts board strokes and PDF edges; the unsupported path visibly selects the documented fallback.
- All three presets map to distinct configured appearance values and changes propagate to host surfaces within 50 ms.
- Shader painting is confined to dock bounds and does not intercept board input or add duplicate semantics.
- Sparse and dense 10-second drag tests each meet p95 frame interval ≤18.2 ms, including both UI and raster timing. If not, work remains open for optimization/fallback decision.

## Tests to write first

- Add/extend tests under `frontend/test/features/studio_board/` for preset rendering configuration, dock clip bounds, fallback state, keyboard activation, semantics, focus, and reduced-motion behavior.
- Add a core shader capability/fallback test under a relevant existing feature directory; do not create root-level test files.

## Phase 02 implementation and gate record — 2026-10-21

**Outcome: dock renderer implemented; interactive performance gate remains open.** User approved dock-only continuation with the plugin result card on its opaque fallback and the 18.2 ms target deferred until an interactive Windows run.

- Added distinct Clear/Frosted/Solid renderer configurations, runtime shader support detection, a cached shader program, clipped shader rendering, and blur fallback. The dock retains manifest-driven tool contributions and exposes a keyboard-operable glass preset control with semantic state and visible focus.
- Removed drag-time shader disabling. The current implementation keeps the shader active while the dock moves; only measurement may justify changing that behavior.
- Synthetic profile diagnostics are in `evidence/phase-02-frame-timings.txt`. Earlier timer-driven sweeps reported 33.33 ms p95. A later profile prototype run reported 17.84 ms sparse and 17.76 ms dense p95, with UI p95 1.01/1.13 ms and raster p95 3.89/4.16 ms, on Windows 10 Home Build 26200 at 1426×844 logical pixels, 1.25× / 120 DPI, Impeller/OpenGLES. These values vary between timer-driven harness runs and do not represent actual pointer dragging or a visible registered plugin card; they are diagnostics only and cannot close the 18.2 ms acceptance gate.
- The profile prototype captures the initial shader composition in `evidence/phase-01-shader-composition.png` and the opaque plugin-card fallback during profile capture in `evidence/phase-02-dock-opaque-fallback.png`. The plugin card remains out of production scope until its WebView composition gate passes.
- A re-review confirmed the earlier drag-time filter-disable finding is fixed and found no further concrete issue in the reviewed renderer/dock scope.
- Focused glass renderer, dock, and plugin fallback tests pass (20 total). The repository analyzer passes with one pre-existing informational lint in `flat_host_native_transparency_test.dart`; no warnings or errors. The architecture gate passes 12/12 invariants.
- `flutter build windows --profile --no-pub -t tool/liquid_glass_composition_prototype.dart` succeeds after closing the prior profile process that held `WebView2Loader.dll`. The test runner initially appeared stalled because the Flutter SDK cache was outside the writable workspace; running the authorized command with SDK access resolved it.

**Open gates:** run focused tests, analyzer, architecture gate, interactive sparse/dense mouse-drag profiling, and final integration validation. Do not mark P1 dock performance or P1 result-card refraction complete from timer diagnostics or alpha-only composition evidence.

**Follow-up synthetic profile (2026-10-21):** A later profile run reported sparse interval p95 19.24 ms and dense interval p95 30.69 ms (UI p95 1.13/1.11 ms; raster p95 4.09/4.46 ms). Both exceed 18.2 ms. The run used timer-driven offsets and did not expose a native window handle, so it is diagnostic only; no frame-budget acceptance is claimed. See the Phase 04 validation record for the capture limitation.

**Latest timer-driven profile run (system trace time 2026-10-21 23:59:41–23:59:52):** sparse/dense interval p95 28.14/28.03 ms (562/571 intervals), UI p95 1.33/1.21 ms, raster p95 4.56/5.41 ms. Both scenes exceed 18.2 ms. These remain synthetic timer sweeps without a visible registered card or real pointer drag, so they do not meet the acceptance measurement.
