# Spec: Smart Pen answer snap

**Date:** 2026-10-17
**Status:** Draft

---

## Problem Statement

Teachers already use the pen to mark PDF exam papers, but circling answer labels requires a separate deliberate gesture and can leave unwanted tap dots. Smart Pen should recognize a quick tap on a verified multiple-choice label and create a hand-drawn oval, while preserving normal freehand drawing everywhere else.

---

## User Stories

- **[P1]** As a teacher, I want to toggle answer snapping while using the existing pen so that a quick tap on an answer label circles it without changing tools.
  Accepted when: Smart Snap can be enabled and disabled independently of the pen color/width controls, and disabled mode preserves current pen tap and drag behavior.

- **[P1]** As a teacher, I want taps to snap only to labels identified as multiple-choice answers so that ordinary letters in question text are not circled.
  Accepted when: a candidate must pass both a spatial hit test and semantic answer-group verification; fixtures cover `A.` as an answer and `A`/`A.` in prose, headings, and section labels.

- **[P1]** As a teacher, I want freehand drags to remain natural pen strokes so that Smart Snap does not interfere with annotation.
  Accepted when: pointer movement beyond the tap threshold creates the existing ink stroke path and does not create an answer oval.

- **[P1]** As a teacher, I want the visible PDF page indexed first and nearby pages prepared progressively so that answer taps do not trigger text extraction at click time.
  Accepted when: text extraction and semantic candidate construction start asynchronously after the PDF is ready; the visible page is prioritized and the full document is not a prerequisite for using Smart Snap on it.

- **[P2]** As a teacher, I want answer circles to be removable using the existing undo flow and by tapping the same label again.
  Accepted when: adding/removing an answer oval is one undoable annotation operation and tapping its label again removes that oval.

- **[P2]** As a teacher, I want choosing another option in the same question to move the circle to that option so that only my latest selection remains marked for that question.
  Accepted when: selecting a different verified answer label in the same question removes the previous answer oval and adds one at the newly selected label.

- **[P2]** As a teacher, I want the oval to look like pen ink and animate into place so that it matches the rest of my annotations.
  Accepted when: the generated oval has small deterministic hand-drawn irregularity and the draw animation completes without altering its saved geometry.

- **[P2]** As a teacher, I want to choose whether new Smart Pen answer circles are saved so that I can mark a PDF temporarily or keep the marks in my lesson and exported PDF.
  Accepted when: a save-circles toggle sits beside Smart Snap; enabled mode preserves the current persistence and export behavior; disabled mode keeps new circles visible for the current session but excludes them from saved lesson data and PDF export.

- **[P3]** OCR support for image-only scanned PDFs is out of scope for the MVP; ordinary pen behavior remains available on those pages.

---

## Functional Requirements

1. FR-01: Smart Snap is an optional mode associated with the existing pen tool and can be toggled from the drawing toolbar.
2. FR-02: On pointer up, classify a gesture as a tap only when movement and duration remain within the existing pen tap-recognition thresholds; inspect and document those thresholds during implementation, and keep drags in the existing stroke pipeline.
3. FR-03: Build answer-label candidates from `pdfrx` page text and character rectangles. Store candidate bounds in canonical page coordinates so zoom and scrolling do not require re-indexing.
4. FR-04: Accept A-D labels at the start of option lines when grouped with at least one other distinct A-D label in a nearby multiple-choice block. Also accept bare A-D error-identification markers positioned below a nearby numbered sentence, when the marker row forms a verified A-D group. A standalone regex match is insufficient; ambiguous layout/context must be rejected rather than auto-circled.
5. FR-05: A tap query first finds spatial candidates within a viewport-scaled 8–12 logical-pixel tolerance, then chooses only one unambiguous semantically verified answer label. If expanded hit regions overlap or yield multiple eligible labels, reject the smart snap. Blank-space and non-answer taps never create a smart oval; their ordinary pen behavior follows the current pen behavior.
6. FR-06: Use a per-page candidate index. Begin with a compact candidate list or coarse spatial buckets; adopt an R-tree only if measurements show the simple index misses the latency target.
7. FR-07: Indexing must be invalidated when the active PDF bytes/document change. Page rotation, zoom, and scroll must transform the tap into the same canonical coordinates as indexed bounds.
8. FR-08: When text extraction returns no usable text, Smart Snap must not claim an answer hit; ordinary pen drawing remains available. Do not run OCR in the MVP.
9. FR-09: A recognized tap creates one hand-drawn oval annotation and suppresses the ordinary tap dot. Freehand strokes continue to use the current ink pipeline.
10. FR-10: Tapping the same selected label removes its oval. Tapping a different verified label in the same question removes that question's previous oval and creates one on the new label.
11. FR-11: While a page index is being built, queue up to 32 quick taps with their page-coordinate positions and resolve them in order when that page's index completes. Keep taps attached to their captured page if the teacher navigates away; cancel queued taps if Smart Snap is turned off or the source document changes. Taps beyond capacity follow ordinary pen behavior. Freehand drawing remains available while indexing.
12. FR-12: Provide a separate save-answer-circles toggle beside Smart Snap. Default it to enabled so existing behavior is preserved. The setting applies when each new oval is created: enabled ovals participate in lesson persistence and PDF export; disabled ovals remain visible and undoable during the current session but are excluded from lesson persistence and PDF export. Changing the toggle must not remove or alter previously saved circles. Turning saving back on affects circles created afterward; it does not retroactively persist temporary circles.

---

## Non-Functional Requirements

- Performance: p95 spatial lookup below 1 ms after the page index is ready, measured with at least 1,000 candidate labels in a synthetic page index.
- Performance: indexing is asynchronous and must not block PDF opening on a full-document scan. UI frame impact and per-page indexing latency must be profiled on the target Windows desktop and web targets before release.
- Correctness: provisional semantic classification targets are at least 99% precision and 90% recall on a labeled fixture set containing answer groups, prose letters, section headings, and common two-column layouts; prioritize precision if the targets trade off.
- Coordinate stability: hit testing must pass at 50%, 100%, and 200% zoom, and with rotated pages where supported by the viewer.
- Availability: extraction failures or textless pages must fall back without disabling the ordinary pen.

---

## Success Criteria

- [ ] Tap lookup p95 is < 1 ms with a ready index containing 1,000 answer-label candidates.
- [ ] Semantic candidate classification reaches >= 99% precision and >= 90% recall on the fixture corpus agreed during planning, prioritizing precision if the targets trade off.
- [ ] In a 100-page text PDF, opening the document does not wait for all pages to be indexed; the visible page is indexed first and other pages are prepared progressively.
- [ ] At 50%, 100%, and 200% zoom, tapping inside a verified label's expanded hit area selects the same candidate; a tap outside all expanded bounds selects none.
- [ ] A drag produces no smart oval; a tap on blank space or a non-answer token creates no smart oval and follows the current pen tap behavior.
- [ ] A tap queued during page indexing is resolved against the captured page coordinates after indexing completes, including after navigating to another page; it is discarded if Smart Snap is disabled or the PDF changes first.
- [ ] The queue preserves at most 32 taps in order; additional taps use ordinary pen behavior.
- [ ] With save-answer-circles enabled, a new oval survives lesson save/reopen and appears in PDF export, matching current behavior.
- [ ] With save-answer-circles disabled, a new oval remains visible and undoable until the PDF/session closes, but is absent from serialized lesson data and PDF export.
- [ ] Changing the toggle does not remove previously saved ovals; temporary ovals created while saving is off are not persisted retroactively when saving is turned on.

---

## Out of Scope

- OCR for scanned/image-only PDF pages in the initial implementation.
- Automatic answer correctness grading or choosing which answer is pedagogically correct.
- Changing the existing freehand pen rendering pipeline.
- New PDF parsing dependencies unless profiling demonstrates `pdfrx` extraction is insufficient.

---

## Assumptions

- The current PDF viewer (`pdfrx`) remains the renderer and source of text geometry.
- A page-local canonical-coordinate index can be queried after transforming pointer coordinates from the displayed page.
- Current-page-first progressive indexing is the user-selected policy.
- Scanned PDFs use ordinary pen behavior; OCR is out of scope for the MVP.
- Quick taps during indexing are queued and resolved after the index is ready; the queue is canceled if Smart Snap is disabled or the PDF changes.
- The pending tap queue is capped at 32; taps over capacity use ordinary pen behavior. Queued taps remain bound to their original page through page navigation.
- Index one page at a time; start with the visible page, reprioritize the newly visible page when navigation occurs, then index remaining nearby pages in increasing distance.
- Selecting another answer in a recognized question replaces its existing circle; tapping the selected label again toggles that circle off.
- A queued tap that is not an answer invokes the current ordinary pen tap behavior and never creates a smart oval.
- Save-answer-circles defaults to enabled; the toggle applies only to circles created after the setting changes.
- Temporarily displayed circles are session-local; closing or replacing the PDF discards them, while existing persisted PDF annotations remain intact.
- Supported answer layouts include ordinary option lines and bare A-D error-identification markers below their numbered sentence; bare markers without that nearby numbered-sentence context are rejected.
- Initial classifier evaluation uses synthetic PDF fixtures for vertical and two-column answer layouts, prose/headings containing A-D distractors, and ambiguous/unsupported groupings; real PDFs can be added after the initial implementation.
