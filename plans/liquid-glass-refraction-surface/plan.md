# Plan: Board-Aware Liquid Glass Refraction Surfaces

**Mode:** Hard  
**Risk:** normal â€” this is a multi-component visual feature with a runtime fallback and measurable performance gate, but it changes no persistent data or infrastructure.  
**Spec:** `plans/liquid-glass-refraction-surface/spec.md`  
**Follow-up:** `plans/liquid-glass-extension-ui/` Phases 01â€“04

## Scope challenge

- **Exists?** Partial. The prior liquid-glass work completed the Flutter glass container, preset state, SDK transport, and a transparent-background prototype. Its `RepaintBoundary` image suggests alpha through the WebView texture in Flutter's captured scene, but it is not a native Windows window capture. The approved fallback kept production WebView content opaque. Neither the old image nor the newer dark under-WebView shader capture proves that a Flutter shader samples board/PDF pixels through the production WebView surface. `LiquidGlassContainer` currently uses blur. The stage draws the board before overlay layers, which is the intended sampling surface.
- **Minimum?** First prove a clipped `ImageFilter.shader` inside the actual stage samples board/PDF pixels, and prove a shader placed beneath a production-shaped transparent native WebView still samples the Flutter scene. Only then build the common shader renderer and region lifecycle.
- **Complexity:** Hard. Requires coordinated Flutter rendering, native WebView transparency, SDK region messages, coordinate calibration, lifecycle safety, and profiling.

## Spec quality check

- **NEEDS CLARIFICATION:** None. Windows-first support, fallback behavior, accepted variable text contrast, story priorities, and measurable thresholds are stated.
- **Measurable success criteria:** Yes: 2 logical-pixel alignment, 50 ms preset updates, p95 frame interval â‰¤18.2 ms over two 10-second scenes, and architecture/analyzer/package gates.
- **Prioritized stories:** P1 and P2 are explicit and mapped below.
- **Testable acceptance criteria:** Yes. Geometry/lifecycle and bridge behavior are automatable; shader sampling, native composition, and frame timing require a repeatable Windows profile run.
- **Implementation risks:** `ImageFilter.shader` support is Impeller-only and alpha alone is insufficient evidence. These are explicit Phase 01 go/no-go checks, not assumed capabilities.

**Verdict: PASS with a Phase 01 feasibility gate.** The spec is ready to plan; the shader and WebView composition remain implementation hypotheses until proven by the prototype.

## Architecture and implementation constraints

- Keep Flutter code within `frontend/lib/core/` and `frontend/lib/features/`; follow existing feature-first architecture and test hierarchy.
- Keep host rendering generic. Do not hardcode plugin IDs/subject names in `frontend/lib/`, import plugin files into Flutter, or replace plugin-owned result markup with Flutter widgets.
- Use `window.HocLuc` for plugin registration and host events. Add no direct `window.chrome.webview.postMessage` calls.
- Model a region identity as `(WebView instance token, region id)`. Validate finite, bounded rectangles; coalesce updates; reject stale navigation generations; clear on hide, navigation, and dispose.
- Convert `getBoundingClientRect()` CSS viewport pixels using the WebView RenderBox origin and an empirically calibrated viewport-to-logical scale. Do not multiply by device pixel ratio as a shortcut.
- Configure transparent native WebView background before its first navigation, and transparent plugin document surfaces. Place host shader regions above the board/PDF and beneath WebView text. Apply `IgnorePointer` and `ExcludeSemantics` to shader-only overlays.
- Check `ImageFilter.isShaderFilterSupported` at runtime. Unsupported runtime, alpha, or shader cases use the documented opaque fallback.
- If plugin assets or manifest change, bump that plugin's SemVer and run `node scripts/package_plugin.mjs <plugin_folder>`; run the validator after packaging.

## Validation decisions

- If shader sampling works for the dock but fails through native WebView composition, continue with the dock and keep the plugin result card on the opaque fallback. The P1 result-card criterion remains open; the plan is incomplete unless it later passes or the user approves a spec revision.
- Use the existing English Assistant as the integration example for the generic SDK contract. Keep the host implementation plugin-agnostic; if plugin assets or manifest change, bump its SemVer and rebuild the `.hlep` package.
- S/V/O token-level refraction remains optional and may be enabled only if the combined performance gate still passes; otherwise defer it.

## Story mapping

| Story | Phase(s) | Acceptance target |
|---|---|---|
| P1 â€” Refractive dock | 01, 02, 04 | Dock shader demonstrably distorts live board/PDF pixels inside clipped bounds; presets retain configured appearance; 10-second drag p95 â‰¤18.2 ms on sparse and dense scenes. |
| P1 â€” Refractive plugin result card | 01, 03, 04 | Production-shaped transparent WebView proves Flutter-scene sampling under the registered result card; text remains plugin-rendered above it; bounds stay within 2 logical px. |
| P1 â€” Generic glass-region SDK contract | 03, 04 | SDK registers, updates, unregisters; host converts/validates/coalesces geometry; stale/hidden/disposed regions are removed. |
| P1 â€” Accessible, non-intercepting UI | 02, 03, 04 | Keyboard activation, focus, semantics, pointer pass-through, and reduced-motion requirements pass; shader overlay adds no semantics. |
| P2 â€” Refractive S/V/O capsules | 04 (conditional) | Enable only after one-card region performance passes; never register more than one region per result card. Defer if frame budget fails. |

## Phases

1. [Phase 01 â€” Production-shaped shader and transparency prototype](phase-01-prototype-gate.md)
2. [Phase 02 â€” Shared host shader renderer and dock](phase-02-shader-renderer-dock.md)
3. [Phase 03 â€” SDK glass regions and coordinate lifecycle](phase-03-sdk-glass-regions.md)
4. [Phase 04 â€” Integration, profiling, accessibility, and packaging](phase-04-integration-validation.md)

## Risks and gates

- **Shader unsupported:** `ImageFilter.shader` is Impeller-only. Phase 01 checks `ImageFilter.isShaderFilterSupported` and actual Windows rendering before production use. Keep the current opaque fallback when unavailable.
- **Alpha works but scene sampling does not:** Alpha-only evidence is explicitly insufficient. The prototype must show recognizable board strokes/PDF edges being refracted by the dock shader and by a shader beneath the transparent native WebView.
- **Native composition breaks shader sampling:** Test the transparent WebView in actual stage composition with realistic bounds and layering. If the host shader cannot sample Flutter content beneath it, keep the WebView opaque and defer the P1 result-card shader; do not substitute DOM capture or per-frame bitmap streaming.
- **Safe fallback versus feature completion:** The opaque fallback protects usability when shader sampling is unsupported, but it does not meet the P1 result-card requirement. The plan remains incomplete unless result-card sampling is verified or the user approves a spec revision that changes that requirement.
- **SDK source divergence:** `PluginWebServer` currently injects and serves an embedded SDK string while a standalone SDK asset also exists. Phase 03 must consolidate to one runtime source or keep both copies in parity, and test the actual served SDK route.
- **Coordinate drift:** Calibrate CSS viewport-pixel to Flutter logical-pixel scale empirically; exercise scroll, resize, replacement, visibility, host movement, DPI, and zoom. Clear regions on hide/navigation/disposal and protect against late events with navigation generations.
- **Frame budget exceeded:** Profile Flutter UI and raster frame timings, p95 â‰¤18.2 ms for 10 seconds on both sparse and dense scenes with dock and result-card region visible. Dock-only runs are diagnostic. Optimize before sign-off; reduce live refraction while dragging only if measurements justify it and restore immediately after drag end. P2 capsules are deferred first.
- **Input/semantics regression:** Shader overlays are visual-only (`IgnorePointer`, `ExcludeSemantics`); plugin controls and accessible state stay in the WebView/host control layers.

## Verification plan

Tests belong under `frontend/test/features/plugin_engine/` and `frontend/test/features/studio_board/`; do not add flat tests under `frontend/test/`. Use feature tests for SDK contract, validation, event generation, lifecycle cleanup, and host widget semantics. Use a Windows profile run for native shader availability, actual scene sampling, transparency ordering, alignment, and UI/raster frame timings.

Completion gates from repository guidance: `node scripts/validate_plugins.mjs`; `flutter test test/architecture_test.dart` from `frontend/` with 12/12 invariants; `flutter analyze --no-fatal-infos`; package any modified plugin and confirm freshness. Planning does not run tests. Do not claim a successful shader surface if only alpha transparency has been observed.

## Cook handoff

`$bb-cook --hard --tdd plans/liquid-glass-refraction-surface/plan.md`

## Session notes â€” 2026-10-21

- Phase 01 established reduced-scope dock continuation; the WebView result card remains on opaque fallback.
- Phase 02 renderer/dock implementation is in place and reviewed. The user approved deferring the interactive 18.2 ms gate. Timer-driven diagnostics have ranged from 33.33 ms p95 in earlier sweeps to 17.84/17.76 ms in the previous sparse/dense prototype run; neither represents pointer dragging with a visible result-card region, so they do not close the gate.
- Focused renderer/dock/fallback tests pass (20); the latest analyzer reports no issues; architecture gate passes 12/12; the normal Windows profile build succeeds. Earlier synthetic p95 was 33.33 ms, while the previous sparse/dense timer runs were 17.84/17.76 ms; interactive mouse-drag profiling remains open.
- Phase 03 SDK region lifecycle and English Assistant integration are implemented under the approved opaque-card fallback. The focused suite currently passes 30 tests; the P1 WebView visual sampling/alignment gate remains open.
- Phase 03 hard-review fixes now cover document-generation races, retained WebView senders, hidden-view lifecycle, viewport clipping, ancestor opacity, mutation observer options, and stale disposers. Phase 04's focused glass/host/preset/accessibility suites pass 54 tests across 11 files; analyzer reports no issues, architecture passes 12/12, plugin validation reports all 3 packages fresh, and `flutter build windows --profile --no-pub` succeeds. Manual WebView sampling/alignment and interactive combined-drag profiling remain open, and S/V/O shader regions are deferred.
- Direct Windows capture was attempted for Phase 04 but could not return native window pixels (the prototype process exposed no top-level window handle; direct launch of the normal app produced an off-screen 50Ã—50 window, and subsequent `PrintWindow` output was black while `CopyFromScreen` failed with an invalid handle). The existing `RenderRepaintBoundary.toImage` artifact is only suggestive alpha evidence and does not prove WebView scene sampling. P1 card sampling/alignment and interactive 18.2 ms p95 profiling remain open pending a usable Windows desktop capture session.

- Earlier elevated Windows profile run (2026-10-21): the prototype built and used Impeller/OpenGLES, then recorded synthetic timer-driven interval p95 19.24 ms sparse and 30.69 ms dense (UI p95 1.13/1.11 ms; raster p95 4.09/4.46 ms). Both interval results exceed 18.2 ms. Process inspection and Win32 top-level-window enumeration found no HWND for the prototype process, so this run still provides no native capture or real drag evidence. No acceptance gate is closed; optimize the measured workload and repeat in an interactive desktop session.


- Follow-up profile run at 2026-10-21 23:59:41–23:59:52 (system trace time): synthetic sparse/dense interval p95 was 28.14/28.03 ms (562/571 intervals), with UI p95 1.33/1.21 ms and raster p95 4.56/5.41 ms. Both exceed 18.2 ms. The profile run remains timer-driven and ran without a usable native app window; it does not verify real drag or combined WebView workload.
- Direct-launch capture diagnostics on 2026-10-22 found a visible `HocLucStation` top-level window at 10,10–1450,892 for one bundle, but `PrintWindow` returned a blank Flutter surface and desktop `CopyFromScreen` failed with an invalid handle. A capture of the `FLUTTERVIEW` child was also blank. This is not scene-sampling evidence; discard the temporary blank capture artifact.

- Follow-up WGC diagnostics on 2026-10-22 compiled a temporary capture helper and confirmed the HWND in the same PowerShell desktop session, but GraphicsCapture reported `0x80070424` (the specified service does not exist); running the helper elevated could not resolve that session's HWND. No native frame was captured, so WebView scene sampling, real alignment, and interactive performance remain open.
- Follow-up capture alternatives failed before returning pixels: `GraphicsCaptureSession.IsSupported` raised `0x80070424`, opening the per-user CaptureService was denied, and DXGI `DuplicateOutput` returned `0x80070005`. The same desktop HWND is valid in the ordinary PowerShell session. Native capture still needs an interactive Windows capture route with access to the desktop compositor.
- English Assistant's bundled `ui/sdk.js` is now synchronized byte-for-byte with the canonical host SDK. The plugin version is `2.1.1`, its `.hlep` archive was rebuilt, and a parity regression test was added. Plugin validation reports all three archives fresh; the focused glass suite (30 tests), English Assistant/WebView suite (12 tests), Node contract suite (8 tests), analyzer, and 12/12 architecture gate pass. A fresh Windows profile rebuild could not overwrite `WebView2Loader.dll` while the running `HocLucStation` process held it; the earlier successful profile build remains the latest successful build evidence.

- **Continuation on 2026-10-22:** Added manifest-driven `ui.transparent_background` support for Windows WebView2, updated English Assistant to `2.1.2`, and repackaged its `.hlep` archive. Reused WebViews now serialize plugin replacement until the current navigation completes, invalidate the old glass generation, ignore messages during replacement, and place a host-owned opaque layer under WebView2 if restoring an opaque native background fails. The focused transition/lifecycle suite passes 5/5; Node plugin contract passes 9/9; plugin validation reports three fresh archives; architecture passes 12/12; analyzer reports no issues. The broader plugin-engine plus dock regression run reported 92 passes and two failures in permission-sensitive fixtures (`plugin_ui_test.dart` expects annotation insertion without `board:insert_annotation`; `process_supervisor_test.dart` expects storage RPC without `storage`). Both failures reproduce when run alone and are outside this glass change.
- A fresh Windows Release build succeeds. The main-workspace Profile build could not replace `WebView2Loader.dll` while `teaching_companion` PID 1428 was present; no process was stopped. A Profile build then succeeded in an isolated temporary build root linked to current workspace sources. This confirms compilation only: native transparent composition, registered-card alignment, and interactive combined-workload drag timing remain unverified. Existing timer-driven interval samples include 28.14/28.03 ms p95 and cannot satisfy the 18.2 ms interactive gate.


- Current continuation: after confirming the reported-closed PID 1428 still held the project Profile executable, it was stopped under the user's prior close authorization. The project Profile build then succeeded. Focused glass/SDK/accessibility/dock tests pass 57/57, architecture passes 12/12, analyzer reports no issues, and plugin validation reports three fresh archives. The launched app has a visible full-size `HocLucStation` window, but native pixel retrieval is still unavailable in this session (`BitBlt` access denied; `GetDIBits` failed), and UI Automation exposes no child controls. Scene sampling, alignment, and interactive performance acceptance remain unverified.

- **Visual follow-up on 2026-10-22:** The user supplied a dock screenshot showing alpha/translucency over the board, but it does not establish visible refraction and contains no plugin result card or drag measurements. Fixed the host shader's understated cross blur with a normalized 3×3 binomial kernel calibrated to the preset sigma, and synchronized Frosted opacity at `0.28` across Flutter, the canonical plugin stylesheet, and English Assistant. English Assistant is now `2.1.3` and its `.hlep` archive was rebuilt. Focused glass/plugin tests pass 29/29, architecture passes 12/12, analyzer reports no issues, Node contract passes 9/9, and plugin validation reports all three packages fresh. A new Windows Profile build succeeded and was launched as PID 14484 from the isolated build root. The P1 WebView sampling/alignment criterion and interactive sparse/dense 10-second p95 drag gate remain open pending the user's inspection and timing report.
- **Profile recheck:** PID 14484 remains responsive with a visible 1440×882 `HocLucStation` window, and its isolated bundle contains the shader asset built at 01:12. The app-data install contains English Assistant v2.1.3 assets. Older workspace Profile and Debug app instances are also still running (PIDs 17312 and 17544); no app process was stopped. This environment still has no usable native screenshot tool for that Flutter window, and runtime display of the English Assistant result card has not been confirmed.
- **Refraction calibration follow-up on 2026-10-22:** After the supplied screenshot showed board alpha but barely visible grid bending, added a size-relative 4× refraction scale (Frosted maps to 10.5 physical pixels at a 75 px short side) and a regression test. The focused glass/plugin suite passes 29/29; architecture 12/12, analyzer, plugin validator, and Node SDK contract (9/9) pass. Code review confirmed shader uniform layout and pixel/UV conversion against Flutter Impeller texture sizing. Windows Profile rebuilt successfully and launched as PID 2008. The user still needs to confirm visible bending and provide interactive 10-second sparse/dense drag timing; plugin card scene sampling/alignment remains open.
- **Visual artifact follow-up on 2026-10-22:** The user screenshot showed refraction pulling a board-page tab into long streaks where the dock overlapped it. Capped shader displacement at 8 physical pixels, independent of the backdrop input texture size. Focused glass/plugin suite passes 29/29; architecture 12/12; analyzer has no issues; Node contract passes 9/9; plugin validator reports all three archives fresh. Review confirmed uniform slots and pixel conversion. Rebuilt Profile and launched PID 14464. Remaining: inspect whether the streaks are resolved, record interactive sparse/dense 10-second drag timing, and verify plugin-card scene sampling/alignment.
- **Regional centering & plugin iOS makeover continuation on 2026-10-23:** Replaced screen-origin normalized shader coordinates with regional container-relative UVs (`u_region_origin`, `u_region_size`) in `liquid_glass.frag` and integrated `_GlassShaderPaintBoundary` in `liquid_glass_container.dart` to calculate live physical bounds during paint. Refraction lens profile, edge rim, and specular highlight are now centered on each glass container, eliminating directional streaking at screen edges. Fulfilling the user's `/goal` request for iOS/iPhone styling, updated `plugins/english_assistant/ui/style.css` and `frontend/assets/scripts/liquid-glass.css` with pill shapes, top specular rim catchlights (`inset 0 1.5px 1px rgba(255,255,255,0.7)`), segmented controls, and tactile active scaling. Advanced English Assistant to v2.1.4 and rebuilt `.hlep`. Plugin validator (3 fresh), architecture (12/12), analyzer, Node contract (9/9), and 39 glass tests pass. P1 result-card refraction stays on the opaque fallback, and interactive 10-second drag profiling remains open for live desktop verification.
