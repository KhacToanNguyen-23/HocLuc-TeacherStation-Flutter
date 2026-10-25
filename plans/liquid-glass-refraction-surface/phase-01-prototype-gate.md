# Phase 01 — Production-Shaped Shader and Transparency Prototype

**Maps to:** P1 dock, P1 result card, P1 SDK contract  
**Depends on:** Completed `plans/liquid-glass-extension-ui/` Phases 01–04. The earlier Phase 01 approved the opaque WebView fallback and left the 55 FPS target open; its Flutter `RepaintBoundary` image suggests alpha through the WebView texture in the captured scene, but does not independently confirm composition in a native Windows window. This phase reopens composition specifically for shader scene sampling.

## Goal

Prove that Flutter's shader-filter path samples the real Flutter stage below both the clipped dock and a shader layer beneath a transparent native WebView. Establish repeatable performance baselines before building production abstractions.

## Work

1. In a disposable/minimal prototype placed in the actual studio stage, draw recognizable board strokes and a PDF edge, then apply `ImageFilter.shader` through a clipped `BackdropFilter` in the dock bounds. Verify visible distortion samples those exact Flutter pixels.
2. Check `ImageFilter.isShaderFilterSupported` at runtime on the supported Windows Impeller build. Record Flutter/Impeller/runtime versions and the support result.
3. Configure the Windows native WebView background as transparent before first navigation. Give the document and relevant plugin surface transparent CSS backgrounds. Place a shader fragment below a production-shaped WebView and above the board/PDF; verify that the shader still samples Flutter scene pixels through the WebView composition, with plugin text visible above it.
4. Do not accept alpha visibility alone as proof. Save a short capture/evidence showing board/PDF edges refracted in both test locations. Do not use WebView DOM snapshots or per-frame board bitmap transfer as a substitute.
5. Profile baseline and prototype dock drags in Flutter profile mode for 10 seconds each on a sparse-board scene and a dense-board/PDF scene. The prototype profile must keep the production-shaped transparent WebView and registered result-card shader visible while dragging, so the result includes combined load. Record a dock-only diagnostic, device, display scale/DPI, renderer, UI and raster timings, and p95 frame interval.

## Gate and fallback

- **Pass:** Runtime shader support is true; dock and under-WebView shaders visibly distort board/PDF pixels; plugin content remains above the underlay; frame p95 ≤18.2 ms in both scenes. Proceed to production renderer.
- **Conditional pass:** Sampling and composition work, but the performance target fails. Profile UI/raster costs, test cheaper shader parameters, and evaluate drag-time refraction pause. Re-run the same two 10-second profiles; proceed only when target passes or an explicit reduced-scope fallback is recorded.
- **Fallback:** Shader unsupported or scene sampling fails under native WebView. Keep the documented opaque WebView fallback; dock may proceed only if its shader works independently. This is safe runtime behavior, but it leaves the P1 result-card refraction criterion unmet. Do not mark this plan complete unless the result-card criterion later passes or the user explicitly approves a spec revision that removes or defers it. No DOM capture or per-frame bitmap streaming.

## Acceptance criteria

- Runtime capability and actual stage sampling evidence are recorded independently for dock and transparent WebView placement.
- The WebView surface is transparent before its initial navigation; plugin text is legible and remains composited above the shader.
- Combined dock + result-card shader profile runs record UI and raster frame timing and p95 interval; the 18.2 ms threshold is evaluated separately for sparse and dense scenes. Dock-only captures remain diagnostic.
- Gate outcome and supported scope are documented before production code proceeds.

## Tests to write first

- Add a feature-local host widget test under `frontend/test/features/studio_board/` for clipping, shader fallback visibility/state, and visual-only pointer/semantics behavior where Flutter's test renderer supports the API.
- Add/extend a host test under `frontend/test/features/plugin_engine/` verifying transparent configuration is applied before the initial navigation call, using an injectable/fake controller seam if needed.
- Native pixel sampling and profile frame timing remain manual Windows profile gates; do not represent them as covered by widget tests.

## Gate record — 2026-10-21

**Outcome: reduced-scope continuation for the dock; result-card and performance gates remain open.** The user approved keeping the card on the opaque fallback if WebView composition cannot be validated, and keeping the P1 result-card story open.

- Windows profile build reported Impeller `OpenGLESSDF`. The prototype loaded the fragment shader and saved `evidence/phase-01-shader-composition.png`, but this is a `RenderRepaintBoundary.toImage` capture, not a native window capture. The card area appears dark and no recognizable board/PDF detail is demonstrated through the under-WebView shader region, so this image does not prove scene sampling or alignment. A prior `RepaintBoundary` image suggests alpha through the WebView texture in Flutter's captured scene, but that indication is not native-window proof. Treat both as prototype evidence only; a valid Windows desktop capture is still required for visual sign-off.
- The shader now flips sampled Y coordinates for OpenGLES. `flutter build windows --profile -t tool/liquid_glass_composition_prototype.dart` completed successfully after this correction.
- `flutter test test/features/plugin_engine/flat_host_native_transparency_test.dart test/features/plugin_engine/liquid_glass_surface_fallback_test.dart` passed (3 tests). The host test confirms transparent WebView background is set after initialization and before first navigation.
- No valid Phase 01 baseline timing evidence was produced. Later Phase 02 timer-driven diagnostics are recorded in `evidence/phase-02-frame-timings.txt`; they are not pointer-drag measurements or a Phase 01 baseline. Do not claim the 18.2 ms target passed; record the device/display/DPI and capture both profiles during final validation.
- A later direct-capture attempt in this environment could not produce usable native window pixels: the prototype window remained 50×50 after resize, `CopyFromScreen` failed with an invalid handle, and `PrintWindow` returned a black image. This environment therefore cannot close the native composition, alignment, or interactive profiling gates.
- Proceeding scope: Phase 02 may implement the dock renderer only. Keep the plugin card on opaque fallback until WebView sampling and combined frame pacing are verified. P1 result-card refraction remains open.
