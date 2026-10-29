# Brainstorm: Math Studio High-End Split-Screen Architecture (35% Left Parameter Tray, 65% Right Render Board)

**Date:** 2026-10-27  
**Slug:** math-studio-split-screen-high-end  
**Invoked Skills:** bb-brainstorm, high-end-visual-design  

---

## Ideas Explored

1. **Floating Formula Island on 100% Canvas (Previous Phase)**:
   - Ultra-compact floating pill at top-center over full-width graph.
   - *Verdict*: Good for quick drawing, but limits visibility of comprehensive mathematical parameters (critical points, intercepts, asymptotes) side-by-side with the curve.
2. **50% : 50% Symmetrical Split**:
   - Equal width for parameters and canvas.
   - *Verdict*: Rejected by user; restricts 2D graph aspect ratio and cramps the JSXGraph viewport while leaving excess whitespace in the parameter panel.
3. **The Editorial Split (35% Parameter Tray : 65% Render Canvas) — High-End Doppelrand**:
   - Selected by user: Left panel (35% width) houses the double-bezel parameter controls (Formula, Derivative, Extrema, Intercepts, Asymptotes).
   - Right panel (65% width) houses the high-contrast JSXGraph live render board.
   - Pinned top-right action button: `[Ghim vào bảng 📌]` + Close `✕`.
   - *Verdict*: **Accepted (Recommended)** — gives the feel of an Apple Pro / Linear-tier hardware studio.

---

## User's Direction

- **Panel Placement**: Bảng thông số bên Trái, nhìn đồ thị bên Phải.
- **Ratio**: Khoảng 35% thông số : 65% render.
- **Data displayed on Parameter Panel**: Chỉ công thức + các điểm đặc biệt (Cực trị CĐ/CT, Giao trục $Ox/Oy$, Tiệm cận TCĐ/TCN/TCX, Tập xác định $D$, Đạo hàm $y'$).
- **CTA Pin Button**: Lựa chọn B — đặt thành nút Action ở góc trên cùng bên Phải của Header.
- **Chalkboard Harmony**: Modal kích thước $960\text{px} \times 560\text{px}$ căn giữa, để lộ $> 480\text{px}$ bảng đen hai bên và $> 260\text{px}$ trên dưới.

---

## Open Questions for Planning

1. **Interactive Highlight**: Does hovering over an extremum card on the left panel highlight the corresponding point on the right JSXGraph canvas? (Yes, via JSXGraph `strokeColor` / `fillColor` temporary highlight).
2. **Mode Switching**: Does mode switching (Đồ thị, BBT, Tích phân, Hình 3D) switch the right render canvas while keeping the left parameter panel contextually adapted? (Yes, Left panel adapts metrics to the active mode).

---

## Risks & Mitigations

1. **Risk: JSXGraph aspect ratio and canvas stretching**:
   - *Mitigation*: Set explicit CSS `flex: 0 0 65%` and call `board.setBoundingBox()` during resize so axes ticks remain 1:1 square.
2. **Risk: Modal width crowding low-resolution screens**:
   - *Mitigation*: $960\text{px} \times 560\text{px}$ fits comfortably on standard $1366 \times 768$ and $1920 \times 1080$ teacher laptop screens.

