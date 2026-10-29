# Spec: Zero-Hardcode Micro-CAS & Non-Intrusive Reactive Live Math Studio

**Date:** 2026-10-27
**Status:** Brainstorm Approved — Ready for Planning (`$bb-plan`)

---

## 1. Problem Statement
The current `plugins/math_studio/ui/core/symbolic_cas.js` contains over 1030 lines of code littered with hardcoded function type checks (`classifyFunctionAST` with `cubic`, `quartic`, `rational1`, `rational21`), magic bounding numbers (`[-9, 9]`), and manual AST traversal.
Simultaneously, the existing UI uses a rigid, form-heavy 2-column layout with cumbersome accordion cards that feels like an administrative data-entry form rather than a live, fluid blackboard tool.
The teacher requires:
1. **Zero hardcoding & extreme lightweight footprint**: Eliminate all family-based if-else branches in favor of pure analytical calculus theorems, reducing `symbolic_cas.js` from 1030+ lines down to ~220 lines with 0 external runtime dependencies.
2. **"Nhập đến đâu vẽ đến đó" (Reactive Live Plotting) without blocking the blackboard**: The studio must be a compact, non-intrusive floating window ($820\text{px} \times 540\text{px}$) leaving the teacher's chalkboard visible around it, where typing immediately renders the curve at 60fps, and clicking "Ghim vào bảng" instantly commits the chalk vector and closes the window.

---

## 2. User Stories & Priority

### Story 1 (P1 — Zero-Hardcode Analytical Micro-CAS)
As a teacher using Teacher Station,
I want to enter ANY mathematical function (polynomial, rational of any degree, square root, exponential, logarithmic, trigonometric)
So that the system automatically plots the exact curve, finds critical points, and computes asymptotes without being restricted to a hardcoded set of textbook function presets.

### Story 2 (P1 — Reactive Live Plotting: "Nhập đến đâu vẽ đến đó")
As a teacher drafting or presenting a graph,
I want the coordinate curve to react and morph smoothly in real-time (< 16ms) as I type characters or tap math symbol chips,
Without needing to hit an extra "Calculate" or "Draw" button or scroll through sidebar form sections.

### Story 3 (P1 — Non-Intrusive Compact Studio Canvas)
As a teacher conducting a live classroom or Google Meet broadcast,
I want the Math Studio window to appear as a compact, floating glass card ($820\text{px} \times 540\text{px}$) in the center of the chalkboard,
So that my chalkboard notes, student knock alerts, and PDF documents are NEVER completely obscured, and clicking "Ghim vào bảng" immediately closes the modal and pins the chalk vector.

### Story 4 (P2 — Universal Analytical Asymptotes & Adaptive Domain Extrema)
As a mathematics instructor,
I want asymptotes and extrema to be derived from universal mathematical limit theorems ($a = \lim_{x \to \pm\infty} \frac{f(x)}{x}, b = \lim_{x \to \pm\infty} [f(x) - ax]$) and adaptive root scanning,
So that functions with roots or asymptotes at large numbers ($|x| > 10$) are never missed by a hardcoded `[-9, 9]` boundary.

---

## 3. Architecture & Functional Requirements

### 3.1. Micro-CAS Architecture (`plugins/math_studio/ui/core/`)
```
Raw Formula Input
       │
       ▼
[Compact Lexer & Recursive Descent Parser (~75 LOC)] ──► Pure Mathematical AST
       │
       ├──► [Universal Chain-Rule Differentiator (~65 LOC)]
       │       • (u+v)', (u*v)', (u/v)', (u^n)', f(g(x))'
       │       • sin, cos, tan, exp, ln, sqrt, abs
       │
       ├──► [Analytical Limit & Asymptote Solver (~50 LOC)]
       │       • a = lim(x -> ±∞) f(x)/x, b = lim(x -> ±∞) [f(x) - ax]
       │       • a = 0, b finite   ==> TCN: y = b
       │       • a ≠ 0, b finite   ==> TCX: y = ax + b
       │       • Vertical asymptotes: Roots of Q(x)=0 where |f(x)| -> ∞
       │
       └──► [Adaptive Dynamic Interval Extrema Solver (~50 LOC)]
               • Scans critical points f'(x) = 0 and inflection points f''(x) = 0
               • Expands domain dynamically if roots approach search boundary
```
- **File Reduction**: Delete the bulky 1030-line `symbolic_cas.js` implementation and replace with a pure, concise `micro_cas.js` (< 240 lines).
- **Zero Family Hardcoding**: Eliminate all strings `'cubic'`, `'quartic'`, `'rational1'`, `'rational21'`. The renderer treats every function as a general analytic mapping $x \mapsto f(x)$.

### 3.2. Compact Floating Canvas UI & Reactive UX (`plugins/math_studio/ui/`)
1. **Window Dimensions & Layout**:
   - Fixed desktop modal footprint: $820\text{px} \times 540\text{px}$ (calibrated 3:2 aspect ratio).
   - The chalkboard behind the modal remains visible on top, bottom, left, and right (at least 200px margins on typical 1080p display).
   - The coordinate canvas takes 100% of the modal viewport.
2. **Floating Formula Island**:
   - A slender floating pill bar ($48\text{px}$ height, rounded-full, frosted acrylic glass `backdrop-filter: blur(12px)`) pinned at the top-center of the canvas.
   - Live Formula Input: typing immediately updates the formula display and triggers curve re-draw within $80\text{ms}$ debounce ($16\text{ms}$ animation frame).
   - In-bar CTA Button: **`[Ghim vào bảng]`** in the same island bar. Clicking it executes SVG serialization and triggers `HocLuc.close()` so the teacher is returned to the chalkboard with zero extra clicks.
3. **Automatic Feature Pinning (Zero Clicks)**:
   - Extrema and intercepts are computed dynamically and rendered as subtle interactive dots on the live curve. Hovering or clicking reveals the coordinate badge.

---

## 4. Measurable Success Criteria

| Metric | Target | Verification Method |
| :--- | :--- | :--- |
| **Code Size** | `symbolic_cas.js` / CAS engine reduced from **1030 LOC $\to$ $\le 250$ LOC** (>75% reduction) | `Get-Content plugins/math_studio/ui/core/symbolic_cas.js \| Measure-Object -Line` |
| **Zero Hardcoded Types** | Exactly 0 occurrences of `'cubic'`, `'quartic'`, `'rational1'`, `'rational21'` in `plugins/math_studio/ui/core/` | `Select-String -Path plugins/math_studio/ui/core/*.js -Pattern "rational1|rational21|'cubic'|'quartic'"` returns 0 matches |
| **Live Typing Latency** | Input debounced at 80ms, redraw completed in $\le 16\text{ms}$ (60fps) | Performance profiling in Chromium WebView2 DevTools |
| **Chalkboard Visibility** | Modal dimensions strictly bounded to $820\text{px} \times 540\text{px}$ | CSS inspection in `style.css` and `floating_plugin_window.dart` |
| **Packaging & CI Gate** | `validate_plugins.mjs` passes 100%, `architecture_test.dart` passes 12/12, `flutter analyze` 0 issues | Standard CI verification commands |

---

## 5. Non-Goals
- Generating 3D geometry models from free-form Vietnamese problem statements via natural language processing (explicitly deferred by user to a future phase).
- Bundling large heavy external math libraries (e.g. `mathjs` 700KB) that burden user hardware.

