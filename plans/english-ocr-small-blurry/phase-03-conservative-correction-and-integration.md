# Phase 3: Conservative correction and endpoint integration

**Objective:** Prevent uncertain OCR output from being silently rewritten, preserve plugin compatibility, and verify the complete offline path.

**Stories:** P1 confidence-aware vocabulary correction and fallback/compatibility criteria; P2 benchmark completion.

## Scope

1. Replace unconditional fuzzy-token correction in the image OCR path with a confidence-gated rule using the existing local vocabulary. Require an unambiguous candidate and a documented threshold/margin; preserve the recognized token for missing/weak confidence, proper names, valid unmatched words, and ties. When Tesseract supplies no confidence, disable spelling guesses for that path.
2. Keep separately justified deterministic cleanup such as boundary noise removal and split-token merging behind tests; avoid deleting single-letter or uncommon content without strong evidence.
3. Integrate selected/corrected text into the existing `_parse_with_spacy` call. Preserve Tesseract's fallback availability, graceful error handling, and the `/analyze-svo` response model; do not apply confidence-dependent word substitutions when its confidence is unavailable.
4. Run the full generated benchmark against the Phase 1 baseline and document per-class CER/WER and latency. If confirmed targets fail, revise preprocessing/candidate thresholds before accepting the phase.
5. Package the modified plugin and run the repository plugin, architecture, and Flutter analyzer gates.

## Files and modules

- `plugins/english_assistant/engine/ocr_recovery.py` — confidence-aware lexical decisions.
- `plugins/english_assistant/engine/service.py` — endpoint wiring and fallback compatibility.
- `plugins/english_assistant/engine/tests/test_ocr_recovery.py` and `test_api.py` — correction and API regression coverage.
- `plugins/english_assistant/engine/benchmarks/` — final comparison report.
- Generated `plugins/english_assistant.hlep` — synchronize using the required packaging script.

## Verification

- Test known OCR substitutions that should be corrected, valid rare/unmatched words that must stay unchanged, missing-confidence cases, ties, capitalization, punctuation, and proper-noun-like tokens.
- Test `/analyze-svo` for text input, image success, empty OCR, unavailable OCR, and thrown OCR exceptions; assert the existing response shape.
- Run the benchmark and assert the confirmed targets: degraded median CER improves by at least 10% relative (or does not regress when baseline CER is zero); clean median CER increases by no more than 2 percentage points.
- Assert end-to-end `/analyze-svo` p95 latency ≤3 seconds for 1280×720 images on the benchmark machine.
- Run `python -m pytest plugins/english_assistant/engine/tests`.
- Run `node scripts/package_plugin.mjs english_assistant`, then `node scripts/validate_plugins.mjs`.
- From `frontend/`, run `flutter test test/architecture_test.dart` and `flutter analyze --no-fatal-infos`.

## Acceptance criteria

- Dictionary corrections happen only when both OCR confidence and lexical evidence meet the documented rule; uncertain tokens remain unchanged.
- Dictionary correction is disabled on OCR paths with no confidence scores.
- The image and text routes keep the existing response schema and execute without a remote service.
- All generated benchmark criteria pass and baseline/final CER, WER, and latency are retained in the report.
- The packaged `.hlep` matches the plugin source and the required repository gates pass.

## Dependencies and risks

- Depends on candidate scores/geometry from Phase 2.
- If the legacy RapidOCR callable exposes no scores, disable confidence-based spelling correction for that path; do not infer confidence from dictionary membership alone.
- A synthetic benchmark does not guarantee projector/camera performance; add anonymized real scans later if they become available.

## Phase Outcome — 2026-10-24 (complete)

- Replaced unconditional OCR substitutions with region-level correction rules: confidence must be finite and in `[0.90, 1.0]`; the token must be lowercase, absent from the local vocabulary and its supported inflections, and exactly one edit from the best candidate; similarity must be at least `0.84` with at least `0.12` margin over the next candidate. Proper-name-like, dictionary-matched, valid-inflected, weak/no-confidence, and ambiguous tokens remain unchanged.
- RapidOCR corrections use each detection's score. Tesseract output carries no score and receives no dictionary or optical-confusion substitutions. OCR image output also bypasses the parser's legacy unscored substitutions; text-only request behavior remains unchanged.
- Added endpoint regression coverage for text input, image success, low/missing confidence, Tesseract without confidence, empty/unavailable OCR, thrown OCR errors, and response shape.
- TDD verification: `python -m unittest discover -s plugins/english_assistant/engine/tests -p 'test_*.py' -v` passes 28 tests. Existing `test_api.py` and `test_rules.py` scripts also pass. `python -m pytest ...` cannot run because pytest is not installed; the standard-library tests cover the new cases.
- Accuracy: against Phase 1, degraded median CER improved from `0.429603` to `0.000000`; clean median CER improved from `0.795652` to `0.012969`. WER medians are retained by class in `engine/benchmarks/final.json`.
- Latency gate: the runner enforces <=3 seconds for aggregate and each image condition, and repeats the 24 fixed images five times. After skipping the redundant retry only when every region confidence is at least `0.995`, the default 120-request run passes: aggregate `0.9265s`, clean `0.9265s`, small `0.7844s`, blurred `0.9994s` p95. CPU utilization was `76.9%` across 8 logical CPUs.
- Packaging: `node scripts/package_plugin.mjs english_assistant` produced an 18-entry archive; dev-only engine tests/benchmark files are excluded. `node scripts/validate_plugins.mjs` reports all 3 plugins schema-valid and synchronized.
- Repository gates: Python compilation passes; plugin package/validator pass; Flutter architecture invariants pass `12/12`; `flutter analyze --no-fatal-infos` reports no issues. Flutter required a process-scoped `safe.directory=D:/flutter` and elevated cache access because the installed SDK is outside the writable workspace; global Git config was left unchanged.
