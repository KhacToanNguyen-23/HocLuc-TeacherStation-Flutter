# Phase 2: Lightweight 2D Graph & 3D Solid Canvas Renderers

## Objective
Build direct canvas renderers for the 2D Oxy coordinate graph and 3D Solid of Revolution using Rough.js on standard HTML5 `<canvas>`.

## Implementation Details
1. File: `plugins/math_studio/src/stage/viewport.js`
   - Coordinate transformation between mathematical $(x, y)$ and screen pixel $(sx, sy)$.
   - Center $(0, 0)$ mathematically at canvas center $(width/2, height/2)$.
   - Zoom scale and pan offset support.
2. File: `plugins/math_studio/src/stage/graph2d.js`
   - Oxy axes, arrows, ticks, and numeric labels.
   - Sample curve $f(x)$ dynamically across visible domain.
   - Detect and split curve at vertical asymptotes / singularities (e.g. division by zero).
3. File: `plugins/math_studio/src/stage/solid3d.js`
   - Generate rings and meridians for revolution of $y = f(x)$ around $Ox$ on $[a, b]$.
   - 3D perspective projection with rotation angles $(\alpha, \beta)$.
   - Segregate front visible arcs (solid line) from back occluded arcs (dashed line).
4. File: `plugins/math_studio/src/stage/canvasRenderer.js`
   - Render elements onto `<canvas>` using `roughjs`.
   - HiDPI Retina support (`window.devicePixelRatio`).
   - SVG export utility for lossless vector stamping.

## Acceptance Criteria
- No infinite canvas camera desync; origin $(0, 0)$ is always centered.
- Zero "Scroll back to content" buttons.
- 60 FPS smooth rendering.

