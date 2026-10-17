# Plan: Smart Pen answer snap

- Date: 2026-10-17
- Mode: --hard
- Risk: normal — multi-file Flutter PDF interaction and annotation-state change; no auth, backend, schema, or infrastructure changes
- Spec: `plans/smart-pen-answer-snap/spec.md`
- Status: Phase 04 validation complete on the generated corpus; dense-page Web extraction latency and representative teacher-PDF evaluation remain release follow-ups

## Goal

Add an optional Smart Snap mode to the existing PDF pen workflow. Index the visible PDF page first and nearby pages progressively, recognize only high-confidence A–D option labels, and turn quick taps on verified labels into undoable hand-drawn ovals. Preserve the existing pen behavior for drags, blank/non-answer taps, textless pages, and disabled mode. Use synthetic PDF fixtures for initial classifier evaluation; OCR and real-PDF corpus expansion remain out of scope.

## Spec Stories

- **P1 — Toggle answer snapping:** enable/disable Smart Snap alongside existing pen controls without coupling it to color/width.
- **P1 — Avoid false positives:** require spatial hit plus conservative semantic membership in a nearby answer group; reject prose/headings/ambiguous labels.
- **P1 — Preserve freehand drags:** movement beyond tap thresholds uses the existing stroke path.
- **P1 — Progressive page indexing:** asynchronously index visible page first and nearby pages after; never require a whole-document scan before use.
- **P2 — Undo and toggle:** adding/removing an oval is one undoable operation; tapping the same answer removes it.
- **P2 — Replace selection in a question:** selecting another verified answer in that group moves the circle.
- **P2 — Natural animated oval:** deterministic hand-drawn variation with animation that does not mutate saved geometry.
- **P3 — Scanned pages:** no OCR; ordinary pen remains available.

## Scope and Design

Keep the feature in the existing `PdfStage`/`StrokeCanvas` and Studio annotation model. Build a small, testable page-text classifier/index service around `pdfrx` character geometry. Wait for the page/document to be loaded before extraction; construct visual lines and columns from token/character boxes, then admit only A–D labels at option-line starts that form a nearby answer group. Prefer a compact candidate list or coarse buckets and benchmark it before considering an R-tree. Store candidate geometry in canonical page coordinates and transform pointer locations through the viewer's page transform. Give each PDF document/index generation an identity so stale asynchronous work cannot populate a replaced document's index.

The pen gesture layer must distinguish taps from drags before committing a tap dot. While a page index is pending, retain ordered taps as canonical page coordinates with the source page/document generation; replay after readiness only if Smart Snap remains enabled and the source is unchanged. Recognized answers create a serializable `BoardStroke`-compatible oval annotation in the existing per-page PDF annotation flow so rendering/export continue to work. Integrate PDF annotation changes with the existing undo history, which currently primarily tracks board strokes. Add the Smart Snap control to both layouts of `studio_drawing_toolbar.dart`.

Synthetic fixtures should exercise vertical and two-column option layouts, distractors such as `A`/`A.` in prose, section headings and labels, ambiguous groups, empty text, and a page/index with at least 1,000 candidates for lookup timing. Fixtures are the agreed initial corpus; document limitations and leave thresholds tunable from measured results.

## Phases

1. [x] **Phase 01 — Classifier, page index, and synthetic corpus** (covers P1 semantic safety and progressive-index foundation): define candidate/group/index models, canonical geometry, conservative line/group reconstruction, document-generation invalidation, and deterministic synthetic PDF/index fixtures. See `phase-01-index-and-classifier.md`.
2. [x] **Phase 02 — Pen gesture routing and progressive indexing** (covers P1 toggle, tap-vs-drag, and visible-page-first use; P3 fallback): wire current-page-first asynchronous indexing and bounded nearby-page work into the PDF viewer; add Smart Snap toggle; defer tap-dot commitment, queue/cancel taps as specified, and preserve freehand/ordinary tap behavior. See `phase-02-pen-and-indexing.md`.
3. [x] **Phase 03 — Oval annotations, replacement, and undo** (covers P2 toggle/removal, question replacement, and natural animation): create deterministic oval geometry, render/animate it, persist it through existing PDF annotation/export paths, and include add/remove/replace as coherent undoable operations. See `phase-03-oval-annotation-undo.md`.
4. [x] **Phase 04 — Integration, coordinate, and performance validation** (automated acceptance and synthetic Windows/Web profiling complete; dense-page Web extraction latency is documented): exercise full interactions across zoom/rotation, pending-index races, disabled/textless modes, fixture accuracy, and export/undo. See `phase-04-validation.md`.

## Dependencies

- Phase 02 depends on Phase 01's stable page-index API and classifier output.
- Phase 03 can develop alongside Phase 02 after the annotation representation is agreed, but final gesture integration depends on both.
- Phase 04 depends on Phases 01–03.
- Do not add OCR or a PDF parsing package unless `pdfrx` geometry is demonstrated insufficient by a failing acceptance criterion and the scope is revisited.

## Risks and Mitigations

- **Synthetic classifier results could overfit generated fixtures.** Keep a versioned expected-label manifest and fixed generator seeds/layout variants; report sample counts and limit claims to that corpus.
- **Tap classification and overlapping hit regions could produce inconsistent selections.** Reuse and document the existing pen tap thresholds; reject ambiguous spatial matches and cover threshold/overlap boundaries in tests.
- **Queued intent could grow unbounded or become detached from its page.** Cap pending taps at 32 and route overflow through ordinary pen behavior; retain each queued tap's original page and PDF generation, canceling only on Smart Snap disable or document replacement.
- **Text extraction coordinate conventions or availability differ by platform/version.** Verify the current `pdfrx` API and page coordinate transforms in a small adapter and fixture tests; keep extraction isolated from the classifier.
- **Visual grouping can misclassify prose or multi-column layouts.** Require line-start labels plus nearby distinct A–D labels; prefer rejecting uncertain blocks. Evaluate precision and recall on labeled synthetic fixtures, prioritizing precision.
- **Stale extraction completes after a PDF replacement or page lifecycle change.** Use document-generation identity, cancellation/ignore stale results, and test replacement while indexing and queued taps exist.
- **Tap queues can replay at the wrong page/coordinates or after a user disables the feature.** Capture canonical coordinates and page/generation per tap, preserve ordering, and discard on toggle-off or source change.
- **Gesture recognizer changes can introduce dots or swallow drags.** Keep existing stroke construction as the drag path and add gesture tests for threshold boundaries, tap-dot behavior, and drag suppression.
- **Page transforms can drift under zoom, scroll, or rotation.** Index in canonical page coordinates; test at 50%, 100%, 200% and rotated pages where viewer support permits.
- **PDF annotations and board undo use different state paths.** Inspect and unify or extend history deliberately so oval add/remove/replacement each undo atomically without regressing board history or export.
- **Animation could alter persisted geometry or make export differ from screen.** Use deterministic saved points and animate only the visible path reveal; export the final stable geometry.
- **Synthetic fixtures may not represent real teacher PDFs.** Make the initial accuracy claim explicitly fixture-scoped and record real-PDF evaluation as follow-up before broadening supported layouts.

## Verification Plan (planned; not run during planning)

Add focused Flutter tests for the index/classifier, Smart Snap control, gesture router, page-index queue, annotation history, and PDF overlay/export. Run the synthetic corpus against labeled expected candidates and distractors; measure p95 lookup for at least 1,000 labels after index readiness. Profile asynchronous indexing and frame impact on Windows desktop and web before release. Verify zoom levels and page rotation where supported.

Implementation verification commands (from `frontend/`):

```powershell
flutter test test/smart_pen_index_test.dart test/smart_pen_gesture_test.dart test/smart_pen_annotation_test.dart
flutter test test/pdf_integration_test.dart test/handout_export_test.dart
flutter test test/architecture_test.dart
```

The named Smart Pen test files are planned new files. Run the broader relevant PDF/studio tests if the targeted changes expose related coverage. No tests are run as part of plan creation.

## User Decisions

- Prioritize the visible page, then index nearby pages progressively.
- Do not OCR image-only scanned pages in the MVP; keep ordinary pen behavior available.
- Queue taps during indexing and resolve them after readiness, in order; cancel on Smart Snap disable or PDF replacement.
- Replace the existing circle when another answer in the same question is selected; tapping the selected label toggles its circle off.
- Prefer precision: only line-start A–D labels in a nearby answer group are eligible; uncertain labels do not snap.
- Use a synthetic fixture corpus first, including vertical/two-column layouts and prose/heading distractors; add real PDFs later.
- Cap queued taps at 32; taps over capacity use ordinary pen behavior. Keep queued taps attached to their captured page through page navigation; cancel on Smart Snap disable or PDF replacement.
- Index one page at a time, reprioritizing the newly visible page and then processing nearby pages in increasing distance.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-18 01:35
**Phase in progress:** phase-04-validation
**Status:** Phases 01–04 implementation and validation complete; final review findings are fixed and generated-corpus/platform limits are documented.

### Decisions made this session
- The pdfrx 2.6.5 adapter waits for `ensureLoaded()`, uses the latest page instance, and maps PDF bottom-left rectangles to top-left canonical page points.
- The classifier accepts exact A–D tokens at visual column starts only when a nearby unambiguous group has distinct labels; overlapping spatial matches fail closed.
- The versioned fixture manifest covers vertical and two-column groups, prose/heading distractors, ambiguous clusters, and textless pages; actual generated-PDF extraction tests cover vertical and two-column layouts.
- Phase 01's initial ready-index benchmark measured p95 45 microseconds; the final Phase 04 rerun measured 64 microseconds across 1,000 candidates/lookups. Final suite and analyzer results are recorded in `phase-04-validation.md`.
- Phase 02 adds an ephemeral Smart Snap toggle, PDF visible-page-first serial index scheduling, a bounded 32-tap page/generation queue, and tap-versus-drag routing. Touch tap slop is 18 logical pixels inclusive; precise-pointer slop is 1 logical pixel; Flutter's tap recognizer has no maximum press duration. Boundary and long-press behavior is covered by gesture tests.
- Review found queued old-page neighbors could delay the newly visible page's neighbors; a regression reproduced it and now passes with the visible page and closest neighbors moved to the front.
- Final code review found and fixed two history issues: PDF ink now clears redo entries for its page, and replacing/updating PDF bytes clears stale Smart Pen undo/redo history. Regression tests reproduced both before the fixes and pass afterward.

### Final follow-up
Evaluate representative teacher PDFs and lower the Web extraction pause for dense text pages before broadening release claims. This remains follow-up work outside the agreed synthetic initial corpus.
