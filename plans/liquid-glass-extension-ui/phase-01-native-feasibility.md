# Phase 01 — Native Feasibility and Integration Gate

**Maps to:** P1-1, P1-2, P1-4  
**Depends on:** None

## Goal

Establish whether the desired background-through-WebView composition is possible in the current Windows WebView2/Flutter embedding and baseline the palette drag path before committing to blur-heavy UI. Resolve the one-sender-per-plugin event lifecycle design for drawer and floating views.

## Work

1. Create a minimal, reversible Windows prototype using the current `FlatHost` and board scene. Verify whether board pixels are visible through the WebView surface when the native background and page background are transparent. Record runtime/package versions, steps, screenshots, and result.
2. Measure dock drag frame pacing on the same Windows device in two fixed scenes (sparse board and dense board/PDF). Capture baseline average and 95th percentile frame interval; repeat with the glass prototype if composition works. Target ≥55 FPS (95th percentile frame interval ≤18.2 ms) during a 10-second drag.
3. Change `PluginEventHub` registration to retain multiple live senders per plugin runtime ID. Document close/reopen and transition semantics; disposing one sender must not unregister another.
4. Decide platform scope for event sync. Windows native is the initial target. The Flutter Web `FlatHost` currently exposes neither message nor JS callback wiring; either prove an iframe bridge design and include it in scope, or mark Web synchronization as follow-up.

## Gate and fallback

- **Pass:** Board is visibly composited behind the native WebView, no white/opaque flash appears after load, and drag meets the 55 FPS target. Proceed with native backdrop glass.
- **Conditional pass:** Composition works but misses the target. Proceed with a drag-time blur reduction/disable strategy and remeasure; retain blur at rest.
- **Fallback:** Composition is unavailable or unstable. Proceed with the approved scope: keep the WebView surface opaque/frosted, apply host glass to the dock/frame, and use internal CSS glass where available. Record that board content does not show through the WebView and narrow that specific visual claim before Phase 02.
- **Stop condition:** No styling implementation that depends on transparent native composition begins until one of these decisions is recorded.

## Acceptance criteria

- A short feasibility note records platform/runtime, reproducible steps, evidence, frame pacing, and pass/conditional/fallback outcome.
- Simultaneous drawer and floating instances both receive preset events; disposing either leaves the other registered, and no disposed controller receives events.
- Supported event-sync platforms and unsupported/follow-up platforms are stated explicitly.
- No production plugin IDs or subject names are added to `frontend/lib/`.

## Tests to write first

- Add/extend host lifecycle tests under `frontend/test/features/plugin_engine/plugin_event_hub_test.dart` for two senders, unregistering one sender, dispatch behavior, and disposed sender cleanup, matching the chosen registration contract.
- Add a palette drag/performance harness only if a stable existing test harness can measure it; the 55 FPS gate itself is a manual Windows profile run, not a widget-test assertion.

## Execution status — 2026-10-21

- Implemented per-plugin sender fan-out and cleanup behavior in `PluginEventHub`. The focused lifecycle suite passes (5 tests), including two-view delivery, unregistering one view, pruning failed senders, and removing canceled message streams.
- A Windows profile build of `frontend/tool/liquid_glass_composition_prototype.dart` succeeded with Flutter 3.47.6, `webview_windows` 0.4.0, and WebView2 runtime 155.0.4283.62. The VM connection reported the app running.
- The Flutter-rendered `RepaintBoundary` capture at `evidence/composition-prototype-frame.png` shows chalk lines crossing the WebView texture and is suggestive evidence of alpha in Flutter's captured scene. It is not a native Windows window capture, so it does not independently confirm composition on the desktop surface. The prototype uses the same `webview_windows` controller and texture widget used by `FlatHostNative`, though it did not instantiate the `FlatHost` class itself.
- Manual dock-drag frame pacing was not measured. This environment did not expose an interactive app window for the 10-second drag protocol. Do not report the 55 FPS target as met; the user approved proceeding with the opaque plugin-content fallback while retaining this as final validation.
- Platform scope is Windows desktop first. Flutter Web event synchronization is deferred because its current host lacks event wiring.
- The code review of the latest event hub change returned APPROVED with no concrete findings.

**Phase gate:** Approved to proceed by the user. The prototype capture suggests transparent composition inside Flutter's captured scene, but native Windows window composition was not independently demonstrated. Production plugin pages use the approved opaque-content fallback. The 55 FPS drag criterion remains open for final validation. The profile run also reported a lost device connection after launching, so this screenshot is not a performance result.
