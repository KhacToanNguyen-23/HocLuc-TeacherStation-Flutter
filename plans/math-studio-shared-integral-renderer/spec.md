# Spec: Math Studio Shared Renderer for Integral (WYSIWYG)

**Date:** 2026-10-26  
**Status:** Ready  

---

## Problem Statement
Previously, the 'Tích phân' feature in Math Studio was built as a detached view (`#integralViewPanel`) with its own separate canvas container (`#integralGraphContainer`) and custom SVG exporter. This caused severe UI discrepancies: the curve was truncated at bounds $a$ and $b$, custom static badges were drawn manually, and the chalkboard export differed from the standard interactive graph. Teachers require a unified rendering architecture where "bảng có cái gì thì in ra cái đó" (WYSIWYG).

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a math teacher, I want the 'Tích phân' tab to render on the exact same primary 2D graph canvas as 'Đồ thị' so that the function curve, axes, grid, and extrema remain continuous across the entire viewport.  
  *Accepted when:* Switching to 'Tích phân' tab displays the integral area and gliders directly on `#graphContainer` without loading an isolated sub-canvas.

- **[P1]** As a math teacher, I want the exported sticker on the chalkboard to match 100% of what is displayed on the preview screen so that no elements (curve tails, coordinate ticks, extrema dots) are lost or manually rebuilt.  
  *Accepted when:* Clicking 'Ghim lên bảng' / 'Cập nhật' exports a complete SVG with continuous curve across viewport bounds, crisp integral fill between $[a, b]$, vertical drop lines, and gliders.

- **[P1]** As a teacher, I want two-way reactive binding between the glider handles on the graph and the input boxes ($a, b$) in the inspector.  
  *Accepted when:* Dragging handle $a$ or $b$ on the $Ox$ axis live-updates the numerical input and recalculated area $S \approx \int_a^b |f(x)|dx$ in $< 16$ms without dropping frames.

- **[P2]** As a teacher, I want to preserve extremum points and custom marked points while in 'Tích phân' mode.  
  *Accepted when:* Extrema markers and coordinates ($CT, CĐ$) remain visible and interactive alongside the integral shaded region.

---

## Functional Requirements

1. **FR-01 (Shared DOM Container):** Eliminate `#integralGraphContainer` and `#integralViewPanel`. Mount integral controls (inputs $a, b$, formula, area $S$) in the inspector while sharing the single `#graphContainer` for rendering.
2. **FR-02 (Unified JSXGraph Pipeline):** When 'Tích phân' tab is active, `renderJSXGraphBoard` mounts the JSXGraph `integral` element, glider handles on $Ox$, and drop lines onto the existing board instance without destroying the global grid/axes.
3. **FR-03 (Continuous Curve Geometry):** The mathematical curve in both preview and exported SVG must span the full horizontal viewport (`xMin` to `xMax`), not truncated at boundary points $a$ and $b$.
4. **FR-04 (WYSIWYG Vector SVG Export):** In `handlePinToBoard`, remove the isolated `activeView === 'integral'` branch. Export using the unified `generateGraphSvg` which incorporates both curve, extrema, and integral layer matching the screen layout.
5. **FR-05 (Two-way Reactive Sync):** Numerical inputs for $a$ and $b$ trigger board updates; conversely, dragging gliders on the board updates the numerical inputs and area readout in real time.

---

## Non-Functional Requirements

- **Performance:** Glider drag and integral area re-evaluation updates at 60 FPS ($< 16$ms latency).
- **Code Cleanliness:** Anti-God Class invariant (files $\le 900$ lines) and zero code duplication between graph rendering and integral rendering.
- **Visual Fidelity:** Full contrast on chalkboard (crisp white axes `#ffffff`, chalk grid `rgba(255, 255, 255, 0.18)`, red curve `#DC2626`, translucent fill `rgba(220, 38, 38, 0.22)`).

---

## Success Criteria

- [ ] Single canvas `#graphContainer` powers both 'Đồ thị' and 'Tích phân' views.
- [ ] Exported sticker on chalkboard displays continuous curve from `xMin` to `xMax` with integral shaded region strictly between $a$ and $b$.
- [ ] All 7/7 Math Studio engine tests and 5/5 app logic simulation tests pass 100%.
- [ ] 12/12 Clean Architecture invariants pass 100%.

---

## Out of Scope

- 3D Revolution Solid changes (already handles its own 2.5D projection mode).
- Multivariable double integrals or 3D volume integrals.

---

## Assumptions

- JSXGraph's native `board.create('integral', ...)` and `generateGraphSvg` integral shading provide mathematically accurate Riemann numerical approximations for high school calculus.

