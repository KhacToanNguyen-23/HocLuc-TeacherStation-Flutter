# Phase 02: Zero-Destruction Board Lifecycle & In-Place Updates

**Goal:** Eliminate the 50–150ms drop-frame freeze when clicking buttons (Extrema toggle, Intercept toggle, Color swatch, Point add/remove) by updating JSXGraph element attributes in place instead of destroying and rebuilding the board.

**Target Files:**
- [`plugins/math_studio/ui/board/graph_board.js`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/board/graph_board.js)
- [`plugins/math_studio/ui/app.js`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/app.js)

---

## Detailed Tasks

1. **Refactor `renderJSXGraphBoard` in `graph_board.js`**:
   - Check if an active board instance already exists on `containerId`.
   - Determine if a full board rebuild is strictly required:
     - Full rebuild needed ONLY if: board does not exist, algebraic formula changed (`formulaClean` differs), or switching between Integral and 2D graph views.
   - If formula is unchanged and only appearance/toggles changed:
     - Wrap updates in `board.suspendUpdate()` and `board.unsuspendUpdate()`.
     - Toggle visibility of existing Extrema points, projection lines, and labels (`showExtrema`).
     - Toggle visibility of existing Intercepts (`showOxIntercept`, `showOyIntercept`).
     - Update stroke color on curve branches in place (`branch.setAttribute({ strokeColor: curveColor })`).
     - Incrementally reconcile custom marked points (`markedPoints`).
     - Return existing board immediately without calling `destroyJSXGraphBoard()`.

2. **Register Elements on Board Instance**:
   - Store clean element references in `board._hoclucElements`:
     - `extremaElements`: points, dashed projection segments, coordinate foot labels.
     - `interceptElements`: $Oy$ and $Ox$ points and projection labels.
     - `curveElements`: curve functiongraph branches.
     - `asymptoteElements`: vertical, horizontal, and oblique lines.

3. **Pass Action Intent from `app.js`**:
   - In `app.js`, refine `changedKeys` emitted to `renderCurrentView`:
     - When toggling extrema / intercepts: emit `['pointToggles']`.
     - When changing color: emit `['curveColor']`.
     - When clicking custom points: emit `['markedPoints']`.
   - Ensure `graph_board.js` leverages these keys for instant execution.

---

## Acceptance Criteria
- [ ] Clicking `[Cực trị]`, `[Giao trục]`, or Color swatches updates in $\le 16\text{ms}$ without invoking `destroyJSXGraphBoard()`.
- [ ] No visual flicker or layout jump when toggling parameters.
- [ ] Projection lines and foot coordinate labels hide/show synchronously with points.

