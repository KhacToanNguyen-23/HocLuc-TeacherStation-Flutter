# Brainstorm: Unified Shared Renderer for Math Studio Integral

**Date:** 2026-10-26

## Ideas Explored
1. **Option 1: Merge Integral directly into Main Graph Sidebar** — Remove tab 'Tích phân' entirely; place limits $a, b$ as a tool card in the left sidebar alongside 'ĐIỂM' and 'CỰC TRỊ'.
2. **Option 2 (User's Pick): Keep 'Tích phân' Tab in Header but share 100% Canvas & Renderer with Main Graph** — Maintain pedagogical separation via the header tab, but eliminate duplicate DOM `#integralViewPanel` / `#integralGraphContainer`. Both 'Đồ thị' and 'Tích phân' render into the same `#graphContainer` using identical JSXGraph board and vector SVG export pipeline, fulfilling "bảng có cái gì thì in ra cái đó" (WYSIWYG).

## User's Direction
The user selected **Phương án 2**:
- Maintain the 'Tích phân' tab in the dialog header for structured lesson flows.
- Enforce the shared architecture: "cực đại cực tiểu và bảng biến thiên... là bảng có cái gì thì in ra có cái đó".
- Eliminate isolated rendering loops where the integral curve was truncated at bounds $a$ and $b$, and remove hardcoded manual UI badges.

## Open Questions
- When switching between 'Đồ thị' and 'Tích phân', should integral shading automatically remain visible or toggle according to active sub-mode?
- When dragging gliders $a, b$ directly on JSXGraph, ensure two-way binding with input numbers $a, b$ in the inspector without triggering redraw flickering.

## Risks
- Board resizing or layout transitions when switching tabs must preserve the JSXGraph board state without re-initializing from scratch if the canvas is shared.
- Exported vector SVG must contain the continuous mathematical curve across the entire viewport bounds while preserving the integral shaded area between $a$ and $b$.

