# Brainstorm: Math Studio Zero-Lag Architecture & High-Performance Lifecycle

**Date:** 2026-10-27  
**Status:** Complete  
**Scope:** `plugins/math_studio` and `frontend/lib/features/plugin_engine`

---

## 1. Challenge & Diagnosis

Teachers reported three distinct performance bottlenecks during classroom usage:
1. **Startup Delay**: A rotating spinner ("started plugin phải quay tròn") on cold launch.
2. **Button Click Latency**: Noticeable UI freeze (50–150ms drop-frames) when toggling parameters (Cực trị, Giao trục, Đổi màu).
3. **Graph Drag Stutter**: Laggy, jittery panning when dragging the coordinate graph on school laptops.

### Architectural Root Causes:
- **`plugins/math_studio/ui/render/` diagnosis**: Clarified that `ui/render/` only houses BBT SVG generation and export stickers; it is **not** the bottleneck.
- **Root Cause 1 (Board Destruction Anti-Pattern)**: `renderJSXGraphBoard()` called `destroyJSXGraphBoard()` and `initBoard()` on **every state change**, completely tearing down and rebuilding SVG DOM trees, axis ticks, and listeners for simple visibility toggles.
- **Root Cause 2 (Tree-Walking AST in 60fps Render Loop)**: `analysis.eval(x)` traversed an object AST tree recursively with `try-catch` on every sample pixel during mouse move (thousands of evaluations per second).
- **Root Cause 3 (Host Cold Boot)**: `FlatHost` destroyed and recreated WebView2 controllers on launch, reloading the 922KB `jsxgraphcore.js` and showing `CircularProgressIndicator`.

---

## 2. Ideas Explored

1. **Option A: Clean Lifecycle + JIT Fast Math Compiler (Selected)**
   - Maintain JSXGraph for mathematical robustness and future 3D surfaces ($z = f(x, y)$).
   - Eliminate `destroyJSXGraphBoard` on state toggles; update elements in-place with `board.suspendUpdate()` / `.setAttribute()`.
   - Compile AST expressions into native JavaScript closures (`new Function('x', '...')`), achieving > 1,000x faster sampling at 60 FPS.
   - Pre-warm or keep WebView2 active in Flutter Host.

2. **Option B: Pure HTML5 Canvas Micro-Engine from Scratch (Dismissed)**
   - Replace JSXGraph with a ~25KB custom 2D Canvas renderer.
   - **Dismissal Reason (Raised by User)**: Writing a custom renderer from scratch will inevitably reintroduce hardcoded special cases when extending to 3D surfaces, planes, spheres, and solids of revolution. Modern PCs (Core i3/i5, 8GB RAM, SSD) easily handle a 40MB WebView2 memory footprint; the real culprit was CPU spike, not bundle size.

---

## 3. User's Direction

The user emphasized:
> *"nếu sau này muốn render ảnh trục 3d từ hàm số thì phương án b có khả thi, phương án b đang dần quay về hardcode à"*  
> *"nhưng vẫn nặng máy giáo viên không, case này có quan trọng lắm trong thời buổi hiện tại không"*

- **Verdict**: Decided unanimously on **Option A (Clean Lifecycle + JIT Fast Math Compiler)**.
- **Key Decision**: Protect the generic pedagogical architecture against hardcoding regressions while achieving true 60fps performance through in-place DOM updates and native JIT execution.

---

## 4. Open Questions & Implementation Strategy

1. **In-Place Updates**: How to map store actions (`TOGGLE_POINT_MARK`, `SET_CURVE_COLOR`) directly to JSXGraph element visibility without breaking SGK projection lines?
   - *Strategy*: Retain element registry on the board instance (`board._hoclucElements = { extrema, intercepts, curve }`) and toggle visibility selectively.
2. **JIT Compilation Safety**: Can arbitrary user input cause syntax errors in `new Function`?
   - *Strategy*: Compile only validated mathematical ASTs into safe arithmetic strings (`Math.pow`, `Math.sin`, etc.). If parsing fails, fall back to AST evaluator with 0 risk of injection.
3. **Flutter Pre-warm**: How to minimize spinner visibility?
   - *Strategy*: Use `Offstage` or cache the `FlatHost` controller in `StudioState` so closing and reopening does not reload WebView2.

---

## 5. Risks & Mitigations

- **Risk**: JSXGraph state desync if in-place updates fail on complex asymptote boundaries.
  - **Mitigation**: Full board re-init ONLY when the algebraic formula or view tab changes; lightweight in-place update for color/toggles/points.
- **Risk**: WebView2 memory leak if kept alive indefinitely.
  - **Mitigation**: Limit pre-warmed pool to 1 active instance for Math Studio; dispose on app exit.

