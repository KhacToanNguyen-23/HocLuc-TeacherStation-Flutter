# Phase 03 — SDK Glass Regions and Coordinate Lifecycle

**Maps to:** P1 plugin result card, P1 generic glass-region SDK contract, P1 accessibility  
**Depends on:** Phase 02 reusable renderer. Phase 01 under-WebView sampling remains open; under the approved reduced scope, implement the generic SDK and lifecycle while keeping the plugin card opaque until that visual gate passes.

## Goal

Allow any compliant plugin to register a visual-only host shader region through the injected HocLuc SDK. Keep result-card markup and text owned by the plugin WebView.

## Work

1. Reconcile the SDK sources before editing: `PluginWebServer` currently injects and serves `_kEmbeddedSdkJs` from `frontend/lib/features/plugin_engine/services/plugin_web_server.dart`, while `frontend/assets/scripts/hocluc-plugin-sdk.js` is also present. Make the runtime-injected and served SDK use one source of truth; if consolidation is not part of this phase, update both copies identically and add a parity check. Add typed register/update/unregister glass-region APIs using the existing SDK bridge. Validate event shape and region IDs; do not call the raw WebView bridge from plugin code.
2. Add generic handling through the typed `HostBridge` and host-side region service. Key records by WebView instance token plus region ID so separate WebViews cannot overwrite each other. Bound region count/rect dimensions and reject NaN, infinity, negative size, and out-of-viewport values.
3. Convert `getBoundingClientRect()` CSS viewport pixels to Flutter logical coordinates using the actual WebView `RenderBox` origin and an empirically calibrated viewport-to-logical scale. Do not blindly multiply by DPR. Record calibration assumptions and test the transform at supported DPI/zoom settings.
4. Make the SDK/plugin own DOM geometry observation: registration identifies the result-card element, and the SDK installs a `ResizeObserver`, scoped `MutationObserver`, and scroll/resize listeners to publish bounds/visibility changes. The plugin re-registers a replacement element; the SDK clears a disconnected element rather than retaining stale bounds. The host owns WebView origin/size, dock/window movement, and supported DPI/zoom refresh. Coalesce high-frequency updates to a frame or bounded cadence, and remove every observer/listener on unregister, navigation, and disposal.
5. Add navigation generation tokens. Ignore stale update events after navigation and clear all relevant regions on hide, navigation, WebView disposal, or plugin replacement.
6. Place the shader region beneath WebView content and above board/PDF, clipped to validated card bounds; apply `IgnorePointer` and `ExcludeSemantics` so the plugin owns hit testing and accessibility.
7. Integrate the existing English Assistant result card with the generic SDK contract for result-card bounds. It reports card/container bounds, not token subregions in this phase. Keep plugin IDs out of host implementation; bump the plugin SemVer and package it if its assets or manifest change.

## Acceptance criteria

- A compliant plugin can register, update, and unregister through `window.HocLuc`; all messages use the SDK event path.
- An end-to-end test loads `/__hocluc_sdk__/hocluc-plugin-sdk.js` through `PluginWebServer` and verifies the runtime SDK exposes the registration lifecycle; source copies cannot silently diverge.
- Region identity is scoped to WebView instance and region ID; two simultaneous views remain isolated, and disposal removes only that view's registrations.
- Bounds are finite, bounded, mapped using measured CSS-to-logical scale, and coalesced; stale navigation generations cannot resurrect old regions.
- SDK-owned DOM observers report size/visibility changes and clear disconnected regions; plugin replacement re-registers the new element; observer/listener teardown is verified.
- The result-card shader aligns to within 2 Flutter logical pixels after load, scroll, content replacement/visibility change, WebView resize, dock/window movement, and tested DPI/zoom changes.
- Clear/Frosted/Solid preset changes apply to all visible registered regions within 50 ms.
- Plugin result content remains plugin-owned; shader does not intercept input or create duplicate semantics.

## Tests to write first

- Add/extend SDK/host bridge tests under `frontend/test/features/plugin_engine/` for request validation, identity scoping, update coalescing, navigation generation, unregister/cleanup, and multi-WebView isolation.
- Add a geometry mapping test under `frontend/test/features/plugin_engine/` for non-1.0 scale, nonzero WebView origin, and DPI values showing DPR is not used as a blind multiplier.
- Add plugin e2e coverage under the existing feature test directory for result registration, visibility clearing, navigation replacement, and late/stale events.

## Phase 03 implementation and gate record — 2026-10-21

**Outcome: SDK contract, host lifecycle, and English Assistant registration implemented; P1 WebView visual acceptance remains open.** The agreed opaque WebView fallback is active, so SDK registration and a host shader below the WebView do not prove that board/PDF pixels are visible through WebView composition.

- Consolidated the runtime SDK route onto `assets/scripts/hocluc-plugin-sdk.js`; `PluginWebServer` now serves that asset directly. Tests assert byte-for-byte parity, route availability, and automatic SDK injection.
- Added `HocLuc.glass.registerRegion`, `updateRegion`, `unregisterRegion`, and `refreshRegions`. The SDK observes element resize/mutation, viewport scroll/resize, visibility, and disconnection; it coalesces measurements with `requestAnimationFrame` and tears observers/listeners down on unregister or page hide.
- Added `GlassRegionService` and typed `glass:*` HostBridge actions. Records are keyed by host WebView token plus region ID, limited to 16 per view, validated for finite/in-viewport dimensions, mapped from CSS pixels using the measured WebView logical size and origin, and published at most once per 16 ms burst. Navigation generations and view disposal clear records and reject stale messages.
- Native `FlatHost` attaches its host-owned view token, navigation generation, and measured RenderBox bounds to incoming messages. The visual-only region layer is clipped, ignores pointer input, and is excluded from semantics. Drawer hide, navigation, and WebView disposal clear its regions.
- English Assistant now uses the injected canonical SDK to register its result card. Its manifest is version `2.1.0`, and `plugins/english_assistant.hlep` was rebuilt.
- The focused suite passes 30 tests across seven feature files, including SDK observer lifecycle, pre-generation registration retry, stale disposer safety, region validation/clipping/mapping/coalescing, view isolation, stale document generations, WebView context, overlay semantics, SDK serving/injection, and English Assistant integration. The final analyzer and architecture gates pass; plugin validation reports all three packages fresh.
- Hard-mode review fixes retain the WebView sender across parent rebuilds, bind SDK messages to a document generation, preserve that generation through hide/show, and prevent hidden navigation completion from re-registering regions. The service clips partial viewport intersections and removes fully offscreen regions. The SDK tracks ancestor visibility/opacity without weakening mutation-removal observation.

**Still open:** visible refraction through the native WebView, 2-logical-pixel alignment through real load/scroll/resize/DPI/zoom and dock/window movement, and the 18.2 ms interactive drag gate. Keep the card opaque; do not claim P1 result-card visual acceptance until Windows composition is verified.
