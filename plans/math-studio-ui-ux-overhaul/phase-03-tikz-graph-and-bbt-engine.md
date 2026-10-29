# Phase 03: LaTeX TikZ / SGK Coordinate Graph, Smart Label Placement, Interactive Points & BBT Fix

## Objective
Overhaul `plugins/math_studio/ui/board/graph_board.js` and `plugins/math_studio/ui/render/bbt_generator.js` so that 2D graphs, integral boards, and variation tables look like publication-grade LaTeX TikZ / Vietnamese SGK diagrams with zero overlapping labels and 100% working interactive point tools.

## Files to Modify
1. `plugins/math_studio/ui/board/graph_board.js`
   - **TikZ Stealth Axes & Origin**:
     - Custom slender SVG `<marker>` arrowheads (aspect ratio $2.2 : 1$ with indented stealth tail) for $Ox$ and $Oy$.
     - Italic serif math labels for *$x$*, *$y$*, and origin *$O$* (positioned cleanly in quadrant III at pixel offset `[-14, -14]` from `(0,0)` so *$O$* is never clipped into a `∪` shape).
   - **SGK Projection Lines & Projection Foot Coordinates**:
     - Draw delicate dashed projection segments (`stroke-dasharray: 3.5, 3.5`, `strokeWidth: 1.0`, `#64748B`) from each active extremum / marked point to $(x_0, 0)$ and $(0, y_0)$.
     - Render explicit coordinate labels $x_0$ on $Ox$ and $y_0$ on $Oy$ at the projection feet (formatted cleanly without `.0`, using mathematical minus `−`).
     - Automatically suppress standard axis ticks that fall within `< 0.48` world units of any projection foot label or origin `0`, completely eliminating number-on-number collisions (such as `2` colliding with `CĐ` or `b = 2`).
     - Add a subtle `2.5px` white background halo (`paint-order: stroke fill` in browser + inline halo in exporter) on axis tick numbers so curves passing through `-2` do not cut through the text.
   - **Smart Non-Overlapping Point Labels & Locked Points (`fixed: true`)**:
     - Set `fixed: true` and `size: 3.2` on all extrema and intercept points so mouse dragging pans the board smoothly at 60fps.
     - Anchor point labels (`CĐ`, `CT`, `Giao Ox`, `Giao Oy`, custom points) with true quadrant/normal-aware offsets (`y > 0` peak pushed above; `y < 0` trough pushed below; shifted horizontally away from $Oy$ if $|x| < 1.2$).
   - **Full Support for `showExtrema`, `markedPoints`, and `isAddPointMode`**:
     - Respect `options.showExtrema` (when false or on Integral tab, do not draw `CĐ`/`CT` dots).
     - Render all `options.markedPoints` (`Giao Ox` roots, `Giao Oy` intercept, and user-added points).
     - When `options.isAddPointMode` is active, bind board `down` event to convert click coordinates to world `(x, y)`, snap to the curve $y = f(x)$ if within `0.4` units (or snap to `0.5` grid), and invoke `options.onMapClickAddPoint({ x, y, onCurve })`.
   - **Clean Integral Board**:
     - Pass `withLabel: false`, `curveLeft: { visible: false }`, `curveRight: { visible: false }` to `board.create('integral', ...)` so JSXGraph never prints the stray `∫ = 0.7500` label on the graph.
   - **Viewport Preservation, Square Aspect Ratio & Zoom Helpers**:
     - Calibrate default bounding box aspect ratio to match the canvas container ($4 : 3$) so 1 unit on $Ox$ equals 1 unit on $Oy$ (preventing stretched grids and distorted $y = x$ diagonals).
     - Skip redundant projection segments when $|x_0| < 0.05$ or $|y_0| < 0.05$ (when an extremum already lies on $Oy$ or $Ox$).
     - Do not destroy and recreate the JSXGraph board while dragging integral gliders `a` and `b` (`isDragging = true`); update sidebar integral numbers live and only re-init board on formula/tab changes.
     - Expose `zoomBoard(containerId, factor)` and `resetBoardViewport(containerId, bounds)` and preserve current bounding box when toggling point visibility or curve color.
2. `plugins/math_studio/ui/render/bbt_generator.js`
   - Fix `pt.isSingular` $\to$ `const isSing = Boolean(pt.isSingularity || pt.isSingular)` at lines 87, 139, 142 so vertical asymptote double-bars `||` and one-sided limits $\pm\infty$ render properly.
   - Implement **SGK 4-Tier Vertical Positioning** in the $y$ row (`+∞` at top tier, local maxima `CĐ` at upper-mid tier, local minima `CT` at lower-mid tier, `−∞` at bottom tier) so finite extrema are visually distinct from $\pm\infty$, and shorten arrow endpoints by `18px` so arrowheads never pierce value labels.
   - Render exact horizontal asymptote limits (`analysis.limits.left` / `right`) at $x \to \pm\infty$ and one-sided limits (`pt.leftLimit` / `pt.rightLimit`) beside `||`.
   - Upgrade BBT typography to crisp `13px–15px` math serif (`Cambria Math` italic for $x, y', y$, clean `−∞`, `+∞`) and support the Dual-Theme Chalkboard palette.

