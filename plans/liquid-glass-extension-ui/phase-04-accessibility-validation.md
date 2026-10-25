# Phase 04 — Accessibility, Regression Gates, and Packaging

**Maps to:** P1-1, P1-2, P1-3, P1-4; P2-5 and P2-6 only if included in agreed scope  
**Depends on:** Phases 01–03.

## Goal

Close accessibility and regression gaps, verify required architecture/plugin invariants, and package any changed plugin assets.

## Work

1. Define and record `contrast-matrix.md` before implementation sign-off. Include normal text, button labels, and S/V/O labels on (a) the app chalkboard `#14221d`, (b) white PDF, and (c) alternating black/white and saturated-color fixtures that represent busy board/PDF content. For each preset, record the resolved backing color and measured contrast ratio. If any combination fails WCAG AA (4.5:1 normal text; 3:1 large text and UI boundaries), give that text a local opaque backing that passes; keep solid mode as the high-contrast fallback. Arbitrary unseen content is outside the guarantee.
2. Respect reduced-motion preferences and avoid sheen/glow animation if the interaction is not hover-capable or if motion is reduced. P2 sheen and aura are optional enhancements, not blockers for P1.
3. Run existing and newly added tests in hierarchical feature locations. Verify drag, dock controls, drawer/floating layout, plugin interactions, and event cleanup.
4. If plugin content changed, increment that plugin's manifest SemVer version, run `node scripts/package_plugin.mjs <plugin_folder>`, and verify archive freshness with `node scripts/validate_plugins.mjs`.
5. Run repository gates from their expected working directories: `flutter test test/architecture_test.dart` must satisfy the repo's 12 invariants; `flutter analyze --no-fatal-infos` must report zero errors/warnings. Do not accept the spec's stale 7-invariant count as sufficient.

## Acceptance criteria

- `contrast-matrix.md` records fixtures, resolved backing colors, and ratios for all three presets; normal text meets 4.5:1 and large text/UI boundaries meet 3:1. Any failing transparent combination receives a local opaque backing, and solid mode remains available.
- The dock and plugin panel work with mouse and keyboard focus; the preset control announces its current state.
- No plugin IDs/subject names are hardcoded in `frontend/lib/`, no plugin imports cross the host/package boundary, and no new flat root/test files violate repository structure.
- `node scripts/validate_plugins.mjs` reports 0 errors; modified plugin archive is fresh after packaging.
- Architecture gate passes 12/12, analyzer has zero errors/warnings, and relevant feature tests pass.
- Final notes include the Phase 01 platform result, performance measurement, fallback (if any), supported targets, and contrast matrix.

## Tests to write first

- Add/extend feature-local tests under `frontend/test/features/studio_board/` and `frontend/test/features/plugin_engine/` for semantics, fallback state, host events, and drawer/floating lifecycle.
- Do not add flat test files under `frontend/test/`; only `architecture_test.dart` is permitted at that root.

## Phase 04 completion record

- Added [`contrast-matrix.md`](contrast-matrix.md). It records Clear, Frosted, and Solid text backing and WCAG ratios against chalkboard, white PDF, alternating black/white regions, and saturated red/blue/yellow fixtures. The plugin uses opaque `#182620` behind text and S/V/O labels; tested normal text and role labels all exceed 4.5:1. Host palette controls use opaque fills; paired dark/light shell edges retain at least one 3:1 boundary for each fixture.
- Added focused CSS and Flutter tests for plugin text backing, S/V/O contrast, panel edges, reduced motion, hover capability, keyboard focus/activation, preset semantics, and dock boundaries. The preset control now shows a 2 px white focus border; a widget assertion checks the visible treatment as well as Enter activation. The final combined run passed 41 checks, including all 12 architecture invariants. `plugin_event_hub_test.dart` passed 9/9; the targeted drawer and floating window layout tests passed.
- `node scripts/validate_plugins.mjs` passed with 0 errors and all 3 plugin archives fresh. Phase 04 changed no plugin package files, so no SemVer bump or repackaging was needed.
- `flutter analyze --no-fatal-infos` reported no issues.
- Code review approved the Phase 04 changes after adding the focused-state border and its visual assertion.
- The complete `plugin_ui_test.dart` file has one failing bridge permission assertion for `INSERT_ANNOTATION` (`board:insert_annotation` missing) in the current worktree; its drawer and floating window tests pass when run directly. The assertion is outside the Phase 04 UI/accessibility changes.
- Windows desktop remains the supported target. Web host-event synchronization is deferred. The opaque WebView2 content fallback remains active. Phase 03 measured 30 preset-event updates at 1.80 ms median, 3.20 ms p95, and 3.90 ms maximum. Dock drag frame pacing remains unmeasured and is not claimed as meeting 55 FPS, per the approved validation scope.
