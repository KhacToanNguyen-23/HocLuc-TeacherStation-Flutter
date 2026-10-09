# Phase 05: Floating Studio Accessories (Camera PIP, Timer, Left Drawer)

**Objective:** Build non-intrusive floating accessories including a 16:9 Camera PIP card, pill countdown timer, and slide-out question drawer to preserve maximum writing area.

---

## Tasks

1. **Floating Camera PIP Card:**
   - Create `app/lib/widgets/floating_pip.dart`.
   - Card dimensions: $240 \times 135\text{ px}$ (16:9 ratio), rounded corners $12\text{ px}$, subtle dark border.
   - Positioned at top-right corner; supports `GestureDetector` / `Draggable` for moving around the canvas and a toggle to minimize/hide.
2. **Floating Pill Timer Widget:**
   - Create `app/lib/widgets/floating_timer.dart`.
   - Pill-shaped chip anchored at top-center displaying `MM:SS`.
   - Click opens mini popover to adjust duration (e.g. 5m, 10m, 15m), Start, Pause, and Reset.
   - Emits visual pulse/border glow when time runs out.
3. **Collapsible Left Drawer for Questions & Table:**
   - Create `app/lib/widgets/drawer_questions.dart`.
   - Slide-in panel from left margin ($320\text{ px}$ width, animation $\le 250\text{ms}$).
   - Displays lesson outline / question list; clicking a question selects it and automatically slides the drawer shut to free the canvas.

---

## Files Affected
- `app/lib/widgets/floating_pip.dart` (new)
- `app/lib/widgets/floating_timer.dart` (new)
- `app/lib/widgets/drawer_questions.dart` (new)
- `app/lib/main.dart`

---

## Acceptance Criteria
- [ ] Camera PIP floats cleanly over canvas without blocking primary drawing tools, can be toggled on/off.
- [ ] Timer runs accurately, can be paused/reset, and does not obstruct board content.
- [ ] Drawer slides out smoothly from left edge and auto-collapses upon item selection.
