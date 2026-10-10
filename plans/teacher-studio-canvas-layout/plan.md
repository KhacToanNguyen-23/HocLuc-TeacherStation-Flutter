# Plan: Universal Teaching Studio Canvas & Ergonomic Split Layout

**Mode:** Hard  
**Risk:** normal — Multi-component Flutter UI, rendering pipeline, and state management refactoring without auth/schema/infra risk.  
**Spec:** `plans/teacher-studio-canvas-layout/spec.md`  
**Date:** 2026-10-09  

---

## Architecture Overview

```
+-----------------------------------------------------------------------------------+
|  16:9 STAGE CONTAINER (Aspect ratio fixed at 16:9, Virtual-Camera ready)          |
|  Keyboard Shortcuts: F1 (Full Board) | F2 (Full PDF) | F3 (Split 50/50)           |
+-----------------------------------------------------------------------------------+
|  TOP BAR: Mode Switcher (F1/F2/F3) | Floating Timer (05:00) | Tools (Pen/Eraser/Laser)
+-----------------------------------------+-----------------------------------------+
|  LEFT VIEWPORT (PDF Stage)              |  RIGHT VIEWPORT (Dark Chalkboard)       |
|  - Engine: pdfrx (PDFium)               |  - Engine: Flutter CustomPainter        |
|  - Ingestion: FilePicker + Drag & Drop  |    + perfect_freehand stroke smoothing  |
|  - Per-page annotation layer            |  - Theme: Slate Green #14221D + Grid    |
|  - Laser pointer tracking               |  - Laser pointer tracking               |
|                                         |  - Floating PIP Camera (240x135 px)     |
+-----------------------------------------+-----------------------------------------+
|  COLLAPSIBLE DRAWER: Slide-out question & table directory (left edge)             |
+-----------------------------------------------------------------------------------+
```

---

## Phase Roadmap

| Phase | File | Priority | Scope Summary |
| :--- | :--- | :--- | :--- |
| **01** | [x] [`phase-01-drawing-engine.md`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/plans/teacher-studio-canvas-layout/phase-01-drawing-engine.md) | **P1** | Add `perfect_freehand`, implement natural stroke smoothing, Pen/Eraser/Laser tools. |
| **02** | [x] [`phase-02-universal-chalkboard.md`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/plans/teacher-studio-canvas-layout/phase-02-universal-chalkboard.md) | **P1** | Dark slate green theme (`#14221D`), 24x24 grid lines, purge hardcoded math parabola. |
| **03** | [x] [`phase-03-pdf-integration.md`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/plans/teacher-studio-canvas-layout/phase-03-pdf-integration.md) | **P1** | Add `pdfrx` viewer, FilePicker + Drag & Drop, per-page stroke annotation storage. |
| **04** | [x] [`phase-04-split-stage-switcher.md`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/plans/teacher-studio-canvas-layout/phase-04-split-stage-switcher.md) | **P1** | 16:9 fixed AspectRatio stage, F1/F2/F3 shortcuts and 1-touch top bar switcher. |
| **05** | [x] [`phase-05-floating-accessories.md`](file:///d:/6_OJT/HocLuc-TeacherStation-Flutter/plans/teacher-studio-canvas-layout/phase-05-floating-accessories.md) | **P2** | Draggable 16:9 Camera PIP card, pill countdown timer, slide-out question drawer. |

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-09 17:33  
**Phase in progress:** None — All 5 phases completed!  
**Status:** All 5 phases complete (Drawing engine, Chalkboard canvas, PDF integration, Stage switcher, Floating accessories).  

### Decisions made this session
- Installed `pdfrx: 2.6.5`, `file_picker: 13.1.0`, and `desktop_drop: 0.8.4`.
- Created `PdfStage` supporting drag & drop directly onto the stage and native file picking.
- Implemented per-page annotation dictionary `Map<int, List<BoardStroke>> pdfAnnotations` in `StudioState`.
- Implemented `StageContainer` locking the output to an exact 16:9 aspect ratio with F1/F2/F3 shortcuts and 1-touch `ViewportModeSwitcher` (Full Board, Full PDF, Split 50/50).
- Implemented `FloatingPip` ($240 \times 135$ draggable webcam card with live mic indicator and minimization).
- Implemented `FloatingTimer` (top pill badge with quick presets, play/pause, reset, and countdown alert).
- Implemented `DrawerQuestions` (slide-out left drawer with auto-collapse on item click).
- Validated with 19/19 passing Flutter unit & widget tests and 0 `dart analyze` issues.

### Next immediate action
Ready for deployment and teacher classroom broadcast!

---

## Verification Strategy

1. **Unit & Widget Tests:**
   - Stroke smoothing and outline path generation via `perfect_freehand`.
   - Per-page annotation dictionary isolation (switching PDF page swaps strokes).
   - Viewport state machine transitions (F1 -> F2 -> F3).
2. **Interactive Acceptance:**
   - Verify 16:9 stage scaling without distortion.
   - Verify laser dot position follows mouse hover without lag.
   - Verify drag-and-drop PDF ingestion on Flutter desktop/web.
