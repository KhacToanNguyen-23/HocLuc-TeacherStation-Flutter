# Brainstorm: Math Studio Plugin UI/UX, Rendering Quality & Architecture Overhaul

**Date:** 2026-10-27

## Ideas Explored

1. **Performance & Cold-Start Optimization (Why opening `math_studio` feels heavy)**
   - **WebView2 Lifecycle**: `FloatingPluginWindow` returns `SizedBox.shrink()` when closed, disposing `FlatHost` and killing the Chromium Edge WebView2 process on every close, and recreating it on every open or sticker edit (`ValueKey` tied to `editingSticker?.id`).
   - **HTTP Caching in `PluginWebServer`**: `PluginWebServer._servePluginFile` sets `Cache-Control: no-cache, no-store, must-revalidate` on all files, forcing WebView2 to re-download and re-compile `vendor/jsxgraph/jsxgraphcore.js` (~922 KB) on every open.
   - **Synchronous CAS Init & Un-debounced Input**: `MathStudioStore.init()` runs 3,400+ numerical loops synchronously during module evaluation, and `mathInput` dispatches `SET_FORMULA` on every keystroke without debounce, calling `destroyJSXGraphBoard()` + `initBoard()` on every character.

2. **Text Resolution, Crispness & SGK Coordinate System Aesthetics (TikZ / Textbook Standard)**
   - **Half-Pixel WebView2 Texture Blurring**: `FloatingPluginWindow` positions the modal at `(availW - dialogW) / 2.0`, landing on `.5` fractional logical pixels when dimensions are odd, causing Direct3D bilinear texture blurring across all text.
   - **ClearType Disabled by Transparent Body**: `body.academic-modal-body` uses `background: transparent` + `-webkit-font-smoothing: antialiased`, disabling Windows ClearType sub-pixel font rendering.
   - **JSXGraph Label Stroke Bleed & Font Mismatch**: `graph_board.js` applies `stroke-width: 3px` white halo on tiny `10px–11.5px` bold text, making glyphs look bloated and pixelated; `view_3d_board.js` falls back to `Courier, monospace`.
   - **Coordinate Label Collisions & Missing Projection Foot Labels**:
     - `offset: [0, offsetY]` in `graph_board.js` is ignored by JSXGraph when `anchor` is not passed, causing `CĐ (-1.0; 2.0)` and `CT (1.0; -2.0)` to render directly on top of the extremum dot and collide with tick `2` on the $Oy$ axis.
     - Origin `O` at `(-0.35, -0.35)` is clipped at the top into a `∪` shape.
     - Curve $y = x^3 - 3x$ cuts directly through tick label `-2` on $Ox$ because tick labels lack a subtle background halo.
     - Dashed projection lines (`đường gióng`) land on $Ox$ at $x = -1, 1$, but $Ox$ only shows even ticks (`-4, -2, 2, 4`), leaving the projection feet unlabeled—violating Vietnamese SGK convention.
   - **Stiff Axes & Heavy Arrows**: Default JSXGraph triangle arrowheads (`size: 8`), thick `5px` extremum dots, and coarse `dash: 2` lines look stiff compared to sleek LaTeX TikZ / SGK stealth arrows, `3.2px` dots, and fine `3,3` dashed projection lines.

3. **Eliminating Hardcoded Math & Fixing Disconnected ("Dead") Features**
   - **Disconnected `ĐIỂM` Controls (`Giao Ox`, `Giao Oy`, `Cực trị`, `+ Thêm điểm`)**:
     - `markedPoints` (holding `Giao Ox`, `Giao Oy`, and custom points from `store.getCombinedMarkedPoints()`) is destructured at `graph_board.js:48` and **never used anywhere** in `graph_board.js`, nor shown in the sidebar list.
     - `showExtrema` (`Cực trị` toggle) is never passed to `renderJSXGraphBoard`, so toggling `Cực trị` off only hides the sidebar list while `CĐ`/`CT` stay permanently drawn on the graph.
     - `+ Thêm điểm` (`#btnAddPoint`) only toggles a local boolean `isAddPointMode` and shows a toast without binding any click handler on the JSXGraph board.
   - **Hardcoded `type: 'cas_function'` Breaking Inverse Drag & Antiderivatives**:
     - `math_cas.js` hardcodes `type: 'cas_function'` and omits `coeffs`, dead-coding all polynomial/rational classification branches in `curve_manipulator.js` (dragging extrema) and `integral_solver.js` (`getAntiderivativeString`).
     - `solveIntegral` throws when `a >= b`, crashing `recomputeAnalysis` and wiping out the entire `analysis` state across all tabs.
   - **Hardcoded Startup State & Broken Host SDK Bridge**:
     - `store.js` hardcodes `x^3 - 3*x` and ignores URL query parameters (`?editId=...&formula=...`) and `window.__hocluc_load_edit` when editing an existing board sticker.
     - `plugins/math_studio/ui/sdk.js` lacks `window.HocLuc.close()` and `window.HocLuc.onMessage()`, breaking the `✕` / `Hủy` buttons and sticker edit reload.
   - **Bloated Fake Buttons on Chalkboard `BoardStickerFloatingBar`**:
     - Out of 11 buttons in `board_sticker_floating_bar.dart` (`Phát quay`, `Góc nhìn: Sách GK`, `Trước`, `Trên`, `Bên`, `Xoay 3D`, `Sửa`, `Sao chép`, `Nhân bản`, `Cắt`, `Xóa`), 8 are fake/redundant placeholders: `Phát quay`, `Sách GK`, `Trước`, `Trên`, `Bên`, `Xoay 3D` all just call `onEdit`, `Sao chép` duplicates `Nhân bản`, and `Cắt` duplicates `Xóa`.
     - Strip down to only the **3 essential, working actions**: **`✎ Sửa`**, **`⧉ Nhân bản`**, **`🗑 Xóa`** in a compact pill bar.
   - **Unreadable Programmer-Syntax Function & Derivative Display (`HÀM SỐ` Card)**:
     - Both `#mathInput` (`x^3 - 3*x`) and `#derFormulaBadge` (`y' = 3x^2 - 3`) display raw ASCII code with `^` and `*` (`textContent` in `app.js:101`).
     - `symbolic_cas.js` does not algebraically simplify quotient-rule numerators, so `(2x+1)/(x-1)` produces `y' = (2 * (x - 1) - (2x + 1)) / (x - 1)^2` instead of $\frac{-3}{(x-1)^2}$.
     - `math_keyboard.js` already contains an academic HTML formatter (`.frac`, `<sup>`, `√`) that was orphaned and never wired up.
   - **Cluttered & Mathematically Inaccurate Integral Tab (`Tích phân`)**:
     - **Stray JSXGraph `∫ = -0.7500` Label on Graph**: `board.create('integral', ...)` in `graph_board.js:371` omits `withLabel: false`, causing JSXGraph to print a huge blue `∫ = -0.7500` floating label on the canvas.
     - **Extrema Clutter on Integral Graph**: The integral board draws `CĐ (-1.0; 2.0)` and `CT (1.0; -2.0)` and blue dots right on top of the integral boundary $a = -1$, colliding with `a = -1.0` and `b = 2.0` (which also collides with tick `2` on $Ox$).
     - **Duplicate Result Rows & Inaccurate `3.7501` Area**: `#intFormulaDisplay` and `#intAreaResult` both repeat `S ≈ 3.7501` twice instead of cleanly showing Definite Integral $I = \int_a^b f(x)\,dx = -0.75\ (-3/4)$ vs. Geometric Area $S = \int_a^b |f(x)|\,dx = 3.75\ (15/4)$. And Simpson's rule on $|f(x)|$ fails to split at roots ($x = 0, \sqrt{3}$), producing `3.7501` instead of exact `3.75`.
     - **Redundant `Tính toán` Button & Derivative Shown Instead of Antiderivative $F(x)$**: Bounds inputs `a, b` require clicking a bulky `Tính toán` button instead of live-updating, and the `HÀM SỐ` card shows `Đạo hàm: y'` instead of `Nguyên hàm: F(x)` when on the Integral tab.
   - **Invisible 3D Geometry Export on Chalkboard & Vision for Problem-Text-to-3D Generator**:
     - `view_3d_board.js` draws edges in `#0b2348`, which `board_exporter.js` misses when converting dark lines to white, making the pyramid invisible on the dark chalkboard.
     - Vertex labels (`S, A, B, C`) are rendered as HTML `<div>` outside `<svg>` and vanish on export; meanwhile, 3 useless `Ox, Oy, Oz` white sticks remain in the center of the pyramid, and the sticker badge prints raw code `pyramid_tri`.
     - Teacher workflow needs a **Vietnamese Geometry Problem Parser** (e.g. *"Cho hình chóp S.ABCD đáy hình vuông, SA vuông góc với đáy, M là trung điểm SC, H là hình chiếu của A lên SB"*) that automatically constructs the exact 3D textbook figure with altitude, right-angle markers, midpoints, and dashed hidden edges.
   - **Useless & Clunky `KHUNG NHÌN HỆ TRỤC` Accordion Card**:
     - The 6 manual inputs (`x từ -6`, `x đến 6`, `y từ -4.1`, `y đến 4.1`, `Vạch x 2`, `Vạch y 2`) do not sync with mouse pan/zoom, require blurring the input (`change` event) to trigger, and clutter the sidebar.
     - Should be removed completely and replaced by **Smart Auto-Fit SGK Viewport** (automatically framing extrema, intercepts, and asymptotes with clean 1/2/5 tick steps) plus a minimal `[+] [−] [⟲ Chuẩn SGK]` floating button group on the corner of the canvas.

## User's Direction
The user highlighted four core pain points that must all be resolved cohesively:
1. Why opening `math_studio` loads heavily/slowly.
2. Hardcoded math state and broken CAS classification (`store.js` / `math_cas.js`).
3. Coarse, pixelated text resolution, overlapping coordinate labels (`CĐ`/`CT` colliding with dots and $Oy$ axis, clipped `O`), and stiff coordinate lines/arrows compared to SGK standards.
4. Broken interactive point tools (`Giao Ox`, `Giao Oy`, `Cực trị`, `+ Thêm điểm` not working on the graph).

## Open Questions
- None blocking planning; all root causes have been verified directly in the source files.

## Risks
- **SVG Export Fidelity (`flutter_svg`)**: `flutter_svg` does not support external CSS classes or `paint-order: stroke`. All typography, colors, halos (using background rects or duplicate under-text), and marker paths must be serialized as explicit inline SVG XML attributes in `board_exporter.js`.
- **JSXGraph Update vs Re-init**: Updating curves/points in-place without `freeBoard`/`initBoard` requires careful tracking of created board elements (`curve`, `extrema`, `markedPoints`, `projections`) so pan/zoom state is preserved without leaking SVG nodes.

