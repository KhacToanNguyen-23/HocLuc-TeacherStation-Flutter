# Phase 04: 16:9 Ergonomic Stage & Fast Switcher (F1/F2/F3)

**Objective:** Build a fixed 16:9 Stage Container for Virtual Camera output with keyboard shortcuts and 1-touch top bar switching between Full Board, Full PDF, and Split View.

---

## Tasks

1. **Build `StageContainer` Widget:**
   - Create `app/lib/widgets/stage_container.dart`.
   - Use `AspectRatio(aspectRatio: 16 / 9, ...)` wrapped in `FittedBox` to lock the studio into an exact 16:9 aspect ratio without letterbox skewing.
2. **Implement Viewport State Machine:**
   - Add enum `StudioViewportMode { fullBoard, fullPdf, split }`.
   - In `Split` mode: Left 50% = `PdfStage`, Right 50% = `ChalkboardCanvas`.
   - In `Full Board` mode: 100% = `ChalkboardCanvas`.
   - In `Full PDF` mode: 100% = `PdfStage` (with margin scratchpad).
3. **Keyboard Shortcuts & Top Bar Buttons:**
   - Bind `F1` -> `fullBoard`, `F2` -> `fullPdf`, `F3` -> `split` via `CallbackShortcuts` / `HardwareKeyboard`.
   - Render segmented toggle buttons on the Top Bar with intuitive icons (`[ 📝 Bảng (F1) ]`, `[ 📄 PDF (F2) ]`, `[ 🌓 Chia đôi (F3) ]`).
4. **Transition Polish:**
   - Add smooth animated width interpolation (`AnimatedContainer` / `AnimatedCrossFade`) for fluid 60 FPS transitions between split and fullscreen modes.

---

## Files Affected
- `app/lib/widgets/stage_container.dart` (new)
- `app/lib/models/studio_state.dart`
- `app/lib/main.dart`

---

## Acceptance Criteria
- [ ] Pressing F1, F2, F3 switches between Full Board, Full PDF, and Split View instantly.
- [ ] Top bar buttons reflect active mode with prominent visual state.
- [ ] Stage maintains exact 16:9 aspect ratio regardless of window resizing.
