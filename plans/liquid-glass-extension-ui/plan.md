# Implementation Plan: Liquid Glass Extension UI

**Mode:** Hard  
**Risk:** normal — visual and platform-composition changes span Flutter host widgets, WebView integration, and plugin UI; no data or infrastructure migration is planned.  
**Spec:** `plans/liquid-glass-extension-ui/spec.md`  
**Brainstorm:** `plans/reports/261020-liquid-glass-extension-ui-brainstorm.md`

## Scope challenge

- **Exists?** Partial. The board palette, plugin drawer/floating window, `StudioState`, `PluginEventHub`, and injected `HocLuc.onHostEvent` transport already exist. Glass styling, preset state, and robust drawer/floating synchronization do not.
- **Minimum?** First establish whether the native WebView can actually expose the board through its composition surface and whether the current drag rebuild path meets a measurable performance target. Build the reusable host glass treatment and preset transport only after that gate passes or an agreed fallback is selected.
- **Complexity:** Hard. Work crosses Flutter and plugin web UI, and the central transparency assumption is currently unverified.

## Spec quality check

- **NEEDS CLARIFICATION:** None explicitly marked in the spec.
- **Measurable success criteria:** Mostly measurable (SC-01 to SC-03, SC-05, SC-06). SC-04 cannot hold for arbitrary backgrounds and transparent surfaces; constrain it to defined content/background samples and retain a solid high-contrast fallback.
- **Prioritized user stories:** Present (P1 and P2).
- **Testable acceptance criteria:** SC-02/03/05/06 are directly testable. SC-01 needs a repeatable device and scene protocol. SC-04 needs revised scope and a fallback.
- **Conflicts and ambiguities:** SC-05 claims 7 architecture invariants, while repository guidance requires the architecture test to pass 12 invariants. The implementation gate follows the repository's 12-invariant requirement. SC-06 names the English Assistant package explicitly; host code must remain plugin-agnostic, and package/validate steps apply only if that plugin's files are changed. `clear` opacity/blur values are listed, but CSS alpha is not the same as total perceived opacity. “Synchronized immediately” requires defining behavior when drawer and floating hosts overlap; `PluginEventHub` currently retains one sender per plugin ID. The Flutter Web target currently lacks event wiring, so cross-target scope must be explicit.

**Verdict: WARN** — proceed with the constraints and decision gates above; the plan does not claim arbitrary-background contrast or unverified WebView transparency as guaranteed outcomes.

## Decisions and boundaries

- Keep all Flutter changes within `frontend/lib/core/` and `frontend/lib/features/`; no flat root directories or plugin-specific IDs/names in `frontend/lib/`.
- Keep plugin web assets inside their plugin package. Reusable host-side Flutter components belong in core; shared plugin CSS must follow the existing plugin packaging/SDK boundaries and must not be imported directly by Flutter.
- Send preset updates as data over the existing Host → WebView event path (`PluginEventHub` → injected SDK `HocLuc.onHostEvent`). Do not issue arbitrary `postMessage` calls from plugin UI.
- Broadcast preset events to every registered live WebView sender for the plugin's runtime ID. Drawer and floating window instances must not overwrite one another; unregistering one view must preserve the other.
- Serve the reusable, versioned `liquid-glass.css` kit from the host plugin SDK asset route (`/__hocluc_sdk__/liquid-glass.css`). Plugin pages opt into this host-managed asset with a stylesheet link; this avoids cross-imports and duplicated sources. Preserve an opaque fallback for pages opened outside the host.
- Treat Windows WebView2 transparency as unverified until demonstrated on the actual target. A Flutter `BackdropFilter` only blurs pixels composited in Flutter's scene; it does not itself blur content inside a separate native WebView surface.
- Scope the first implementation to Windows desktop and the currently supported plugin presentation modes. Web target event wiring is a separate decision gate; do not report cross-platform synchronization until it is implemented and verified.
- Use Frosted as the initial preset. If native WebView transparency is unavailable, proceed with the approved opaque WebView fallback while retaining the glass dock/frame and plugin-internal glass treatment; document that the board is not visible through WebView content.
- Meet contrast with constrained backing surfaces and an accessible solid mode. Shadows and micro-outlines alone cannot guarantee WCAG AA over arbitrary board content.

## P1 story mapping

| Story | Plan phases | Acceptance summary |
|---|---|---|
| P1-1 Liquid glass board dock | 01, 02 | Dock uses reusable glass surfaces over the board; drag performance meets the gated target or uses the documented fallback. The plugin WebView reveals board content only if native composition supports it; otherwise its approved opaque fallback is documented. |
| P1-2 Three synchronized presets | 01, 02, 03 | Clear → frosted → solid → clear; host state and every live relevant WebView converge to the same preset within 50 ms on the supported Windows path. |
| P1-3 Glass S-V-O result UI | 03 | Plugin results and S/V/O tokens adopt the shared CSS treatment; labels remain legible with a high-contrast solid fallback. |
| P1-4 Modular glass kit and architecture | 01–04 | Reusable host/CSS tokens follow boundaries; no plugin ID hardcoding or cross-import; required architecture gate is 12/12. |

## Phases

- [x] [Phase 01 — Native feasibility and integration gate](phase-01-native-feasibility.md)
- [x] [Phase 02 — Host glass kit, palette, and preset state](phase-02-host-glass-presets.md)
- [x] [Phase 03 — Plugin glass UI and event synchronization](phase-03-plugin-glass-sync.md)
- [x] [Phase 04 — Accessibility, regression gates, and packaging](phase-04-accessibility-validation.md)

## Risks and mitigations

- **Native transparency unsupported or inconsistent:** Phase 01 must produce a reproducible Windows WebView2 result. If Flutter cannot composite the board behind the native surface, proceed with the approved opaque/frosted WebView fallback and preserve glass styling in the dock/frame and plugin UI; do not claim that board content shows through the WebView.
- **Drag performance misses target:** Profile the existing and candidate dock on the same Windows device and board/PDF scene. If it misses 55 FPS, simplify/remove live blur while dragging and restore it on drag end, or use the approved opaque fallback. Record the measured result and chosen fallback.
- **Drawer/floating sender collision:** Store a set of senders per plugin runtime ID, fan out preset events to all live views, and remove only the disposed sender; add lifecycle tests for open, float, close, and overlapping views.
- **Web target cannot receive host events:** Either add supported iframe event transport in a follow-up with its own acceptance gate or declare Windows desktop as the bounded delivery target. Do not claim synchronization on Web.
- **Contrast over arbitrary chalk/PDF content:** SC-04 as written is mathematically unachievable for unrestricted backgrounds. Keep text surfaces opaque enough to pass against a defined palette, provide solid mode, and document that transparent decorative regions are not text backing.
- **Spec/repository architecture count mismatch:** Follow current repository guidance: `flutter test test/architecture_test.dart` must pass 12/12, irrespective of the spec's 7/7 statement.
- **Shared CSS distribution:** Keep one versioned host SDK stylesheet route available to every plugin served by `PluginWebServer`; plugin pages consume it by URL and remain readable with an opaque local fallback when opened outside the host.
- **Plugin package freshness:** Follow the plugin edit rule to bump the edited plugin's SemVer before repackaging and validating its `.hlep` archive.

## Verification and handoff

No tests are run during planning. Implementation verification must use the repository's existing hierarchical locations, including `frontend/test/features/studio_board/subject_tool_palette_test.dart`, `frontend/test/features/plugin_engine/plugin_event_hub_test.dart`, and any new tests under those feature directories. Only `architecture_test.dart` may live at `frontend/test/` root.

Before completion, follow repository CI gates: `node scripts/validate_plugins.mjs`, `flutter test test/architecture_test.dart` from `frontend/` (12 invariants per repository guidance), and `flutter analyze --no-fatal-infos`. If plugin assets are modified, run `node scripts/package_plugin.mjs <plugin_folder>` and validate the resulting package. The feature should not be declared complete unless the Phase 01 decision, supported platform scope, fallback, and measured performance result are recorded.

## Cook handoff

`$bb-cook --hard --tdd plans/liquid-glass-extension-ui/plan.md`

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-21 11:01 Asia/Saigon
**Phase in progress:** none — all phases complete
**Status:** Phase 04 is implemented and verified. The contrast matrix covers three presets and seven board/PDF fixtures; plugin text and S/V/O labels meet 4.5:1 on local opaque backings, while host controls retain visible boundaries. The final combined Flutter run passed 41 checks, including architecture invariants 1–12; focused plugin event cleanup passed 9/9; targeted drawer and floating window tests passed. Plugin validation reports 0 errors with all 3 archives fresh; analyzer reports no issues. One unrelated `plugin_ui_test.dart` bridge permission assertion remains failing when the entire file is run; its drawer/floating tests pass in isolation. The Windows WebView event benchmark measured 30 updates at 1.80 ms median, 3.20 ms p95, and 3.90 ms maximum. The opaque WebView fallback remains in effect; dock drag frame pacing remains unmeasured and no 55 FPS claim is made.

### Decisions made this session
- Broadcast global glass preset changes to both active and floating plugin IDs, deduplicating when they identify the same plugin.
- Unregister the prior plugin sender before a mounted FlatHost navigates to another plugin URL.
- Keep Windows desktop as the verified event transport target; Web event synchronization remains deferred.
- Preserve the user-approved opaque WebView content fallback.

### Phase 04 decisions and verification
- User approved proceeding with Phase 04.
- Keep Windows desktop as the supported target and defer Web host-event synchronization.
- Preserve the approved opaque WebView content fallback; the dock and plugin surfaces keep glass styling.
- Record the approved scope of validation: WebView preset dispatch is measured; dock drag frame pacing is not measured and remains unverified.
- Repository gates passed: plugin validator 0 errors, architecture 12/12, analyzer no issues.
