# Phase 04 — Integration, coordinate, and performance validation

**Stories:** all P1 and P2 stories; confirms P3 fallback.

## Tasks

1. Run the versioned labeled synthetic corpus through the complete extraction → grouping → spatial query pipeline using fixed generator seeds/layout variants. Report sample counts, precision/recall, false-positive examples, and supported layout assumptions; adjust only toward conservative rejection when criteria conflict.
2. Exercise full PDF interaction at 50%, 100%, and 200% zoom and with rotated pages where `pdfrx` supports rotation; verify that hit areas remain page-local and tolerance remains viewport-scaled.
3. Test races: visible page changes during extraction, PDF replacement during indexing, queued tap followed by disable, queue-capacity overflow, multiple queued taps, queued taps replayed after page navigation against their captured page, overlapping hit regions, and index failure. Confirm active-page priority and stale-result cancellation.
4. Verify freehand drag, ordinary tap fallback, undo/redo, answer replacement, page switching, PDF export, and toolbar state as one integrated workflow.
5. Profile current-page indexing/frame impact on Windows desktop and web, plus lookup p95 with at least 1,000 candidates. Document extraction latency separately from ready-index lookup.

## Acceptance / Verification

- Fixture classifier reaches at least 99% precision and 90% recall; if the fixture tradeoff prevents both, prioritize precision and document the measured recall and rejected layouts.
- Ready-index lookup p95 is below 1 ms with 1,000 candidates; report target and measurement method.
- In a 100-page text PDF, current-page use is not gated on whole-document indexing; adjacent work is progressive and responsive to page navigation.
- Coordinate, queue, cancellation, fallback, undo/export, and interaction tests pass, along with the required architecture test.
- Flutter's default tap movement threshold is documented and covered at the boundary: touch slop is 18 logical pixels (inclusive), precise mouse/trackpad slop is 1 logical pixel; the recognizer has no maximum press duration (100 ms is only the `onTapDown` press timeout). Queue cap/overflow behavior is covered; ambiguous spatial matches fail closed. Queue capacity is 32; overflow taps use ordinary pen behavior.
- Run planned focused commands plus broader affected PDF/studio tests; record actual commands and results in the implementation session notes.

## Risks

- Target-device profiling can reveal indexing work that is too expensive even when lookup is fast. Keep extraction asynchronous, cap concurrent work, and prioritize the visible page.
- Synthetic fixture thresholds may overstate real-PDF performance. Limit claims to the agreed corpus and plan follow-up evaluation on representative teacher PDFs before expanding classifier behavior.

## Execution record — 2026-10-18

- Synthetic corpus: 5 deterministic layouts, 16 expected labels; classifier produced 16, precision 100%, recall 100%, 0 false positives and 0 false negatives. These results apply only to the agreed generated fixtures.
- Ready-index workload: 1,000 candidates and 1,000 lookups; p95 55 microseconds on this Windows host. Generated-PDF extraction measured 26 ms for the vertical fixture (19 fragments) and 2 ms for the two-column fixture (24 fragments). These are single test-run timings, not device percentiles.
- Coordinates: automated coverage includes 50%, 100%, and 200% zoom tolerance, rotated pdfrx page extraction, all four inverse display-to-PDF rotation transforms, and exporting ink while retaining a 90-degree source-page rotation. The review found no remaining P1/P2 issue in the Phase 04 coordinate change.
- Races and interactions: page/generation queue ordering, the 32-tap cap and overflow fallback, page navigation while indexing, reprioritization, disable behavior, stale generations, ambiguous overlaps, textless/extraction failure, pen drag/tap routing, undo/redo, replacement, and export are covered by the focused suites.
- `flutter test --no-pub test/smart_pen_index_test.dart test/smart_pen_gesture_test.dart test/smart_pen_annotation_test.dart test/pdf_integration_test.dart test/handout_export_test.dart test/studio_test.dart test/architecture_test.dart`: 61 tests passed.
- `flutter analyze --no-pub` on the 10 changed implementation/test files: no issues found. `git diff --check` and `feature_list.json` JSON parsing passed.
- `flutter build windows --profile --no-pub`: succeeded; produced `build/windows/x64/runner/Profile/teaching_companion.exe`. `flutter build web --profile --no-pub` also succeeded earlier in this session.
- `flutter test --no-pub --platform chrome test/smart_pen_annotation_test.dart` did not reach test startup and remained silent until stopped. Therefore actual browser-runner interaction and live Windows/web frame-time profiling were not measured. Profile builds and host-side timings do not substitute for frame profiling on representative devices.
- Real teacher PDFs remain outside the agreed initial corpus. Evaluate them before broadening classifier support.

Phase 04 automation and generated-corpus runtime profiling are complete; the continuation record below supersedes the earlier unmeasured-profile note. Dense-page Web extraction latency and representative teacher-PDF evaluation remain release follow-ups.

## Continuation record — 2026-10-18

- The profile harness uses a generated 612 × 10,000-point PDF page with 320 option labels and 1,920 extracted text fragments. It runs the production `pdfrx` extractor and answer classifier. Each platform result is one synthetic workload run, not a device percentile or a real teacher-PDF result.
- Final Windows Profile run: total index 20 ms (extraction 19 ms; classification below the 1 ms display resolution), 320 candidates. One frame was attributed to the index window (build p95 969 µs, raster p95 863 µs). The largest 16 ms timer interval overlapping the index window was 18.0 ms.
- Final Web Profile run in headless Chrome: total index 137 ms (extraction 125 ms; classification 11 ms), 320 candidates. Nine frames were attributed to the index window (build p95 5.0 ms, raster p95 5.1 ms). The largest timer interval overlapping the index window was 89.8 ms. `pdfrx` text extraction dominates this dense synthetic Web workload and can pause the event loop; evaluate and optimize with representative teacher PDFs before release claims about Web responsiveness.
- The classifier now tracks row bounds incrementally and prunes answer groups outside the existing vertical grouping window. The fixed generated corpus remains at 100% precision and 100% recall (5 cases, 16 expected labels, no false positives/negatives). The latest 1,000-candidate ready-index test measured p95 lookup 64 µs.
- Final affected test command: `flutter test --no-pub test/smart_pen_index_test.dart test/smart_pen_gesture_test.dart test/smart_pen_annotation_test.dart test/pdf_integration_test.dart test/handout_export_test.dart test/studio_test.dart test/architecture_test.dart` — 61 passed, including the mandatory architecture test.
- Final `flutter analyze --no-pub` completed with seven existing info-level lints in unrelated Google Workspace/auth/local-service/logger files; no Smart Pen issues were reported. Windows and Web profile builds succeeded. Web was launched from a local server in headless Chrome with a temporary profile, and the profile and processes were removed after measurement.
- `flutter test --no-pub --platform chrome test/smart_pen_annotation_test.dart` still exits before loading the test suite (`Connection closed before test suite loaded`). The Chrome profile harness did execute the Web app, but it does not replace browser-runner interaction tests.
- Real teacher PDFs remain outside the agreed initial corpus. Their evaluation and reduction of dense-page Web extraction pauses are explicit release follow-ups.

## Final review follow-up — 2026-10-18

- The final review found that adding PDF ink after undo left Smart Pen and board actions redoable across pages, and replacing a PDF under a reused document ID could retain Smart Pen history from the previous bytes. Regression tests reproduce these cases; PDF ink now clears both current-document Smart Pen redo and current-board redo, while PDF source/byte replacement clears stale Smart Pen undo/redo history.
- Added gesture boundary coverage: an 18 logical-pixel touch movement remains a tap; 19 pixels rejects tap routing and uses the existing stroke path. A 600 ms stationary press is still recognized on release, matching Flutter's lack of a maximum TapGestureRecognizer duration. The 100 ms press timeout only governs `onTapDown`; Smart Snap classifies on `onTapUp`.
- Final affected command rerun after the fixes: `flutter test --no-pub test/smart_pen_index_test.dart test/smart_pen_gesture_test.dart test/smart_pen_annotation_test.dart test/pdf_integration_test.dart test/handout_export_test.dart test/studio_test.dart test/architecture_test.dart` — **67 passed**, including the architecture test. The run measured ready-index lookup p95 at 62 µs with 1,000 candidates and 1,000 queries.
- Final `flutter analyze --no-pub` — no Smart Pen issues; seven existing info lints remain in unrelated Workspace/auth/local-service/logger files.
