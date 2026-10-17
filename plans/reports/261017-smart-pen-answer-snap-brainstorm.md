# Brainstorm: Smart Pen answer snap pre-indexing

**Date:** 2026-10-17

## Ideas Explored

- **Index every page immediately:** Gives the most predictable first tap after preparation, but delays PDF readiness and spends work on pages a teacher may never visit.
- **Current page first, then nearby pages:** Prepare the visible page as soon as it is ready, then scan adjacent pages asynchronously. The user chose this to balance first-use latency and long-document cost.
- **Lazy index on page visit or first tap:** Reduces startup work, but can make the first Smart Pen tap wait for text extraction and semantic grouping.
- **Reuse `pdfrx` text extraction:** The app uses `pdfrx`; `PdfPage.loadText()` exposes full text, fragments, and per-character rectangles in PDF page coordinates. The existing SVO interaction already calls it on demand. Build answer candidates from those bounds rather than adding another PDF parser.
- **Candidate list versus a spatial tree:** Keep only semantically accepted answer labels in a page-local index. Start with a compact list or coarse grid and measure; an R-tree may be unnecessary when each page has relatively few answer labels.
- **Text PDFs versus scanned pages:** Text extraction cannot identify words in image-only scans. The user chose to keep ordinary pen behavior on scanned pages for the first version; OCR would add substantial runtime, memory, and accuracy complexity.

## User's Direction

The user wants Smart Pen to remain a mode of the existing pen tool and emphasized that background pre-indexing is the key design question. They chose current-page-first indexing followed by nearby pages, no OCR for scanned pages in the MVP, queued taps while the current page is indexing, and replacement of a prior answer circle when another option in the same question is chosen. They also chose a conservative semantic filter: only A-D labels at the start of option lines in a nearby answer group are eligible; uncertain labels must not auto-snap.

## Open Questions

- What representative labeled PDF fixture corpus should determine classification precision/recall, including two-column layouts and ambiguous A-D labels?

## Risks

- PDF reading order and line grouping vary, so a standalone `A.` regex can confuse answer labels with headings, prose, and section markers.
- A conservative answer-group filter avoids false circles but may miss unusual layouts; the fixture corpus must cover the supported formats.
- `loadText()` is asynchronous, but that alone does not prove extraction/index construction is off the UI thread. Measure frame impact on target devices before promising zero jank.
- PDF text bounds use PDF page coordinates; tap coordinates and the 8–12 px snap margin must be transformed consistently across zoom, rotation, and scrolling.
- A queued tap that resolves to no answer candidate should invoke the current ordinary pen tap behavior, consistent with the user's original interaction description.
