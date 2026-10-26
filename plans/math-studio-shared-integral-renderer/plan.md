# Plan: Math Studio Shared Renderer for Integral (WYSIWYG)

**Date:** 2026-10-26  
**Mode:** --fast  
**Risk:** normal — multi-file plugin UI unification (index.html, app.js), fully testable with existing JS test suites.  
**Spec:** `plans/math-studio-shared-integral-renderer/spec.md`  
**Report:** `plans/reports/261026-math-studio-shared-integral-renderer-brainstorm.md`  

---

## Architecture Overview

```
Teacher selects tab 'Tích phân'
            │
            ▼
[Shared Inspector Panel]               [Shared Canvas Container: #graphContainer]
├── Cận a, Cận b inputs                ├── Full coordinate axes Ox, Oy & grid numbers
├── Formula S = ∫ |f(x)| dx            ├── Continuous curve spans full viewport (xMin → xMax)
└── Live area S ≈ ...                  ├── Extrema markers (CĐ, CT) preserved
                                       └── Reactive integral shading & draggable gliders [a, b]
                                                       │
                                                       ▼ (Teacher clicks 'Ghim lên bảng')
                                       "BẢNG CÓ CÁI GÌ IN RA ĐÚNG CÁI ĐÓ"
                                       (100% WYSIWYG export via generateGraphSvg)
```

---

## Phase Breakdown

- [x] **Phase 1: DOM & Viewport Unification (`index.html` & `app.js`)**
  - Removed isolated `#integralGraphContainer` and `#integralViewPanel`.
  - Maintained `#graphContainer` as the single shared canvas across both 'Đồ thị' and 'Tích phân'.
  - Mounted integral controls (cận $a$, cận $b$, công thức, diện tích $S$) into the inspector when in 'integral' view mode.
  - Updated `renderIntegralTable` to update the active integral on the shared `#graphContainer`.

- [x] **Phase 2: Unified Vector SVG Export & Continuous Curve (`app.js` & `graph_plotter.js`)**
  - In `app.js` (`handlePinToBoard`), removed the isolated branch for integral export.
  - Used unified `generateGraphSvg` with `theme: 'chalkboard'` where the function curve continuously covers the viewport from `xMin` to `xMax` and the shaded integral region covers $[a, b]$.
  - Re-packaged and validated: `node scripts/validate_plugins.mjs --fix`.
  - All automated test suites pass 100%.

## Session Notes
**Last active:** 2026-10-26 16:19  
**Phase in progress:** Completed  
**Status:** All phases verified and passing 100%  

### Decisions made this session
- Unified DOM: `#graphContainer` is now the single shared canvas across graph and integral modes.
- Unified WYSIWYG export: Graph and integral use identical SVG generator and aspect ratio (`520 / 380`).
- True continuous curves: Function curve extends across full viewport `[xMin, xMax]` with integral shading spanning $[a, b]$.

