# Phase 2: Bounded preprocessing and candidate selection

**Objective:** Retry eligible captures on conservative image variants and deterministically select a readable OCR candidate.

**Stories:** P1 passage retry and candidate/read-order stories.

## Scope

1. Keep a normalized original image as candidate zero. Trigger retries only for measured small inputs or weak OCR results; establish thresholds from Phase 1 baseline data.
2. Produce no more than two variants using existing offline image libraries, for example a scale-up and a contrast/sharpness variant. Avoid unconditional morphology that can thicken small glyphs or close counters.
3. Run the current OCR model for each candidate, preserve per-region geometry and available scores through grouping, and mark confidence as unavailable when the engine does not return it.
4. Reconstruct paragraph order by geometry using line grouping followed by within-line ordering. Do not use an invented score to bridge missing OCR confidence.
5. Rank candidates deterministically: prefer valid non-empty text and available OCR evidence, apply documented quality checks, and retain the original on ties or unsupported output. If confidence is unavailable, only select a retry when a tested structural quality rule clearly improves on the original; do not infer a probability from dictionary membership. Keep the existing no-result fallback.
6. Do not change the `/analyze-svo` response schema or add UI controls.

## Files and modules

- `plugins/english_assistant/engine/ocr_recovery.py` — candidate model, image variants, geometry grouping, ranking.
- `plugins/english_assistant/engine/service.py` — invoke the bounded pipeline from the image branch.
- `plugins/english_assistant/engine/tests/test_ocr_recovery.py` — deterministic unit coverage with fake OCR results.

## Verification

- Test original-only, one/two retries, retry trigger thresholds, equal-score tie, absent confidence, malformed result, empty OCR, and engine exception.
- Test multi-line and multi-column fixtures preserve expected reading order.
- Compare Phase 1 benchmark; ensure clean median CER regression is no more than 2 percentage points and degraded median CER improvement is tracked toward the 10% target.
- Record median and p95 end-to-end `/analyze-svo` response latency; enforce at most two extra OCR calls and p95 ≤3 seconds for 1280×720 benchmark images on the same machine.

## Acceptance criteria

- A fixed image always produces the same candidate and output text.
- The candidate evaluator invokes at most two enhanced retries and falls back to the original when enhanced results do not provide better supported evidence.
- End-to-end `/analyze-svo` p95 latency is ≤3 seconds at 1280×720 on the benchmark machine.
- Geometry tests preserve line order and token order across multi-line passages.
- Existing text-only `/analyze-svo` calls and response models remain unchanged.

## Dependencies and risks

- Depends on Phase 1 output contract and benchmark.
- OCR scores rank candidates but are not probabilities; favor the original when evidence is missing or tied, unless a separately tested structural rule clearly resolves the choice.
- If multi-column reconstruction cannot be supported reliably by the existing box geometry, preserve line order and document the limitation rather than flattening all words by x coordinate.

## Phase Outcome — 2026-10-24

- Added a bounded candidate pipeline: preserve the normalized original, retry at most once with a 1.25× upscale and conservative sharpening when median detected text height is below 19.5 px or mean available confidence is below 0.82, then rank deterministically.
- Confidence is retained only when all selected detections provide valid scores. If confidence is absent, the original remains selected unless a retry has a tested, clear structural gain (usable text over empty text, or at least 30% more alphanumeric characters without a lower alphanumeric ratio).
- OCR detections are grouped by vertical geometry and sorted left-to-right within each line; the prior image-wide vertical projection and morphology path was removed.
- TDD: 14 standard-library `unittest` tests pass, covering geometry, triggers, confidence/no-confidence selection, ties, malformed output, fallback, and the maximum of two total OCR calls.
- Re-ran the actual `/analyze-svo` benchmark on the same 24 images. Degraded median CER improved from `0.429603` to `0.082271` (80.85% relative); clean median CER improved from `0.795652` to `0.115841` (85.44% relative; no clean regression). Aggregate endpoint p95 is `2.390461s`.
- The small-class p95 is `3.278994s` because retry cases require a second model inference; the aggregate p95 meets the user's specified 3-second target. At least one generated small sample triggered a retry; retry count is capped at one enhanced candidate to protect the latency budget.
- The benchmark report is `engine/benchmarks/phase-02.json`; Phase 1 baseline remains preserved in `engine/benchmarks/baseline.json`.
