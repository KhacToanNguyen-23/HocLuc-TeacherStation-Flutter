# Phase 0 Spike Result: Excalidraw in WebView2 / Chromium

**Date:** 2026-10-29  
**Decision:** **GO (APPROVED)**  
**Verification Method:** Automated headless Edge (`msedge.exe`) run via `puppeteer-core` with real local HTTP server + simulated pointer interactions.

---

## 1. Experimental Answers to Core Questions

### Q1. Bundle Feasibility & WebView2 Compatibility
- **Status:** **PASS**
- **Build tool:** `esbuild` with `conditions: ['production']`, `format: 'iife'`, `minify: true`. Build time: **~950 ms**.
- **Runtime:** Tested in Chromium/Edge 120+ (identical engine to WebView2). Page loaded and initialized in **934 ms**. Zero console errors. Excalidraw canvas mounted and rendered smoothly.

### Q2. 100% Offline & Asset Integrity
- **Status:** **PASS**
- **Asset path:** `window.EXCALIDRAW_ASSET_PATH = './';`
- **Network trace results:**
  - Total HTTP requests: 11 (all to `http://127.0.0.1:<port>`)
  - External network requests (CDN / unpkg / Google Fonts): **EXACTLY 0**
  - Font files loaded locally:
    - `Assistant-Bold-ZDZZ6JHA.woff2` (20 KB)
    - `Assistant-Regular-PLF2XOGW.woff2` (20 KB)
    - `Assistant-Medium-DZ25RZU3.woff2` (20 KB)

### Q3. Interactive Dragging Architecture: Approach (b) Selected
- **Selection:** **Approach (b) — `viewModeEnabled: true` + Transparent Interaction Overlay (`zIndex: 100`)**
- **Why not Approach (a):**
  - In native edit mode, Excalidraw wraps selected elements in bounding boxes with 8 resize handles. Dragging a handle would warp point $M$ into an ellipse or scale the dashed line $y=m$.
  - Native element drag allows arbitrary 2D movement, causing point $M$ to drift off the curve $y=f(x)$.
- **Why Approach (b) excels:**
  - Excalidraw operates in clean presentation mode (`viewModeEnabled: true`, `zenModeEnabled: true`).
  - Overlay captures pointer events with `pointerdown` / `pointermove` / `pointerup` (and `setPointerCapture`).
  - $M(x_0)$ is mathematically constrained to the curve: horizontal movement updates $x_0$, and $y_0 = f(x_0)$ automatically evaluates.
  - Line $y=m$ is constrained to vertical displacement.
  - Proven in headless test: Dragging $M$ from $x_0=2.0$ to $x_0=1.0$ updated tangent line slope from $9.00$ to $0.00$ instantly; dragging $y=m$ updated $m$ from $0.00$ to $2.00$ with 0 console errors.

### Q4. Bundle Size & Performance Baseline
- `entry.js`: 8,215 KB (~8.0 MB minified)
- `entry.css`: 141 KB
- Fonts: 80 KB
- Load time: ~934 ms
- Drag latency: Real-time synchronous scene update via `excalidrawAPI.updateScene(...)`.

---

## Conclusion
Phase 0 is **GO**. Proceed to Phase 1 (TDD Math Engine).

