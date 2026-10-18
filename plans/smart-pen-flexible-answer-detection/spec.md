# Spec: Flexible Smart Pen answer detection

**Date:** 2026-10-18
**Status:** Implemented and approved

---

## Problem Statement

Smart Pen works for common multiple-choice layouts but misses answer labels in some real PDFs. The reported examples include labels attached to option text (`A attached to option text`), answer choices separated from the label by wide formula/layout gaps, bare A-D markers under error-identification sentences, and answer groups split by a page break. The classifier must recognize these supported forms while continuing to reject ordinary letters in prose and unrelated section labels. Selecting an option on either side of a page break must replace the prior selection for that same question.

## User Stories

- **[P1]** As a teacher, I want Smart Pen to recognize answer labels attached to option text or separated by unusual layout gaps so that I can circle choices in more PDF formats.
  Accepted when: generated text-PDF fixtures cover attached labels, wide formula layouts, vertical and two-column options, and bare error-identification markers; all intended labels in these supported fixtures are hit-testable.

- **[P1]** As a teacher, I want Smart Pen to keep rejecting A-D letters that are prose, headings, or unrelated page content so that flexible recognition does not create accidental circles.
  Accepted when: labeled negative fixtures cover ordinary prose, section headings, watermark fragments, duplicate/ambiguous labels, and nearby unrelated text; no negative candidate is accepted, and uncertain cases fail closed.

- **[P2]** As a teacher, I want to diagnose why an answer label was missed so that I can distinguish text extraction, classification, and hit-testing problems.
  Accepted when: opt-in debug mode displays extracted fragment text/bounds, candidate acceptance state, and a concise rejection reason; normal production logs contain no extracted PDF text.

- **[P1]** As a teacher, I want choices split across adjacent pages to belong to the same question so that selecting a new option replaces the earlier circle.
  Accepted when: a fixture with a question's choices split across two adjacent pages receives one stable group ID, selecting an option on either page leaves only one circle for that question, and undo/redo restores/removes the multi-page change atomically.

- **[P3]** As a teacher, I want visible-page-first progressive indexing to remain available so that flexible recognition does not require waiting for a full-document scan.
  Accepted when: the current visible page can be indexed and used before the full document; cross-page linking is performed only as the adjacent page becomes indexed.

## Functional Requirements

1. **FR-01 Marker candidates:** Separate text-fragment marker extraction from answer-group classification. Recognize a supported leading A-D marker prefix, including punctuation/parenthesis variants and a marker attached to following option text. Retain marker-specific hit bounds where extraction permits; otherwise use a bounded prefix region from the fragment.
2. **FR-02 Layout association:** Associate marker candidates with option text using scale-aware line, column, row, and neighboring-marker geometry. Do not rely on a single fixed maximum gap. Support wide formula fragments and error-identification answer rows without associating unrelated prose.
3. **FR-03 Conservative grouping:** Preserve vertical, inline, two-column, and error-identification layouts. Require contextual evidence of an answer block. Reject duplicated labels, ordinary prose, section headings, watermark-only fragments, ambiguous clusters, and isolated markers without question context.
4. **FR-04 Partial edge groups:** Preserve locally credible partial answer groups at the beginning/end of a page so they can be considered for cross-page linking; do not treat a partial group as a complete local question solely because it contains A-D-like labels.
5. **FR-05 Cross-page linking:** Link groups only across adjacent pages and only with continuity evidence such as complementary ordered labels, proximity to the respective page edges, compatible geometry/layout, and no intervening new question heading. Labels alone are insufficient. Ambiguous links remain separate.
6. **FR-06 Stable identity and selection:** Assign stable document-level group IDs to linked candidates. Selection replacement/toggle behavior must operate on the canonical group across pages. A single user selection affecting more than one page is one atomic undo/redo action.
7. **FR-07 Progressive indexing:** Keep current-page-first, one-page-at-a-time indexing. A visible page's local candidates remain usable without waiting for a full-document scan. Re-run or finalize linking when an adjacent page index becomes ready, without allowing stale document generations to mutate current state.
8. **FR-08 Debug diagnostics:** In `SMART_PEN_DEBUG` mode, show extracted fragments and bounds, accepted/rejected marker/group status, and compact rejection/linking reasons. Do not emit PDF text to production logs.
9. **FR-09 Safe fallback:** If extraction fails or semantic/group confidence is insufficient, do not auto-circle and preserve normal pen behavior. OCR and manual answer-region authoring are excluded.

## Non-Functional Requirements

- **Precision:** Reach at least 99% precision on the agreed labeled synthetic corpus. If precision and recall conflict, prefer precision and fail closed.
- **Recall:** Target at least 95% recall on supported labeled layouts in the corpus; report raw counts and per-layout results so an aggregate cannot hide a missed layout.
- **Scoring unit:** Score each intended answer marker as one positive instance and each labeled distractor marker/fragment as one negative instance. The versioned corpus must contain at least 100 positive and 100 negative instances; report TP/FP/FN overall and per layout/category.
- **Latency:** Ready-page candidate lookup remains below 1 ms p95 with at least 1,000 candidates. Index extraction and linking remain asynchronous and do not block drawing.
- **Determinism:** Identical PDF text geometry and indexing order produce identical candidate groups and stable IDs for the same document generation.
- **Compatibility:** Existing pen drag behavior, Smart Snap tap behavior for already supported layouts, save-answer-circle preference, annotation persistence/export, and page coordinate transforms remain unchanged except where flexible candidates are admitted.

## Success Criteria

- [x] All intended markers in synthetic fixtures for attached-prefix, wide-gap formula, vertical, two-column, error-identification, and adjacent-page layouts are hit-testable.
- [x] The fixture classifier reaches >=99% precision and targets >=95% recall; corpus v3 reports TP=616, FP=0, FN=0 across the six scored layouts (100% precision and recall).
- [x] Prose, heading, watermark, duplicate-label, and ambiguous-layout negative fixtures produce no accepted answer candidate; 100 labeled negatives yielded FP=0.
- [x] Cross-page groups have stable canonical IDs; selecting across the page boundary replaces the old option and undo/redo restores the multi-page state atomically.
- [x] Current visible page becomes usable before all pages are indexed; index/link work does not block pointer handling or drawing.
- [x] Debug diagnostics identify extraction bounds and acceptance/rejection reasons, and production logging contains no PDF text.
- [x] Existing Smart Pen gesture, persistence, and export acceptance tests continue to pass (125 acceptance and architecture tests).

## Out of Scope

- OCR for scanned/image-only PDFs.
- Manual authoring of answer regions or question groups.
- Automatic answer correctness grading.
- Full-document eager indexing before the visible page becomes usable.
- Replacing the existing PDF text extraction or rendering library unless fixture evidence proves it cannot provide needed geometry.

## Assumptions

- `pdfrx` remains the PDF renderer/text-geometry provider and existing canonical page coordinates remain authoritative.
- The current answer-index API is page-local; the feature will introduce candidate/partial-group exposure and a document-level adjacent-page linker.
- Cross-page grouping is limited to adjacent pages. The user explicitly wants choices on both pages to share one question group so a new selection replaces the old one.
- Ambiguous cross-page matches are rejected rather than guessed; proximity or A-D label order alone is insufficient.
- If a teacher selects an answer before the neighboring page is indexed, retain the selection and migrate it to the canonical group when the link is established. Preserve that reconciliation through undo and redo.
- Initial evaluation uses a generated text-PDF corpus with at least 100 intended answer markers and 100 labeled distractors, including synthetic cases based on the provided screenshots. Target at least 99% precision and 95% recall, reporting per-layout counts; original PDFs can be added later.
- Existing visible-page-first progressive indexing policy is retained.
