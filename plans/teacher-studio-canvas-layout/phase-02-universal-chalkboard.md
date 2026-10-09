# Phase 02: Universal Dark Chalkboard Canvas

**Objective:** Transform the app into a subject-agnostic teaching canvas with dark slate green theme (`#14221D`), 24x24 student grid lines, and purge all hardcoded math/parabola artifacts.

---

## Tasks

1. **Theme Overhaul:**
   - Change default canvas background to `#14221D` (Deep Slate Chalkboard).
   - Update text/toolbar contrast for dark mode ergonomics (muted chalk white `#E8EAE6`, lime green accent `#D4E8A6`).
2. **Build `GridPainter`:**
   - Create `app/lib/widgets/grid_painter.dart`.
   - Render $24 \times 24\text{ px}$ subtle student grid lines (`color: Color(0x1AFFFFFF)` or soft muted sage) for comfortable handwriting alignment.
3. **Purge Subject-Specific Hardcoding:**
   - Remove hardcoded `studio.subject = 'Toán học'`, `studio.title = 'Khảo sát hàm số bậc hai'`, and math parabola function from `main.dart` and `BoardPainter`.
   - Set universal default title: `"Không gian giảng dạy"` / `"Trạm phát sóng bài giảng"`.
   - Provide clean multi-page chalkboard management (Trang 1, Trang 2, Trang 3...).

---

## Files Affected
- `app/lib/main.dart`
- `app/lib/models/studio_state.dart`
- `app/lib/widgets/grid_painter.dart` (new)

---

## Acceptance Criteria
- [ ] Canvas opens by default in dark slate green with subtle grid lines.
- [ ] No math-specific parabola curve or quadratic formulas appear automatically.
- [ ] Multi-page navigation (Trang 1/2/3) cleanly isolates chalk strokes per board page.
