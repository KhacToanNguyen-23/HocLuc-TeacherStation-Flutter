# Spec: Board-aware liquid glass refraction surfaces

**Date:** 2026-10-21  
**Status:** Ready

---

## Problem Statement

The current glass treatment uses Gaussian blur and translucent CSS/Flutter fills, so it does not have the refraction, curved rim, or specular lighting shown in the reference. Teachers want the floating dock and plugin result panel to bend the actual chalkboard or PDF pixels behind them while preserving plugin ownership of the result UI.

## User Stories

- **[P1]** As a teacher, I want the floating tool dock to refract the live board/PDF behind it so that the controls feel like the reference glass surface without hiding the lesson.
  Accepted when: the Windows dock samples and visibly distorts the Flutter-rendered scene behind its clipped bounds, and the Clear/Frosted/Solid control changes its configured glass appearance.

- **[P1]** As a teacher, I want the plugin result card to refract the actual board/PDF behind the native WebView so that its glass surface matches the dock and reference.
  Accepted when: the WebView is transparent, the plugin registers the result-card bounds through the HocLuc SDK, and a host-owned Flutter shader layer aligns beneath the card and samples the Flutter scene rather than only WebView DOM content.

- **[P1]** As a plugin developer, I want a generic SDK contract for requesting host-rendered glass regions so that any compliant plugin can use the shared renderer without plugin IDs or direct package imports in `frontend/lib/`.
  Accepted when: a plugin can register, update, and unregister a glass region through `window.HocLuc`; the host maps its viewport bounds to Flutter logical coordinates; and the existing registered region is removed when hidden, replaced, or disposed.

- **[P1]** As a teacher using keyboard or reduced-motion settings, I want controls and state changes to remain operable and understandable while the visual surface is refractive.
  Accepted when: the dock preset control retains keyboard activation, semantics, and visible focus; the shader overlay receives no pointer input or duplicate semantics; and reduced-motion disables nonessential animated lighting.

- **[P2]** As a teacher, I want S/V/O capsules to use the same refractive material so that the result hierarchy feels cohesive.
  Accepted when: individual token regions can be enabled without registering more than one WebView glass region per result card or exceeding the performance gate. Defer if prototype measurements show material cost is too high.

## Functional Requirements

1. **FR-01:** Implement one host-owned Flutter fragment-shader renderer usable by both `LiquidGlassContainer` and registered plugin glass regions. Use the existing Clear, Frosted, and Solid preset state as named configurations for opacity/tint, blur, refraction, rim highlight, and specular intensity.
2. **FR-02:** Keep plugin result markup, text, buttons, and token generation inside the plugin WebView. The host overlay is purely visual, clipped to registered bounds, `IgnorePointer`, and excluded from the semantics tree.
3. **FR-03:** Extend the injected HocLuc SDK with a generic glass-region registration lifecycle. Use the SDK bridge for all plugin-to-host messages; do not post arbitrary WebView messages directly.
4. **FR-04:** Map plugin viewport rectangles into Flutter logical coordinates using the WebView origin and current scale. Refresh on registration, result visibility/content changes, page scroll, resize, and WebView movement; unregister stale regions on hide, navigation, and disposal.
5. **FR-05:** Set the Windows WebView background and plugin document background transparent for registered glass composition. Preserve a documented opaque CSS fallback if runtime shader or alpha composition is unavailable.
6. **FR-06:** Keep the shader surface beneath WebView text and above the board/PDF; do not intercept pointer events or board input.
7. **FR-07:** Reuse the current shader beneath the dock and registered result card. Pause expensive refraction while the dock is actively dragged only if the frame-time prototype requires it; restore it immediately after drag ends.
8. **FR-08:** Keep host code plugin-agnostic and keep all code within existing feature-first directories. If English Assistant assets or manifest change, bump its SemVer and rebuild the `.hlep` package.

## Non-Functional Requirements

- **Platform:** Windows desktop first. Flutter Web synchronization and unverified native platforms are out of scope.
- **Performance:** During a 10-second dock drag, keep the 95th percentile frame interval at or below 18.2 ms (at least 55 FPS) on both sparse-board and dense-board/PDF scenes. Record device, renderer, and measurements. If this fails, profile and optimize before sign-off; no unmeasured claim is allowed.
- **Alignment:** Keep the host shader bounds within 2 Flutter logical pixels of the plugin card after page load, scroll, result replacement, WebView resize, and dock/window movement.
- **Rendering:** Use Flutter `ImageFilter.shader` on the Impeller Windows renderer for host scene sampling. Verify shader availability at runtime and keep the explicit opaque fallback for unsupported conditions.
- **Accessibility:** The user accepts content text contrast depending on the board/PDF behind the glass. Keep keyboard focus, semantics, pointer behavior, reduced-motion support, and the Solid preset; document that text contrast is not guaranteed over arbitrary content.
- **Packaging:** Follow repository plugin SDK bridge, schema, SemVer, `.hlep` freshness, architecture, and analyzer requirements.

## Success Criteria

- [ ] The dock shader visibly refracts actual chalkboard strokes and PDF edges behind the dock on Windows.
- [ ] The result-card shader visibly refracts the same Flutter scene through its transparent native WebView, not a DOM-only snapshot.
- [ ] Region alignment stays within 2 logical pixels across the lifecycle cases listed in FR-04.
- [ ] Clear/Frosted/Solid presets update all visible host and registered plugin surfaces within 50 ms.
- [ ] Dock drag p95 frame interval is at most 18.2 ms on sparse and dense scenes, measured over 10 seconds each.
- [ ] No shader overlay intercepts input or creates duplicate accessibility nodes; keyboard focus and reduced-motion checks pass.
- [ ] Plugin validator has zero errors, all 12 architecture invariants pass, analyzer has zero issues, and modified plugin archives are fresh.

## Out of Scope

- Replacing plugin-owned result content with Flutter widgets.
- Streaming a new board bitmap to WebView every frame.
- Flutter Web event synchronization or non-Windows transparency certification.
- Guaranteeing text contrast for every arbitrary board/PDF color.
- Animated decorative lighting unrelated to pointer, focus, or preset state.

## Assumptions

- Windows desktop remains the first supported target, as agreed in the earlier liquid-glass work.
- The earlier Phase 01 `RepaintBoundary` image is suggestive evidence that the WebView texture exposed transparency inside Flutter's captured scene, but it is not a native Windows window capture. Treat alpha composition as promising but not independently confirmed on the actual desktop surface; shader sampling and overlay alignment still require production-shaped visual verification.
- The current Flutter 3.47.6 Windows build uses Impeller by default and exposes `ImageFilter.shader`; verify at runtime before enabling the effect.
- The plugin result card is a semantic glass region; its inner text remains plugin-rendered above the host shader.
- User accepts that content contrast will vary with the live scene and prefers the reference appearance over fixed opaque text backplates.

