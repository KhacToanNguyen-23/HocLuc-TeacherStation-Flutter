# Spec: Math Studio Zero-Lag Architecture & High-Performance Lifecycle

**Date:** 2026-10-27  
**Status:** Ready  
**Invoked Skills:** bb-brainstorm  

---

## Problem Statement

Teachers experience noticeable latency and spinning loaders when opening Math Studio, toggling parameter buttons, and dragging the coordinate graph due to full board re-instantiation, tree-walking AST evaluation in the 60fps render loop, and cold WebView2 boots. This spec details the zero-destruction lifecycle, native JIT compiler, and host keep-alive optimizations to deliver instant 60 FPS responsiveness.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher, I want clicking parameter toggle buttons (Extrema CĐ/CT, Intercepts, Color swatches) to respond in $\le 16\text{ms}$ without dropping frames, so that the UI feels snappy and responsive.  
  *Accepted when:* Toggling extrema or intercepts updates element attributes in place without calling `destroyJSXGraphBoard()` or re-creating the board DOM.

- **[P1]** As a teacher, I want dragging/panning the graph to run at 60 FPS buttery-smooth, so that the curve follows my mouse/touch pointer without stutter.  
  *Accepted when:* Graph dragging evaluates curve points via JIT-compiled native JS functions (`(x) => Math.pow(x, 3) - 3 * x`), reducing CPU consumption to $\le 8\%$.

- **[P1]** As a teacher, I want Math Studio to open instantly without an annoying spinning loading wheel, so that my classroom flow is never interrupted.  
  *Accepted when:* Modal re-opens in $< 100\text{ms}$ without triggering `CircularProgressIndicator` on warm sessions.

- **[P2]** As a teacher, I want 3D geometry and future 3D surfaces to retain full parametric rendering capabilities without hardcoding.  
  *Accepted when:* Zero hardcoded geometry constants are introduced; generic parametric transformations remain functional.

- **[P3]** _(Out of scope)_ WebGL hardware shader acceleration for complex multivariable surfaces $z = f(x, y)$ (future roadmap).

---

## Functional Requirements

1. **FR-01 (Non-Destructive In-Place Board Updates)**:
   - `renderJSXGraphBoard` must create the JSXGraph board only on initial mount or when switching active board panel / algebraic formula.
   - Visibility toggles (`showExtrema`, `showOxIntercept`, `showOyIntercept`, `curveColor`, `markedPoints`) must update existing JSXGraph elements in-place using `board.suspendUpdate()`, `.setAttribute({ visible: ... })` or element property mutations, followed by `board.unsuspendUpdate()`.
   - Never call `destroyJSXGraphBoard()` or `initBoard()` on button clicks.

2. **FR-02 (JIT Fast Function Compiler)**:
   - In `plugins/math_studio/ui/core/math_cas.js` and `micro_cas.js`: implement `compileFastEvaluator(ast)` that converts validated mathematical AST trees into native JavaScript arithmetic strings (`Math.pow`, `Math.sqrt`, `Math.sin`, etc.) and compiles a native closure: `new Function('x', 'return ' + expr)`.
   - The JSXGraph curve plotter must call this native function directly, eliminating tree-walking overhead and `try-catch` blocks inside the high-frequency sampling loop.
   - Maintain AST fallback for malformed expressions.

3. **FR-03 (Tick & Label Throttling during Pan)**:
   - Cache projection foot coordinates during viewport changes.
   - Avoid quadratic array scans in `generateLabelText` on every pixel move.

4. **FR-04 (Host Flutter Pre-warming / Warm Keep-Alive)**:
   - In `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart` and `flat_host_native.dart`: preserve the initialized WebView2 instance offscreen or in memory when dismissing the modal so reopening does not re-initialize the process or reload `jsxgraphcore.js` from scratch.

---

## Non-Functional Requirements

- **Button Click Latency**: $\le 16\text{ms}$ (1 frame at 60Hz).
- **Graph Pan/Drag Framerate**: $\ge 58\text{fps}$ on standard Intel Core i3 / i5 integrated graphics.
- **CPU Usage during Drag**: $\le 8\%$ (reduced from 100% core saturation).
- **Memory Consumption**: $\le 50\text{MB}$ in WebView2.
- **Cold Boot Time**: $\le 300\text{ms}$; Warm Boot Time: $\le 50\text{ms}$.

---

## Success Criteria

- [ ] Button click latency (extrema, intercepts, color): $\le 16\text{ms}$ with zero `destroyJSXGraphBoard` calls.
- [ ] Graph pan/zoom framerate: 60 FPS verified without drop-frame stutter.
- [ ] Curve evaluation throughput: $\ge 1,000,000$ points/sec via JIT native compiled evaluator.
- [ ] Warm modal open time: $< 100\text{ms}$ without visible loading spinner.
- [ ] Plugin validation (`node scripts/validate_plugins.mjs`) passes 100%.
- [ ] Architecture tests (`flutter test test/architecture_test.dart`) pass 12/12 invariants.
- [ ] Analyzer (`flutter analyze --no-fatal-infos`) reports 0 issues.

---

## Out of Scope

- Removing JSXGraph or replacing it with raw Canvas (dismissed to avoid hardcoding regressions).
- WebGL GPU compute shaders for 2D curves.

---

## Assumptions

- Target machines have at least Intel Core i3 / i5 (8th gen or newer), 8GB RAM, and Windows 10/11.
- Edge WebView2 Runtime is installed and hardware acceleration is enabled by default.

