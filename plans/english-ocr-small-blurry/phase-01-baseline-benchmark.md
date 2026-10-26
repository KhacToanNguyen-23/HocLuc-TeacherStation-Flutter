# Phase 1: Baseline and deterministic OCR benchmark

**Objective:** Establish the runtime contract and a reproducible accuracy baseline before changing OCR behavior.

**Stories:** P2 (measure quality); foundation for P1 OCR retry and candidate-selection stories.

## Scope

1. Verify which offline sidecar interpreter supplies Pillow, NumPy, OpenCV, RapidOCR, and the optional Tesseract fallback; record exact installed versions and the `rapidocr_onnxruntime` return structure. Do not add a new OCR engine or model.
2. Add a small OCR adapter/result representation that preserves recognized text, geometry, and confidence only when returned by the installed engine. Provide a test seam for a fake OCR callable.
3. Generate 24 fixed 1280×720 English passage images from known source strings: 8 clean, 8 reduced-text-size, and 8 blurred cases. Keep fonts and degradation settings deterministic and local; report if a required image library is unavailable rather than silently skipping benchmark results.
4. Add CER/WER and latency measurement against the current one-pass OCR path; record a baseline report for the same corpus to compare in Phase 3.

## Files and modules

- `plugins/english_assistant/engine/service.py` — inspect only for exact runtime behavior unless a narrow adapter extraction is required.
- `plugins/english_assistant/engine/ocr_recovery.py` — proposed typed candidate/adapter seam if needed.
- `plugins/english_assistant/engine/tests/test_ocr_recovery.py` — adapter and metric tests.
- `plugins/english_assistant/engine/benchmarks/` — generated corpus metadata and reproducible benchmark runner/results; do not add raw runtime model files.
- `plugins/english_assistant/engine/requirements.txt` — change only if the offline runtime audit proves an already-used capability is undeclared; explain any added package and size.

## Verification

- Test CER/WER helpers against exact-match, insertion, deletion, substitution, punctuation, and empty-reference examples.
- Run adapter tests with legacy output, empty output, missing confidence, and malformed result entries.
- Run the baseline on all 20 or more generated samples using the actual offline model and save per-class CER/WER and latency.

## Acceptance criteria

- Repeated corpus generation yields identical source strings, fonts, image dimensions, and degradation parameters.
- The benchmark includes 24 1280×720 samples (8 clean, 8 reduced-size, 8 blurred), reports per-class CER/WER and median/p95 end-to-end `/analyze-svo` response latency, and meets p95 ≤3 seconds on the benchmark machine.
- The actual sidecar's OCR output shape and available confidence behavior are documented; unavailable runtime dependencies are a phase blocker, not a passing benchmark.

## Dependencies and risks

- No OCR model migration. Phase 2 depends on this adapter and baseline.
- If the actual sidecar environment cannot execute OCR, determine its documented dependency installation path before proceeding; do not substitute a fake OCR pass for the accuracy baseline.

## Phase Outcome — 2026-10-24

- Runtime verified: Python 3.12.10, Pillow 12.3.0, NumPy 2.4.6, OpenCV 5.0.0.93, `rapidocr_onnxruntime` 1.4.4, bundled English PP-OCRv4 recognition model. `pytesseract` is unavailable in this environment.
- The actual legacy output is `(detection_rows, timing_values)`; each row contains box, text, and confidence. The adapter preserves the score only when finite and within `[0, 1]`.
- TDD result: 8 OCR recovery unit tests pass with `python -m unittest discover -s plugins/english_assistant/engine/tests -p test_ocr_recovery.py`. `pytest` is not installed; no package was installed outside the workspace.
- Baseline: 24 generated images passed through the current `/analyze-svo` endpoint. Median CER/WER: clean `0.7957 / 0.8856`, small `0.4296 / 0.6424`, blurred `0.4879 / 0.6760`. Overall endpoint latency p95 is `1.7541s`; clean-class p95 is `2.5259s`, both below the 3-second target.
- Machine-specific per-sample output and package versions are recorded in `engine/benchmarks/baseline.json`. Current clean-text accuracy is poor, and the existing dictionary correction rewrites several correctly recognized words; Phase 3 must address that behavior.
- The user-facing review gate is next; Phase 2 has not started.
