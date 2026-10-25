# Phase 02 — Host Glass Kit, Palette, and Preset State

**Maps to:** P1-1, P1-2, P1-4  
**Depends on:** Phase 01 decision; implement the approved composition path or fallback.

## Goal

Add a reusable Flutter glass surface and wire the generic board tool palette to a three-state preset. Keep the host design independent of any particular plugin identity.

## Work

1. Add `LiquidGlassContainer` under `frontend/lib/core/widgets/` with explicit preset/blur inputs, clipped backdrop filtering, restrained gradient/rim/shadow, and a reduced-motion/reduced-cost option if needed by the feasibility result.
2. Add a typed glass preset value in studio feature state (`StudioState` or a focused model under `features/studio_board/domain/models/`). Start in the agreed `frosted` state; persist only if persistence semantics are deliberately specified.
3. Replace the palette's opaque decoration with the shared host surface where supported. Preserve manifest-driven tool contributions, drag behavior, and existing hit targets. Add one accessible preset cycle control with semantic name and state.
4. Notify the host event service when preset changes. Keep the event name and payload generic; no direct plugin imports, arbitrary webview calls, or plugin IDs in `frontend/lib/`.
5. Re-profile against Phase 01's device/scenes. If target is missed, apply the agreed reduced blur while dragging or opaque fallback and capture the result.

## Acceptance criteria

- The preset cycles exactly `clear → frosted → solid → clear` and each state maps to the documented opacity/blur values within ±0.05 opacity and exact sigma 10/20/28 where blur is supported.
- The palette renders from manifest-contributed tools as before, and uses the common container without plugin-name branching.
- Preset selection updates host state once and emits one generic host event with the matching preset value.
- Target performance is ≥55 FPS during the measured 10-second drag, or the approved fallback is enabled and its resulting frame rate and visual behavior are recorded.
- UI control exposes an accessible label/state and remains usable at supported desktop window sizes.

## Tests to write first

- Extend `frontend/test/features/studio_board/subject_tool_palette_test.dart` for preset order, state-to-style mapping, semantics, and palette behavior with different manifest contributions.
- Add focused state tests under `frontend/test/features/studio_board/` for default preset and notification behavior, if state is extracted.

## Execution record

- **Status:** Implemented; phase review approved.
- Added the typed `GlassPreset` model with Clear, Frosted, and Solid values and the agreed blur mapping. Frosted is the startup state.
- Added the reusable `LiquidGlassContainer` in core and applied it to the manifest-driven subject palette. The accessible 44 × 44 preset control cycles the three states. Backdrop filtering is disabled during palette dragging and restored on drag end or cancellation.
- Preset changes update studio state and emit the generic `GLASS_PRESET_CHANGE` host event with the preset name. Duplicate selections do not emit duplicate updates.
- **TDD:** The focused test run passed after first confirming the tests failed against the missing preset/state API. Final command: `flutter test --no-pub test/features/studio_board/liquid_glass_preset_test.dart test/features/studio_board/subject_tool_palette_test.dart` — 12 tests passed.
- **Analysis:** `flutter analyze --no-fatal-infos` — no issues found.
- **Review:** Code review approved with no concrete findings.
- **Composition/performance:** Per user approval, plugin content uses the opaque WebView fallback. Dragging reduces blur cost, but interactive dock frame pacing was not measured; the 55 FPS result remains open for final validation and is not claimed here.
