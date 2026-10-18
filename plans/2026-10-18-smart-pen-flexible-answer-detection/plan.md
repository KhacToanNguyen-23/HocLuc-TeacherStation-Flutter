# Plan: Flexible Smart Pen answer detection

- Date: 2026-10-18
- Mode: --hard
- Risk: normal - extends Flutter PDF text classification, adjacent-page linking, and annotation history; no auth, schema, or infrastructure changes
- Spec: `plans/smart-pen-flexible-answer-detection/spec.md`
- Status: Complete; Phases 01–04 implemented, verified, reviewed, and approved

## Goal

Improve the existing Smart Pen answer classifier to recognize attached labels, scale-spaced/formula choices, bare error-identification markers, and answer groups continuing onto the next page. Preserve conservative semantic filtering, visible-page-first indexing, current annotation persistence/save-toggle behavior, and atomic answer replacement/undo across all pages in a linked question.

## Scope Challenge

- **Exists?** Yes. `smart_pen_answer_index.dart` currently recognizes exact standalone A-D fragments, uses a small nearby-text distance, rejects components with fewer than two distinct labels, and assigns page-local ordinal group IDs. `PdfStage` indexes pages independently. Its debug overlay shows accepted bounds but not raw rejected fragments/reasons. Selection state and undo can work across pages only when candidates already share a group ID.
- **Minimum?** Expose conservative page-local marker candidates (including partial page-edge groups), link only high-confidence adjacent-page continuations under a document generation, and feed canonical group IDs into the existing selection/history pipeline. Add the missed layouts and failure explanations to generated-PDF tests and opt-in debug rendering.
- **Complexity?** Hard: classifier tolerance, cross-page matching, page scheduling, document identity, replacement, and undo/redo interact. Risk remains normal because the scope is local and reversible, and data model/persistence formats need not change.

## Spec Stories

- **P1 - Recognize flexible layouts:** attached marker prefixes, wide option spacing/formulas, vertical/two-column options, and bare error-identification markers.
- **P1 - Preserve semantic safety:** reject prose, headings, watermark fragments, duplicate or ambiguous marker groups.
- **P2 - Diagnose missed labels:** debug accepted/rejected fragments, bounds, and concise reasons without production PDF-text logging.
- **P1 - Link choices across adjacent pages:** stable shared group identity, cross-page selection replacement, atomic undo/redo.
- **P3 - Retain progressive indexing:** visible-page-first usability; linking becomes available as adjacent indexes become ready.

## Existing Architecture and Findings

- `frontend/lib/services/smart_pen_answer_index.dart` defines `SmartPenAnswerCandidate`, page-local extraction/grouping, page index, scheduler, and index store. It accepts an exact token pattern and derives group IDs as `answer-group-N` within each page.
- The nearby text and column checks need scale-aware handling because PDF extraction can expose a marker and formula as separate fragments with a wide gap.
- A component needs at least two distinct labels before candidates are retained. Incomplete A/B and C/D portions split at page boundaries can therefore disappear before any cross-page analysis.
- `frontend/lib/widgets/pdf_stage.dart` builds and queries one page's index. `SMART_PEN_DEBUG` currently paints accepted candidate boxes only.
- `frontend/lib/models/studio_state.dart` replaces selections by `groupId` and holds document-keyed Smart Pen history. Existing annotation tests exercise same-group state across pages when IDs are supplied, including undo/redo and saved/temporary lanes. The classifier/index must provide canonical stable IDs and the model should be verified for atomic multi-page mutation rather than replaced wholesale.
- Current progressive scheduling is visible-page-first and serial. Keep it; do not require a whole-PDF scan before a local candidate is usable.
- `pdfrx` stays as text/geometry provider. Existing save toggle keeps temporary circles outside persistence/export; classifier/linker work must not change it.

## Recommended Design

Keep extraction page-local and add an internal `SmartPenMarkerCandidate` layer that records normalized label, exact source fragment, marker sub-bounds (when possible), full-fragment bounds, line/column position, nearby option evidence, edge proximity, and confidence/rejection metadata. Parse a leading A-D marker prefix even when its option text is attached. If character-level geometry cannot isolate the prefix, use a conservative clipped prefix bound derived from fragment geometry rather than the entire answer text. Associate marker and option fragments with scale-aware row/column geometry and neighboring distinct markers; wide spacing is acceptable only when layout evidence supports the same choice block.

Retain credible partial clusters near page edges. A document-level linker consumes ready indexes for adjacent pages and proposes unions only for compatible edge clusters with complementary expected label order, page-edge proximity, matching column/layout evidence, and no new question heading between them. Uniqueness is required on both sides; ties, duplicate labels, missing continuity, and stale document generations remain unlinked. Keep local page hit testing, but resolve candidate group IDs through the linker's canonical document group map. Use stable IDs derived from document generation and group membership/anchor rather than page-local sequence number.

Feed the canonical group ID and existing marker bounds into the current annotation-selection API. Verify that replacement removes a prior circle on any linked page and that one operation captures every touched page's persisted and temporary state in one history entry. Avoid serialization changes: group metadata already exists on Smart Pen oval strokes. Document replacement invalidates indexes, links, and pending asynchronous results together.

Extend debug mode with distinct raw-fragment, accepted-candidate, and rejected-candidate views. Show short fragment text only in the explicit debug overlay and a compact reason code; never include fragment contents in production logs. Keep diagnostics optional to avoid normal rendering cost.

Use generated text-PDF fixtures reproducing the supplied cases: attached marker-plus-option text (for example, `A.` immediately followed by choice text), two-column and inline choices, large-gap formulas, bare markers under sentence spans, question/options divided across a page break, watermarks, ordinary prose, headings, duplicate labels, and deliberately ambiguous neighbors. Include rendered-coordinate taps so candidate recognition is tested separately from pointer transforms.

## Phases

1. [x] **Phase 01 - Marker extraction and flexible local grouping** (P1 layout support + semantic safety): add prefix-aware marker extraction with marker-level hit bounds, scale-aware option association, partial edge clusters, and labeled generated-PDF fixtures. Preserve existing supported layouts and fail-closed rules. See `phase-01-flexible-marker-classifier.md`.
2. [x] **Phase 02 - Adjacent-page group linker and canonical selection IDs** (P1 cross-page story): link compatible edge clusters across adjacent ready pages, guard by document generation, assign canonical stable group IDs, and connect selection replacement to the existing multi-page annotation state. See `phase-02-cross-page-linker-and-state.md`.
3. [x] **Phase 03 - Debug extraction diagnostics and progressive integration** (P2 diagnostics + P3 indexing story): expose accepted/rejected fragment geometry and reason codes behind `SMART_PEN_DEBUG`, and make newly available adjacent indexes refresh links while keeping current-page use independent. See `phase-03-debug-and-progressive-integration.md`.
4. [x] **Phase 04 - Acceptance, history, and regression validation** (all stories): validate corpus precision/recall per layout, cross-page replacement/undo/redo and stale-generation behavior, coordinate hit testing, persistence/export boundaries, and existing Smart Pen behavior. See `phase-04-acceptance-validation.md`.

## Dependencies

- Phase 01 defines marker candidate and partial-cluster APIs needed by Phase 02.
- Phase 02 depends on candidate IDs that do not collide across pages and must validate existing state history semantics before changing state code.
- Phase 03 integrates linker refresh with indexing readiness; candidate-local UI use must remain functional before adjacent indexing finishes.
- Phase 04 depends on Phases 01-03.
- Do not add OCR, manual-region authoring, a new PDF parser, or a full-document eager scan in this scope.

## Risks and Mitigations

- **False positives from relaxed matching:** require multiple independent signals (line/column start, option text/neighbor geometry, group pattern, and context); reject ambiguous clusters; measure precision and recall per fixture layout.
- **Bounding-box mismatch for attached marker text:** prefer character/sub-fragment geometry; if unavailable, constrain the fallback prefix box and test taps at its edges at several zoom levels.
- **Wide formula options mistaken for unrelated columns:** infer row/column structures from the whole page and nearby markers; do not simply increase a fixed distance threshold.
- **Wrong page-boundary union:** require adjacency, edge proximity, compatible arrangement, ordered complementary labels, no new-question evidence, and a unique mutual match; leave weak matches separate.
- **Unstable IDs as indexes arrive:** define canonical group identity from document generation and stable page/geometry anchors; keep selection state keyed to canonical IDs and test relinking without duplicate circles.
- **Undo changes multiple pages inconsistently:** validate existing grouped history behavior first; store the complete before/after selection group state in one entry and test persisted and temporary circles together.
- **Stale index/link completion:** invalidate on PDF byte/source generation change and discard stale extraction/link results; test navigation, document replacement, and neighboring-page completion races.
- **Debug mode leaks PDF text:** render diagnostics only behind the explicit compile-time flag and prohibit text-bearing production logs.
- **Synthetic corpus may not represent all PDFs:** limit claims to corpus scope, retain per-layout outcomes, and collect representative real PDFs as later follow-up.

## Verification Plan (planned; not run during planning)

From `frontend/`, extend the existing test files and add focused suites only where the current coverage cannot assert behavior:

```powershell
flutter test test/smart_pen_index_test.dart
flutter test test/smart_pen_annotation_test.dart test/smart_pen_gesture_test.dart
flutter test test/pdf_integration_test.dart test/handout_export_test.dart
flutter test test/architecture_test.dart
flutter analyze lib/services/smart_pen_answer_index.dart lib/models/studio_state.dart lib/widgets/pdf_stage.dart
```

The index suite should use generated-PDF extraction and labeled candidates for positives and negatives; report TP/FP/FN and precision/recall by layout. Annotation tests should select across pages in both directions, verify only one circle per canonical group, and verify undo/redo snapshots each page atomically for persisted and temporary annotations. Integration coverage should assert no persistence/export changes and no regression to ordinary pen taps/drags. Do not run tests during plan creation.

## Implementation Constraints

- Keep `pdfrx`, canonical page coordinates, current hit-test tolerance policy, tap routing, freehand pen, save toggle, and export/persistence boundaries intact.
- Preserve visible-page-first, one-page-at-a-time indexing; candidate use on the current page must not await the adjacent page.
- Do not group by label sequence alone. Ambiguity must fail closed.
- Avoid lesson/PDF serialization changes unless a concrete compatibility requirement is discovered and separately reviewed.
- Do not emit PDF text in normal logs.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-18
**Phase in progress:** complete
**Status:** All four phases implemented; final acceptance and architecture suites pass; final code review found no remaining actionable findings; user approved completion.

### Decisions made this session
- Split attached marker prefixes into marker-only hit bounds and residual option text using a bounded proportional prefix estimate because pdfrx supplies fragment bounds rather than per-character glyph boxes here.
- Make option association scale-aware for extracted formula text, treat each A-D token as a column boundary, and require prior answer context when a marker follows prose. Preserve the existing inline-choice classifier and reject bare A-D instruction sequences.
- Cap attached-marker hit bounds to 1.5 median glyph heights even when the extracted text fragment spans a long option.
- Expose incomplete page-edge groups separately from selectable candidates; the new regression verifies a C/D bottom-edge cluster is linker-visible but cannot snap on its own.
- Add extracted synthetic-PDF cases for attached labels and formula options spanning wide horizontal gaps; the formula fixture reproduces a 36-point row spacing and passes with all four labels in one group.
- Focused verification: `smart_pen_index_test.dart` 34 passed, 0 failed; `dart analyze` on the classifier and test reported no issues. Existing 5-case corpus smoke metrics: precision 100%, recall 100%; 1,000-candidate lookup p95 53 µs.
- Preserve classifier candidate ordering because existing two-column tests and callers expect column grouping order.
- Link only ordered A/B bottom and C/D top pairs; edge clusters split across two horizontal columns now form linker-visible partial groups. Heading evidence groups extracted word fragments into visual rows and rejects both split `Question 21` and number-first question stems.
- Cross-page saved and temporary selection edits now snapshot every affected page in one undo entry. Progressive relinking migrates existing group IDs and selection metadata without marking a clean lesson dirty.
- Phase 02 checks: horizontal edge-link, split-heading, ambiguity, generation scope, readiness order, and incremental refresh tests pass; canonical replacement and migration preserve selection and history.
- Phase 03 checks: compile-time `SMART_PEN_DEBUG` overlay distinguishes raw, accepted, partial, rejected, and linked/unlinked candidates; debug-enabled PDF tap widget smoke passes; analyzer clean.
- Phase 04 corpus v3: 616 positive labels and 100 negative labels; TP=616, FP=0, FN=0; 100% precision and recall overall and for vertical, two-column, attached, inline, wide-formula, and error-identification layouts. Ready-index lookup p95=416 µs for 1,000 candidates (below the 1 ms target).
- Final regression command passed 125 tests across Smart Pen index/annotation/gesture, PDF integration, handout export, and architecture suites. Analyzer reported no issues. Debug-mode PDF tap smoke and normal-mode absence of the debug overlay both pass. Regression tests confirm relinking keeps the latest pre-index choice, preserves saved/session-only boundaries, and undo/redo restores the prior choice atomically. Final code review found no remaining actionable findings.

### Next immediate action
Complete. The debug overlay can be enabled with `flutter run --dart-define=SMART_PEN_DEBUG=true`.
