# Phase 02 — Pen gesture routing and progressive indexing

**Stories:** P1 Smart Snap toggle; P1 drag preservation; P1 progressive indexing; P3 textless-page fallback.

## Tasks

1. Add Smart Snap state to `StudioState` and a small toggle alongside pen color/width controls in both vertical and horizontal layouts in `studio_drawing_toolbar.dart`. Keep it independent from tool, color, and width; disable/cancel queued smart taps when toggled off.
2. Connect PDF readiness/current page changes in `pdf_stage.dart` to start visible-page extraction first, then enqueue nearby pages in increasing distance. Run one extraction at a time and reprioritize the newly visible page on navigation. Keep the viewer usable while indexing and avoid eager full-document scans.
3. Extend the PDF pen gesture path to capture pointer down/move/up and reuse the current Flutter tap recognizer behavior. Document its actual movement and duration semantics: the default touch tap slop is 18 logical pixels (inclusive), precise mouse/trackpad tap slop is 1 logical pixel, and `TapGestureRecognizer` imposes no maximum press duration. Its 100 ms press timeout only controls when `onTapDown` may fire; Smart Snap defers classification until `onTapUp`. Defer tap-dot commit until classification; route drags through the existing `StrokeCanvas` freehand path without Smart Snap lookup.
4. Transform tap position to canonical page coordinates and query the ready page index. While building, queue at most 32 ordered taps with canonical point, page number, and document generation; additional taps use current ordinary pen tap behavior. Replay queued taps against their captured page even after navigation, provided Smart Snap remains enabled and the PDF generation is unchanged. For misses and textless pages, invoke current ordinary tap behavior; recognized answers suppress the tap dot and dispatch a smart selection. If multiple verified hit regions match, fail closed with ordinary tap behavior.
5. Add disposal, page-change, document-replacement, and error handling so stale indexing/queued work is ignored without blocking freehand drawing.

## Acceptance / Verification

- Widget tests toggle Smart Snap in both toolbar layouts without changing pen properties.
- With Smart Snap off, existing tap and drag behavior is preserved. With it on, a drag past thresholds creates one ordinary stroke and no oval; a tap does not produce a dot before its smart result.
- A tap while the current index is building is resolved in original order after readiness; queued taps are discarded after toggle-off or PDF replacement.
- At exactly 18 logical pixels, a touch remains a tap; moving beyond that slop is rejected as a tap and continues through the existing stroke gesture path. A long press remains eligible as a tap on release because Flutter's tap recognizer has no maximum duration. Overlapping eligible hit regions never choose arbitrarily.
- Current page starts indexing before nearby pages; only one extraction runs at a time, navigation reprioritizes the newly visible page, and opening a long PDF does not wait for all pages.
- Queued taps stay attached to their captured page after navigation; after 32 pending taps, further taps use ordinary pen behavior.
- Blank, non-answer, extraction-failed, and textless-page taps create no smart oval and follow existing ordinary pen behavior.

## Likely files

- `frontend/lib/widgets/pdf_stage.dart`
- `frontend/lib/widgets/stroke_canvas.dart` or a focused gesture adapter used by it
- `frontend/lib/widgets/studio/studio_drawing_toolbar.dart`
- `frontend/lib/models/studio_state.dart`
- New `frontend/test/smart_pen_gesture_test.dart`; update relevant PDF/studio widget tests.

## Risks

- Flutter gesture-arena ownership may change page pan/zoom behavior; test with interactive mode, pan tool, space-pan, and pointer devices.
- Keep nearby-page work bounded and reprioritize when the visible page changes; do not permit background work to starve the active page.
