# Implementation Plan: Math Studio Plugin — High-End Visual Design & Clean CAS Architecture Overhaul

```
Directory: plans/math-studio-ui-ux-overhaul/
Spec:      plans/math-studio-ui-ux-overhaul/spec.md
Mode:      hard (comprehensive multi-layer plugin + host overhaul)
Risk:      normal — multi-file plugin UI/CAS overhaul and 3 host Flutter widget/server refinements, fully testable, no auth/DB/infra risk
Test:      default + architecture/validator gates
Tasks:     default
```

---

## Scope Challenge & Spec Quality Check

```
# Scope Challenge:
#   Exists?     → Yes, `plugins/math_studio` exists but has ~970 lines of dead code, hardcoded CAS types, broken point controls, coarse text, and broken 3D export.
#   Minimum?    → 5 focused phases covering: (1) AST CAS + Integral + Dead Code cleanup, (2) High-End UI & Typography, (3) TikZ 2D Graph + BBT, (4) 3D Problem Parser + Chalkboard Export, (5) Host WebView crispness/caching + 3-button Sticker Bar + Packaging.
#   Complexity? → Hard (spans JS CAS engine, JSXGraph 2D/3D SVG rendering, CSS design system, and Flutter host bridge/toolbar).
#
# Spec Quality Check:
#   [NEEDS CLARIFICATION] remaining? → 0 remaining (all resolved with user via screenshots)
#   Success criteria measurable?     → PASS (9 explicit testable checkboxes)
#   User stories P1/P2/P3?           → PASS
#   Acceptance criteria testable?    → PASS
#   Verdict: PASS
```

---

## Research Synthesis

- **Researcher A (Primary — Single AST Pipeline + In-Place JSXGraph Layering + Dual-Theme SVG Serializer)**:
  - **Approach**: Consolidate all expression parsing, polynomial/rational classification (`coeffs`), derivative simplification, and denominator root finding into `symbolic_cas.js` + `math_cas.js`. Delete the 5 dead modules (`expression_parser.js`, `curve_manipulator.js`, `graph_plotter.js`, `revolution_solid_plotter.js`, `ui/sdk.js`). Render TikZ-grade axes, projection foot labels ($x_0, y_0$), and quadrant-aware point labels in `graph_board.js` with `fixed: true` points for 60fps panning. Map colors semantically to a High-Luminance Chalk Palette in `board_exporter.js`.
  - **Verdict**: **Recommended** — eliminates ~970 lines of technical debt, fixes every visual and mathematical defect reported by the user, and keeps zero external runtime dependencies.
- **Researcher B (Alternative — External KaTeX + Math.js Bundle)**:
  - **Approach**: Bundle external `mathjs` (~700 KB) and `katex` (~300 KB + fonts) into `vendor/` alongside `jsxgraphcore.js` (922 KB).
  - **Verdict**: **Rejected** — would triple the plugin payload size (~2 MB+ JS), worsening cold-start time, whereas our existing zero-dependency AST in `symbolic_cas.js` only needs ~120 lines of polynomial/rational coefficient extraction to handle 100% of high-school SGK functions in `< 2ms`.

---

## Phase Overview

| Phase | File | Summary | Stories Covered |
| :---: | :--- | :--- | :--- |
| **01** | [`phase-01-cas-engine-and-cleanup.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-ui-ux-overhaul/phase-01-cas-engine-and-cleanup.md) | Delete 5 dead files; upgrade AST classifier, rational derivative simplifier, general asymptote solver, root-splitting integral solver, and URL-aware store initialization. | FR-03, FR-04, FR-07, FR-08 |
| **02** | [`phase-02-high-end-ui-and-typography.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-ui-ux-overhaul/phase-02-high-end-ui-and-typography.md) | Rebuild `index.html`, `style.css`, and `app.js` with `/high-end-visual-design` (Soft Structuralism + Double-Bezel trays, ClearType opaque body, academic math preview, SGK presets, 2-row Integral card, drop `KHUNG NHÌN HỆ TRỤC`). | FR-02, FR-05, FR-07, FR-08, FR-10 |
| **03** | [`phase-03-tikz-graph-and-bbt-engine.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-ui-ux-overhaul/phase-03-tikz-graph-and-bbt-engine.md) | Overhaul `graph_board.js` (TikZ stealth arrows, italic $O$, projection foot labels on $Ox/Oy$, smart non-overlapping point labels, working `Giao Ox`/`Giao Oy`/`Cực trị`/`+ Thêm điểm`, viewport preservation) & fix `bbt_generator.js` (`isSingularity`). | FR-01, FR-02, FR-03, FR-08, FR-09, FR-10 |
| **04** | [`phase-04-3d-geometry-parser-and-export.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-ui-ux-overhaul/phase-04-3d-geometry-parser-and-export.md) | Build `geometry_parser.js` (Vietnamese geometry problem text $\to$ 3D figure with altitudes, midpoints, projections, right-angle markers), remove 3D axes in `view_3d_board.js`, and upgrade `board_exporter.js` with Dual-Theme Chalk Palette. | FR-09, FR-11 |
| **05** | [`phase-05-host-integration-and-verification.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-ui-ux-overhaul/phase-05-host-integration-and-verification.md) | Integer pixel-snapping & stable WebView key in `FloatingPluginWindow`, vendor HTTP caching in `PluginWebServer`, 3-button `BoardStickerFloatingBar`, remove `'math'` hardcode in `interactive_chalkboard.dart`, repackage `.hlep` & run CI gates. | FR-04, FR-05, FR-06 |

---

## Red-Team Review & Risk Adjudication

1. **[ACCEPTED] Risk: Removing `ui/sdk.js` could break standalone browser preview if `PluginWebServer` is not running.**
   - *Mitigation*: In `PluginWebServer`, remove `!html.contains('sdk.js')` block or delete `ui/sdk.js` and update `assets/scripts/hocluc-plugin-sdk.js` so `window.HocLuc.close()`, `window.HocLuc.onMessage()`, and `window.__hocluc_load_edit` are always present with safe no-op fallbacks when opened outside the Flutter host.
2. **[ACCEPTED] Risk: `flutter_svg` (`SvgPicture.string`) ignores CSS classes and `paint-order: stroke` when stickers are pinned to the chalkboard.**
   - *Mitigation*: Phase 03 & Phase 04 explicitly serialize all font families (`Cambria Math`, `Segoe UI`), sizes, weights, and colors as direct XML attributes (`font-family`, `font-size`, `fill`, `stroke`) on SVG elements in `board_exporter.js`.
3. **[ACCEPTED] Risk: Existing tests in `frontend/test/` might reference `FloatingPluginWindow` or `BoardStickerCard`.**
   - *Mitigation*: Phase 05 runs `flutter test` across `test/architecture_test.dart` and plugin/board widget tests to verify zero regressions.

---

## Checklist
- [x] Phase 01: Zero-Hardcode AST CAS Engine, Integral Root-Splitting & Dead Code Cleanup
- [x] Phase 02: High-End Visual Design (`Soft Structuralism + Double-Bezel`), UI Restructure & Keep/Drop Cleanup
- [x] Phase 03: LaTeX TikZ / SGK Coordinate Graph, Smart Label Placement, Interactive Points & BBT Fix
- [x] Phase 04: Vietnamese 3D Geometry Problem Parser (`geometry_parser.js`) & Dual-Theme Chalkboard Exporter
- [x] Phase 05: Flutter Host Pixel-Snapping, Caching, 3-Button Sticker Bar & CI Verification

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-27 12:36
**Phase in progress:** completed
**Status:** All 5 phases completed, packaged, and verified against all CI gates.

### Decisions made this session
- Completed Phase 01 (`rational.js`, `symbolic_cas.js`, `math_cas.js`, `integral_solver.js`, `store.js`; deleted 5 dead files).
- Completed Phase 02 (`index.html`, `style.css`, `app.js` with Soft Structuralism Double-Bezel trays, Pill Island tabs, Button-in-Button CTA, live academic math preview, 4 SGK swatches, and removal of `KHUNG NHÌN HỆ TRỤC`).
- Completed Phase 03 (`graph_board.js` with TikZ stealth arrows, projection foot labels on $Ox/Oy$, `fixed: true` points for 60fps panning, working `Giao Ox`/`Giao Oy`/`Cực trị`/`+ Gắn điểm`, `withLabel: false` on integrals, and 4-tier `bbt_generator.js` with `isSingularity` double-bars `||`).
- Completed Phase 04 (`geometry_parser.js` Vietnamese 3D problem parser, `view_3d_board.js` hidden axes & SVG `<text>` labels, and `board_exporter.js` High-Luminance Chalk Palette serializer).
- Completed Phase 05 (`hocluc-plugin-sdk.js`, `plugin_web_server.dart`, `floating_plugin_window.dart`, `board_sticker_floating_bar.dart`, `interactive_chalkboard.dart`, `board_sticker_card.dart`, `board_sticker_test.dart`, and packaged `math_studio.hlep`).

### Next immediate action
None — implementation complete.


