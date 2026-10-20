# Cleaner board curves
Mode: fast
Risk: normal — reversible stroke rendering change; no data format changes.

## Plan
- [x] Share outline generation between active and committed ink.
- [x] Use midpoint quadratic curves for a smooth closed outline; modestly raise streamline to 0.65 and smoothing to 0.75.
- [x] Keep original input points, dot handling, widths, and pressure behavior.
- [x] Run architecture, handwriting tests, plugin validator, formatting, and code review.

## Session Notes
Shared buildInkPath handles pixel coordinates for live and cached committed strokes.
Architecture: 12 passed. Existing handwriting tests: 4 passed. Plugin validator: 0 errors.
Independent code review: no actionable findings. Git hooks activated.
Full Flutter analyzer: no issues found. Changed-file analyzer: no issues found. Interactive drawing comparison remains for visual acceptance.

