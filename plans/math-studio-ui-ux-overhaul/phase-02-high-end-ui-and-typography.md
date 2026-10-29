# Phase 02: High-End Visual Design (`Soft Structuralism + Double-Bezel`), UI Restructure & Keep/Drop Cleanup

## Objective
Rebuild `plugins/math_studio/ui/index.html`, `style.css`, and `app.js` following `/high-end-visual-design` (Soft Structuralism + Academic Editorial), eliminating all coarse/pixelated typography, removing dead/clunky UI sections (`KHUNG NHÌN HỆ TRỤC`, `Tính toán` button), and adding live textbook math typesetting.

## Files to Modify
1. `plugins/math_studio/ui/index.html`
   - Remove `<script src="sdk.js"></script>` so `PluginWebServer` injects `/__hocluc_sdk__/hocluc-plugin-sdk.js`.
   - Header: Floating Pill Island tab switcher (`Đồ thị`, `Bảng biến thiên`, `Tích phân`, `Hình 3D SGK`).
   - Left Sidebar (`Double-Bezel` hardware tray):
     - **Card 1 (`HÀM SỐ`)**:
       - 4-color swatch selector pill (`#1D4ED8` SGK Blue, `#DC2626` Crimson, `#059669` Emerald, `#D97706` Amber).
       - Clean input row + live **Academic Math Preview Box** (rendering stacked fractions $\frac{u}{v}$, exponents $x^3$, radicals $\sqrt{\dots}$).
       - Quick symbol & SGK family chips (`x²`, `x³`, `a/b`, `√`, `Bậc 3`, `Trùng phương`, `Nhất biến`).
       - Context-aware calculus row: displays `Đạo hàm:` ($y'$) on Graph/BBT tabs and automatically switches to `Nguyên hàm:` ($F(x)$) on the Integral tab.
     - **Card 2 (`ĐIỂM ĐẶC BIỆT` — Graph tab)**:
       - Toggle pills (`Cực trị`, `Giao Ox`, `Giao Oy`) + `+ Thêm điểm` button + unified coordinate list showing active extrema, intercepts, and custom points (with `✕` delete on custom points).
     - **Card 3 (`TÍCH PHÂN & DIỆN TÍCH` — Integral tab)**:
       - Auto-updating bounds row (`Cận a = [...] → b = [...]`, no `Tính toán` button).
       - Two distinct, crystal-clear SGK metric cards:
         1. **Tích phân xác định**: $I = \int_a^b f(x)\,dx$ (with exact value + fraction badge)
         2. **Diện tích hình phẳng**: $S = \int_a^b |f(x)|\,dx$ (with exact value + fraction badge)
     - **Card 4 (`HÌNH HỌC KHÔNG GIAN SGK` — 3D tab)**:
       - Vietnamese Geometry Problem input (`textarea` with quick sample prompts) + 6 SGK solid presets (`Chóp S.ABCD`, `Chóp S.ABC`, `Chóp đều`, `Lăng trụ đứng`, `Hình nón`, `Hình trụ`).
     - **Removed**: `#advancedAccordionCard` (`KHUNG NHÌN HỆ TRỤC`).
   - Right Preview Column:
     - Floating `[+] [−] [⟲ Chuẩn SGK]` zoom/reset island in the bottom-right corner of the 2D graph & integral boards.
   - Footer:
     - Pill `Button-in-Button` primary CTA (`Ghim vào bảng`) with trailing icon circle and spring hover/active physics.
2. `plugins/math_studio/ui/style.css`
   - Set opaque `#F8FAFC` background on `body.academic-modal-body` (enabling Windows ClearType sub-pixel antialiasing) and remove double modal border/shadow.
   - Apply Double-Bezel container styling, custom `cubic-bezier(0.32, 0.72, 0, 1)` transitions, `.math-frac` 2-story fraction layout, and clean `12px–16px` typography.
3. `plugins/math_studio/ui/app.js`
   - Add `120ms` debounce on `#mathInput` typing (keeping existing graph visible with subtle `"Đang nhập..."` status when expression is mid-type like `x^`).
   - Wire up quick math chips, SGK function presets, 4-color swatch picker, `[+] [−] [⟲]` zoom controls, live `a, b` integral bound inputs, and `window.__hocluc_load_edit`.

