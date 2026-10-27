# Phase 2: Unified Vector SVG Export & Continuous Curve

**Files to modify:**
- `plugins/math_studio/ui/app.js`
- `plugins/math_studio/ui/render/graph_plotter.js`

## Implementation Steps
1. In `graph_plotter.js` (`generateGraphSvg`):
   - Verify that when `integralResult` is present, the function curve `<path>` is generated for the full range `[xMin, xMax]` without clipping at $a$ or $b$.
   - Verify the integral shaded path covers $[a, b]$ with drop lines to $Ox$ and glider markers matching JSXGraph.
2. In `app.js` (`handlePinToBoard`):
   - Unify the export logic: both 'graph' and 'integral' views call `generateGraphSvg(currentAnalysis, currentIntegral, { theme: 'chalkboard', ... })`.
   - Title matches pedagogical convention (`Tích phân S = ...` or `Đồ thị: y = ...`).
3. Verification:
   - Run `node scripts/test_math_studio.mjs` (7/7 tests pass).
   - Run `node scripts/test_app_logic.mjs` (5/5 tests pass).
   - Run `node scripts/validate_plugins.mjs --fix` (0 errors, package updated).
   - Run `node scripts/run_architecture_check.mjs` (12/12 invariants pass).

## Acceptance Criteria
- [ ] Exported sticker on chalkboard displays the complete continuous curve, full axes, grid numbers, and shaded integral region.
- [ ] "Bảng có cái gì thì in ra cái đó" (100% WYSIWYG match).

