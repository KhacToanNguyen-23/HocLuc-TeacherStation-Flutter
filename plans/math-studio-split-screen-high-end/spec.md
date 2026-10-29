# Spec: Math Studio High-End Split-Screen Architecture (35% Left Parameter Tray, 65% Right Render Board)

**Date:** 2026-10-27  
**Status:** Ready  
**Invoked Skills:** bb-brainstorm, high-end-visual-design  

---

## Problem Statement

Teachers need a unified pedagogical workspace where analytical parameters (formula, derivative, critical extrema, intercepts, and asymptotes) and the live visual graph are simultaneously visible side-by-side in a 35:65 ratio, without crowding the chalkboard or requiring mental context switches between separate tabs or screens.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a math teacher, I want a dedicated left parameter tray (35% width) displaying the formula input, analytical derivative, domain $D$, extrema (CĐ/CT), intercepts, and asymptotes, so that all textbook analytical parameters are immediately readable in one place.  
  *Accepted when:* Left panel occupies ~35% of the 960px modal (~336px) and displays live parameter cards populated dynamically from `micro_cas.js`.

- **[P1]** As a math teacher, I want the right panel (65% width) to display the live interactive JSXGraph board (or BBT / 3D / Integral board), so that the curve morphs reactively as I type formula or change parameters.  
  *Accepted when:* Right panel occupies ~65% of the modal (~624px) and renders at 60fps in < 16ms with 1:1 square aspect ratio axes.

- **[P1]** As a math teacher, I want the `[Ghim vào bảng 📌]` action button positioned at the top-right of the window header, so that I can click it cleanly and have the SVG pin to my blackboard while the studio automatically closes.  
  *Accepted when:* Clicking top-right `[Ghim vào bảng 📌]` serializes vector SVG, sends RPC to Flutter Host, and dismisses the modal after 300ms.

- **[P2]** As a math teacher, I want hovering over a critical point card on the left panel to highlight the corresponding point on the right canvas, so that students can visually connect numbers to geometry.  
  *Accepted when:* Hovering an extremum card changes the corresponding JSXGraph point's stroke/fill color dynamically.

- **[P3]** _(Out of scope)_ Dragging points on the canvas to reverse-solve formula coefficients.

---

## Functional Requirements

1. **FR-01 (Modal Geometry & Doppelrand Architecture)**:
   - Window size: $960\text{px}$ width $\times$ $560\text{px}$ height (`manifest.json` set to `"default_width": 960, "default_height": 560`).
   - Outer shell: Soft structuralism bezel with `border-radius: 20px`, hairline border (`rgba(15, 23, 42, 0.08)`), and ambient drop shadow.
   - Inner core split: CSS Flexbox with `flex: 0 0 35%` (Left Parameter Tray) and `flex: 1 1 65%` (Right Render Stage).
2. **FR-02 (Header & Top-Right Pin CTA)**:
   - Header bar (height: 50px): Left side displays brand glyph `ƒ(x)` + mode switcher tabs (`Đồ thị`, `BBT`, `Tích phân`, `Hình 3D`).
   - Right side displays high-contrast action CTA: `[Ghim vào bảng 📌]` and close button `[✕]`.
3. **FR-03 (Left Parameter Tray Content)**:
   - Card 1: Formula Input `y = f(x)` with Clear button `✕`, quick math chips drawer button (`x²`, `x³`, `√x`, `a/b`), live derivative badge $y' = ...$, and domain $D = \mathbb{R} \setminus \{...\}$.
   - Card 2: Special Points & Asymptotes (Extrema CĐ/CT with exact rational fractions $(x; y)$, Intercepts $Oy$ and $Ox$, Asymptotes TCĐ, TCN, TCX).
   - Card 3 (Contextual): Integral bounds glider controls ($a, b, I, S$) when in Integral mode; 3D shape presets and prompt parser when in 3D mode.
4. **FR-04 (Right Render Stage)**:
   - 100% height and width of the 65% column.
   - Pinned bottom-right floating viewport island: `[+]`, `[−]`, `[⟲ Chuẩn SGK]`.
   - Responsive canvas auto-resize maintaining 1:1 tick proportions.
5. **FR-05 (Zero-Hardcode CAS Integration)**:
   - All parameters derived dynamically through `micro_cas.js` (zero hardcoded function families).

---

## Non-Functional Requirements

- **Performance**:
  - Live typing to curve morph latency $\le 16\text{ms}$ (80ms debounce).
  - Memory consumption $\le 15\text{MB}$ inside WebView.
- **Visual Design Quality**:
  - Apple/Linear-tier high-end aesthetic (nested double-bezel, ClearType math typography, smooth `cubic-bezier(0.32, 0.72, 0, 1)` transitions).
- **Chalkboard Harmony**:
  - $960\text{px} \times 560\text{px}$ leaves $> 480\text{px}$ on left/right and $> 260\text{px}$ on top/bottom of a 1080p chalkboard, never occluding the teacher's handwritten notes.

---

## Success Criteria

- [ ] Modal window geometry: strictly $960\text{px} \times 560\text{px}$, centered.
- [ ] Left column width: strictly 35% (~336px); Right column width: strictly 65% (~624px).
- [ ] Parameter panel displays live formula, analytical derivative, domain, extrema (CĐ/CT), intercepts, and asymptotes.
- [ ] Primary CTA `[Ghim vào bảng 📌]` sits at top-right of the header and auto-closes the modal upon pinning.
- [ ] `node scripts/validate_plugins.mjs` passes 100% with 0 errors.
- [ ] `flutter test test/architecture_test.dart` passes 12/12 invariants.
- [ ] `flutter analyze --no-fatal-infos` outputs "No issues found!".

---

## Out of Scope

- Full-screen modal (violates chalkboard visibility constraint).
- Reverse-solving equation by dragging extrema points on graph.

---

## Assumptions

- Teacher screen resolution is at least $1366 \times 768$ (Full HD $1920 \times 1080$ standard).
- WebView engine supports standard CSS Flexbox and `backdrop-filter`.

