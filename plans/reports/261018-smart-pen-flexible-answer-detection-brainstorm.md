# Brainstorm: Flexible Smart Pen answer detection

**Date:** 2026-10-18

## Ideas Explored

- **Only loosen the label regex:** quick to implement, but it can capture ordinary A–D prose and does not fix cross-page grouping or large geometry gaps.
- **Make marker-to-option geometry adaptive:** support labels attached to text and formula options using local row/column evidence instead of a single strict gap. This is the best fit for the screenshots while keeping semantic filtering.
- **Link partial question groups across adjacent pages:** the screenshots show options split by page breaks. Page-local indexes cannot currently associate A/B on one page with C/D on the next, so document-level group IDs and atomic cross-page undo are needed.
- **Add raw-fragment diagnostics:** the current debug overlay shows only accepted candidate boxes. Displaying extracted fragment bounds and rejection reasons will separate PDF extraction problems from classifier and hit-test problems.
- **Manual regions or OCR:** useful fallbacks for unsupported layouts, but broader and more expensive; OCR remains out of scope for the first improvement.

## User's Direction

The user prefers more flexible automatic recognition. For questions split across pages, labels A–D must remain in one question group so selecting a new option replaces the prior selection.

## Open Questions

- Validate the precision/recall targets against the fixture corpus during planning.
- Original PDFs for these screenshots were not present in the workspace; begin with synthetic text-PDF fixtures reproducing the shown layouts.

## Risks

- More permissive geometry can mistake prose letters or section headings for answer labels. Require multiple contextual signals and fail closed on ambiguity.
- Cross-page pairing based only on complementary A–D labels can join adjacent questions incorrectly. Require page-edge proximity and question-continuity evidence.
- A cross-page answer group affects annotations on multiple pages. Undo/redo and replacement must update all affected pages atomically without changing persistence rules.
