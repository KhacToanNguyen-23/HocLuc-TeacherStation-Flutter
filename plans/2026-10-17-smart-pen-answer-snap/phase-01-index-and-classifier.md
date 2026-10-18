# Phase 01 — Classifier, page index, and synthetic corpus

**Stories:** P1 semantic safety; P1 visible-page indexing foundation.

## Tasks

1. Inspect the repository's pinned `pdfrx` API and current PDF page lifecycle. Implement a narrow extractor adapter that waits for page load and exposes text tokens/character rectangles in canonical page coordinates; represent empty text and extraction failure explicitly.
2. Create page-local candidate, answer-group, and index models. Reconstruct visual lines/columns from character geometry; accept only A–D labels at option-line starts in a nearby group with at least one other distinct A–D label. Reject ambiguous or insufficient context.
3. Implement document-generation-scoped per-page index state (`notStarted`, `building`, `ready`, `empty`, `failed` or equivalent). Ensure replacing PDF bytes/path invalidates in-flight and ready indices.
4. Start with a flat candidate collection or coarse buckets. Keep spatial query separate from semantics, use viewport-scaled 8–12 logical-pixel tolerance at query time, and defer R-tree adoption until measured lookup shows a miss.
5. Add a versioned labeled synthetic corpus manifest (expected candidate labels and distractors) and deterministic generated PDF cases with fixed seeds/layout variants for vertical options, two columns, prose `A`/`A.`, headings/section labels, ambiguous groups, and textless pages. Keep the evaluation set fixed while thresholds are tuned.

## Acceptance / Verification

- Unit tests show that only fixture-labeled answer labels enter the candidate index; prose, heading, standalone, and ambiguous labels are rejected.
- Canonical bounds remain unchanged by zoom; query transformation selects the expected candidate at 50%, 100%, and 200%.
- Empty extraction produces an explicit empty/unsupported result without OCR or exception leakage.
- Index invalidation ignores results from an older PDF generation.
- Corpus manifest and generator seeds/variants make classifier counts and metrics reproducible across runs.
- Benchmark query p95 below 1 ms with a ready index containing at least 1,000 candidates (report environment and sample count; do not include index-build time in lookup timing).

## Likely files

- New `frontend/lib/services/smart_pen_answer_index.dart` (or equivalent focused service/model files).
- New `frontend/test/smart_pen_index_test.dart` and fixture assets/helpers under `frontend/test/fixtures/`.
- `frontend/pubspec.yaml` only if fixture asset declarations are required; do not add a PDF parser dependency.

## Risks

- Verify character bounds ordering and line/column conventions against actual `pdfrx` output; avoid deriving token geometry from `fullText` character offsets alone.
- Synthetic corpus accuracy is provisional and should not be described as real-world accuracy.
