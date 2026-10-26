# Phase 03 — Plugin Glass UI and Event Synchronization

**Maps to:** P1-2, P1-3, P1-4  
**Depends on:** Phase 01 sender/platform contract and Phase 02 generic preset event.

## Goal

Apply a reusable CSS glass token/component layer to the target plugin UI and keep its drawer/floating instances synchronized through the SDK event path.

## Work

1. Add the canonical, versioned `liquid-glass.css` to the host SDK asset route at `/__hocluc_sdk__/liquid-glass.css`. Plugin pages opt in with a stylesheet URL; keep an opaque fallback for standalone/local development. This avoids cross-plugin imports and duplicated sources while keeping the CSS kit subject-agnostic.
2. Style result cards, pills, and S/V/O gem tokens with distinct semantic colors and visible text backing. Map host presets exactly in the shared CSS: `clear` → `--glass-bg-opacity: 0.15`, `--glass-blur: 10px`; `frosted` → `0.50`, `20px`; `solid` → `0.85`, `28px`. Use `backdrop-filter` only as progressive enhancement; define an opaque fallback for unsupported browsers and busy backgrounds.
3. Subscribe using `window.HocLuc.onHostEvent('GLASS_PRESET_CHANGE', handler)` and update CSS custom properties/classes from validated event payloads. Do not use `window.chrome.webview.postMessage` directly.
4. Update `PluginEventHub` registration/dispatch according to Phase 01. Fan out every preset change to all mounted views for the plugin, and rehydrate newly mounted views with the current preset on registration.
5. Add CSS states for clear/frosted/solid and ensure initial page load receives the current preset, not just changes made after mount.

## Acceptance criteria

- Changing preset on the host updates every supported mounted plugin view within <50 ms. Measure 30 alternating preset changes with the plugin page loaded and host idle; include an epoch-millisecond dispatch timestamp in the event, record the CSS-variable update time in the page using `performance.timeOrigin + performance.now()`, and report median and p95. Measure from host dispatch to CSS-variable assignment (not paint completion); all samples must be below 50 ms, and newly mounted views initialize to the current state.
- The plugin listens through `HocLuc.onHostEvent`; no raw WebView bridge API is used.
- The shared CSS token values for all three presets match the host values exactly (opacity tolerance ±0.05; blur sigma 10/20/28px where supported).
- S/V/O tokens remain distinguishable without relying on hue alone, and text over cards meets ≥4.5:1 against the defined backing surface in all three modes.
- On unsupported CSS `backdrop-filter`, controls/results remain readable using the opaque fallback.
- Plugin assets remain within the plugin package boundary and are not imported from `frontend/lib/`.

## Tests to write first

- Extend `frontend/test/features/plugin_engine/plugin_event_hub_test.dart` for multi-view synchronization, late registration hydration, and disposal.
- Extend `frontend/test/features/plugin_engine/english_assistant_e2e_test.dart` for SDK event handling and initial/current preset convergence. Keep this test under the existing feature directory.

## Phase 03 execution record

- **Implementation:** The host serves the shared stylesheet from `/__hocluc_sdk__/liquid-glass.css`; the English Assistant opts in through that route and handles preset updates through `HocLuc.onHostEvent`. The host synchronizes active and separately floating plugin IDs, with duplicate IDs dispatched once. A mounted `FlatHost` unregisters its previous page sender before loading a changed URL.
- **Automated verification:** 24 focused tests passed across the glass preset, event hub, plugin web server, and English Assistant end-to-end suites. The English Assistant suite was rerun after the latency report added a maximum-sample check: all 5 tests passed. `flutter analyze --no-fatal-infos` reported no issues.
- **Windows WebView measurement:** 30 preset updates through `HostBridge → PluginEventHub → WebviewController.executeScript`; median **1.80 ms**, p95 **3.20 ms**, maximum **3.90 ms**. Each sample was below 50 ms. Timing uses the host epoch-millisecond dispatch value and the page's `performance.timeOrigin + performance.now()` at CSS-variable assignment.
- **Package:** `english_assistant` is version **2.0.3** and was repackaged into `plugins/english_assistant.hlep` (SHA-256 `10b7ef3e67177588f93777abc0d0d2a7903f7c8f023a2bd4f8a574c6313d105f`). The repository-wide plugin validator remains in the Phase 04 gate.
- **Review:** Approved. The plugin A→B cleanup test covers the event-hub callback contract; the `FlatHost` callback ordering itself was verified by code inspection rather than a native WebView widget test.
