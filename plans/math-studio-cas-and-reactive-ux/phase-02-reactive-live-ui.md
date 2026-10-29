# Phase 02: Non-Intrusive Floating Studio Window (820x540px) & Reactive Live Plotting Bar

## Objective
Overhaul `plugins/math_studio/ui/index.html`, `style.css`, and `app.js` into a compact, non-intrusive floating studio ($820\text{px} \times 540\text{px}$) that does NOT cover the teacher's chalkboard, featuring an in-canvas Floating Formula Island where typing immediately morphs the curve at 60fps (< 16ms).

## Files to Modify
1. `plugins/math_studio/ui/index.html`:
   - Eliminate the heavy 2-column sidebar layout (`.sidebar-tray` and `.sidebar-card`).
   - The root body contains:
     - Full canvas container (`#graphContainer`, 100% width and height).
     - **Floating Formula Island** (`#floatingFormulaIsland`): A slender horizontal pill bar pinned at top-center containing:
       - Formula input field: `y = f(x)` with clear button `✕`.
       - Quick math chip drawer button: `[+ Công thức]`.
       - Mode switcher pills: `[Đồ thị]` `[BBT]` `[Tích phân]`.
       - Primary action: **`[Ghim vào bảng]`**.
     - Quick Math Symbols Bar: Pops down smoothly on demand (`x²`, `x³`, `√`, `a/b`, `sin`, `cos`, `π`).
     - Floating Viewport Island: `[+]` `[−]` `[⟲ Chuẩn SGK]` at bottom-right.
2. `plugins/math_studio/ui/style.css`:
   - Set fixed desktop modal container dimensions: `820px` width, `540px` height, `border-radius: 20px`, `overflow: hidden`.
   - Subtle double-bezel border (`border: 1px solid rgba(15, 23, 42, 0.08)` and inner highlight).
   - Glassmorphism for the Floating Formula Island (`backdrop-filter: blur(14px)`, `background: rgba(255, 255, 255, 0.88)`).
3. `plugins/math_studio/ui/app.js`:
   - Reactive Live Rendering: Input event on formula input triggers immediate parse & curve morphing with 80ms debounce.
   - Zero-click feature rendering: Critical points (extrema, intercepts) are drawn as small interactive dots directly on the JSXGraph curve without needing a separate list.
   - When user clicks `[Ghim vào bảng]`:
     - Calls `serializeLiveBoardSvg()`.
     - Sends sticker payload to Flutter Host via `window.HocLuc.callRpc('studio:insertSticker')`.
     - Calls `window.HocLuc.close()` to immediately dismiss the floating window and return the teacher to the full chalkboard.

## Verification
- Test typing in browser: `x^3 - 3*x` renders in < 16ms with zero stutter.
- Modal dimensions verified at exactly 820px × 540px.

