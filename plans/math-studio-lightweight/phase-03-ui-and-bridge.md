# Phase 3: Minimalist High-End UI & Host Bridge

## Objective
Implement the streamlined, full-screen Math Studio UI (Header + Canvas) with fluid drag interactions and Host Chalkboard Stamping.

## Implementation Details
1. File: `plugins/math_studio/src/app/main.jsx`
   - Top Header Bar:
     - Math input `f(x) = ...` with instant debounced parsing.
     - Mode switcher: `[ 📈 Đồ thị 2D ]` | `[ 🪐 Khối tròn xoay 3D ]`.
     - 3D bounds slider $[a, b]$ visible only in 3D mode.
     - Viewport tools: `[ 🔍+ ] [ 🔍- ] [ ↺ Reset ]`.
     - Action buttons: `[ 📌 Ghim vào bảng ]` and `[ ✕ ]`.
   - Direct Pointer Interaction on Canvas:
     - In 2D: drag to pan, wheel to zoom.
     - In 3D: drag to rotate 360° freely in all directions.
   - Chalkboard Stamping:
     - Call `Bridge.insertAnnotation({ type: 'com.hocluc.plugin.math_studio', data: { imageBase64, svgContent, ... } })`.
2. File: `plugins/math_studio/ui/style.css`
   - Clean, dark, high-end chalkboard styling.
   - Full 100% stage utilization.

## Acceptance Criteria
- UI loads instantly without sidebar clutter.
- 360° 3D rotation responds smoothly to pointer movements.
- Ghim vào bảng successfully exports PNG & SVG.

