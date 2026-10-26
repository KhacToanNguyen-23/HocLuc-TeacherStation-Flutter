# Plan: Automatic OCR recovery for small or blurry English passages

**Date:** 2026-10-24  
**Status:** Complete — OCR recovery, accuracy, class-wise latency, packaging, and repository gates pass
**Mode:** Hard (auto-detected; multi-component OCR pipeline)  
**Risk:** normal — local OCR processing and tests only; no external API, persistent user data, or infrastructure changes.

## Scope Challenge

- Exists? The plugin already captures a passage and invokes RapidOCR in `/analyze-svo`; it also has OCR cleanup, but no image retry, confidence-based candidate selection, or OCR accuracy benchmark.
- Minimum? Keep the existing OCR model and API. Add a deterministic benchmark, at most two enhanced variants, confidence-aware result selection, and conservative dictionary correction.
- Complexity? Hard: image transforms, OCR result adapters, word reconstruction, lexical correction, offline fallback, and benchmark verification span several components.

## Spec Quality Check

- Verdict: PASS. P1/P2 stories have testable acceptance criteria; benchmark target confirmed by the user.
- Benchmark: 24 generated 1280×720 images; degraded median CER improves by at least 10% relative; clean median CER regression is at most 2 percentage points; end-to-end `/analyze-svo` p95 is at most 3 seconds on the benchmark machine.

## Research

Codex compatibility for this workflow does not provide named subagents, so the Primary and Alternative researcher roles were run inline as required by `host-compatibility.md`.

### Researcher A — confidence-aware multi-pass recovery (Primary)

- Current path is in `plugins/english_assistant/engine/service.py:542-692`: dark-image inversion, erosion, one RapidOCR run, projection-based word grouping, dictionary correction, then `_parse_with_spacy`.
- RapidOCR output confidence is discarded at `service.py:570-593`; token reconstruction can also merge multiple detections, so confidence must be retained and aggregated explicitly. Do not treat OCR scores as calibrated probabilities.
- Best fit: preserve the original candidate, try no more than two conservative variants only for low-resolution or low-confidence input, rank deterministically, and keep original text when evidence is missing or tied.
- Cost: bounded extra OCR latency; requires adapter tests against the runtime's actual `rapidocr_onnxruntime` result shape. The sidecar requirements file currently lists only FastAPI, Uvicorn, and Pydantic even though OCR code uses optional Pillow, NumPy, OpenCV, RapidOCR, and Tesseract paths; verify the installed offline runtime before changing dependencies.
- Risks: filtering/erosion can erase punctuation or merge glyphs; custom column projection may join lines incorrectly; fuzzy correction may replace valid uncommon words.

### Researcher B — one deterministic upscale pass (Alternative)

- Upscale once when the source is below a measured minimum text/image size, then run the current OCR logic.
- Upside: simpler selection, lower latency, fewer output-format assumptions.
- Cost: cannot compare against the untouched input; one transform can harm already-readable images and does not provide evidence for dictionary correction.
- Verdict: viable as a fallback variant, but weaker than retaining the original and comparing a bounded set of candidates. Replacing RapidOCR or adding a remote/large model is out of scope.

### Compatibility note

The current import is the legacy `rapidocr_onnxruntime` API and is not version-pinned in the plugin requirements. Current RapidOCR documentation exposes text, scores, boxes, and timing through a structured output, while the local integration expects a tuple containing legacy detection entries. Keep a small adapter for the installed legacy interface and add a compatibility test; do not migrate packages as part of this work. Reference: [RapidOCR Python API source](https://github.com/RapidAI/RapidOCR/blob/main/python/rapidocr/main.py).

## Phases

1. [x] **Baseline and deterministic OCR benchmark** — pin down the installed OCR result contract, generate the fixed known-text corpus, and record baseline CER/WER and latency.
2. [x] **Bounded preprocessing and candidate selection** — implement up to two enhancement variants, preserve available confidence and geometry, and choose a candidate deterministically without breaking reading order.
3. [x] **Conservative correction and endpoint integration** — gate dictionary corrections, retain uncertain words, preserve fallback and API behavior, then package and run repository gates. The final repeated benchmark passes the 3-second p95 gate overall and for each image condition.

## Risks

- **HIGH:** runtime OCR dependencies and RapidOCR output shape are not declared in `engine/requirements.txt`; the benchmark and adapter must run in the actual offline sidecar environment before the accuracy gate can be trusted.
- **HIGH:** OCR confidence is not a calibrated probability, and custom word grouping can combine detections with different scores; missing confidence must disable confidence-based correction rather than receive an invented value.
- **MEDIUM:** synthetic degradation may not model projector/camera captures; it is reproducible but does not certify real-world accuracy.
- **MEDIUM:** more OCR passes increase scan time; cap at two retries and enforce end-to-end `/analyze-svo` p95 ≤3 seconds at 1280×720.

## Red-Team Review (inline Codex fallback)

Verdict: WARN — no blocker. Codex does not expose the named `plan-reviewer` subagent, so the reviewer role was run inline per `host-compatibility.md`.

- **MEDIUM, addressed:** benchmark composition was initially underspecified. Phase 1 now fixes 24 cases across clean, reduced-size, and blurred classes (8 each).
- **MEDIUM, addressed:** confidence may be unavailable on legacy/Tesseract paths. Phases 2–3 now retain the original unless a tested structural rule resolves candidate choice, and disable confidence-dependent spelling guesses when scores are missing.
- **LOW, noted:** synthetic images do not model projector/camera artifacts; real samples can be added later, and no real-world accuracy claim is made.
- **RESOLVED:** the user set the image-scan p95 target to ≤3 seconds at 1280×720, confirmed that dictionary correction must be disabled when OCR confidence is unavailable, and kept the benchmark to clean, small-text, and blurred classes.

## Verification Commands

- `python -m unittest discover -s plugins/english_assistant/engine/tests -p test_ocr_recovery.py`
- `python plugins/english_assistant/engine/benchmarks/ocr_benchmark.py --repeats 5 --max-p95-seconds 3 --output plugins/english_assistant/engine/benchmarks/final.json`
- `python -m pytest plugins/english_assistant/engine/tests` (when pytest is available)
- `node scripts/package_plugin.mjs english_assistant`
- `node scripts/validate_plugins.mjs`
- From `frontend/`: `flutter test test/architecture_test.dart`
- From `frontend/`: `flutter analyze --no-fatal-infos`

Plugin packaging and the repository CI gates are mandatory before implementation is declared complete. No tests are run during planning.

## Handoff

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-24 12:15
**Phase in progress:** complete
**Status:** Implementation, accuracy, latency, package freshness, and repository gates pass. The repeated final benchmark includes an enforced p95 gate for aggregate and every image condition.

### Decisions made this session
- The current offline runtime uses Python 3.12.10, Pillow 12.3.0, NumPy 2.4.6, OpenCV 5.0.0.93, and `rapidocr_onnxruntime` 1.4.4; Tesseract is unavailable.
- Baseline scans go through the actual `/analyze-svo` endpoint, so reported latency includes OCR and S-V-O parsing.
- Pytest is absent in this interpreter; the standard-library `unittest` runner is used for OCR tests.
- Phase 2 uses one combined upscale/sharpen retry only for small boxes or weak OCR evidence; this keeps the measured benchmark under the response-time target.
- Phase 2 degraded-sample median CER fell from `0.4296` to `0.0823` (80.85% relative improvement); clean median CER fell from `0.7957` to `0.1158`.
- Current 24-sample end-to-end `/analyze-svo` p95 is `2.3905s`; the small-class p95 is `3.2790s`, while the aggregate p95 remains under the user's 3-second target.
- Phase 3 enforces a confidence threshold of `0.90`, a one-edit dictionary match, minimum lexical similarity `0.84`, and a `0.12` winner margin. Confidence is evaluated per OCR region; proper-name-like, known-inflected, valid, ambiguous, low-confidence, and no-confidence words are preserved.
- Small-text recovery skips the extra OCR pass only when every detected region has confidence at least `0.995`; low/missing confidence and weak OCR still trigger the bounded enhancement retry. The generated small-text corpus retains the same CER after this fast path.
- The benchmark gate checks p95 <=3 seconds for aggregate, clean, small-text, and blurred samples and exits nonzero for any violation. Five repeats produce 120 measured requests (40 per image condition). A follow-up review required the five-repeat, final-report command to be explicit and reproducible.
- Final accuracy medians against Phase 1: degraded CER `0.429603 → 0.000000` (100% relative improvement); clean CER `0.795652 → 0.012969` (no regression).
- After profiling showed small-08 was already recognized correctly at confidence `0.9992`, its unnecessary enhancement retry was skipped only when every detection meets the `0.995` confidence threshold. A mixed-confidence regression test ensures a weak region still retries. The default benchmark then passed all 120 scans: aggregate p95 `0.9265s`, clean `0.9265s`, small `0.7844s`, blurred `0.9994s`; CPU utilization was `76.9%` across 8 logical CPUs.
- Repository checks: 28 Python `unittest` cases pass; Python compilation passes; plugin package/validator pass; Flutter architecture gate passes 12/12; `flutter analyze --no-fatal-infos` reports no issues. `pytest` is unavailable in the active Python interpreter.

### Next immediate action
No remaining implementation work. `teaching_companion` remains paused at the user's request and can be resumed now.
