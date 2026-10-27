# Phase 1: DOM & Viewport Unification

**Files to modify:**
- `plugins/math_studio/ui/index.html`
- `plugins/math_studio/ui/app.js`

## Implementation Steps
1. In `index.html`:
   - Keep `graphViewLayout` (with `#graphContainer`) visible when switching between 'graph' and 'integral'.
   - Place `#integralControlsCard` inside the left sidebar (`left-control-col`) or as a dedicated inspector card displayed when tab `integral` is active.
   - Remove redundant `<div id="integralGraphContainer"></div>` and `#integralViewPanel`.
2. In `app.js`:
   - When tab `integral` is clicked (`data-view="integral"`):
     - Set `activeView = 'integral'`.
     - Keep `#graphContainer` visible.
     - Show the Integral controls in the inspector and hide non-applicable cards (or highlight the integral card).
     - Call `renderGraphOnly()` with `currentIntegral = solveIntegral(currentAnalysis, a, b)` to render the full graph with integral shading and gliders on the shared `#graphContainer`.
   - In `renderIntegralTable()`:
     - Update formula display and area $S \approx \dots$.
     - Re-render/update `#graphContainer` directly.

## Acceptance Criteria
- [ ] Switching between 'Đồ thị' and 'Tích phân' uses the same DOM `#graphContainer`.
- [ ] No duplicate JSXGraph board initialization on separate canvases.

