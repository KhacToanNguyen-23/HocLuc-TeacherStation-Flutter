# Phase 01: Interactive Stroke Engine (perfect_freehand)

**Objective:** Implement calligraphic stroke smoothing using `perfect_freehand` and `CustomPainter` to simulate natural chalkboard writing and laser pointing.

---

## Tasks

1. **Add Dependency:**
   - Update `app/pubspec.yaml` to include `perfect_freehand: ^2.0.1`.
   - Run `flutter pub get`.
2. **Refactor Stroke Model (`BoardStroke`):**
   - Update `app/lib/models/studio_state.dart` to store raw `PointVector` (x, y, pressure) for each stroke.
   - Support variable stroke width, color, and tool mode (`pen`, `eraser`, `laser`).
3. **Build `SmoothStrokePainter`:**
   - Create `app/lib/widgets/stroke_canvas.dart`.
   - Implement `getStroke(points, options: ...)` to generate outline polygons.
   - Convert outline points into a smooth `Path` rendered via `canvas.drawPath()`.
4. **Implement Laser Pointer Mode:**
   - Track cursor position via `MouseRegion(onHover: ...)`.
   - Render a glowing green/white light circle (radius 5px, radial glow blur) when laser mode is active.

---

## Files Affected
- `app/pubspec.yaml`
- `app/lib/models/studio_state.dart`
- `app/lib/widgets/stroke_canvas.dart` (new)

---

## Acceptance Criteria
- [ ] `flutter test` compiles without errors.
- [ ] Pen strokes have smooth, rounded tapered ends without sharp corner artifacts.
- [ ] Laser pointer follows mouse coordinates smoothly.
