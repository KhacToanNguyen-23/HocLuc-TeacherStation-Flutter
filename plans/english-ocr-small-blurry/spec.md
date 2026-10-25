# Spec: Automatic OCR recovery for small or blurry English passages

**Date:** 2026-10-24  
**Status:** Implemented and verified

---

## Problem Statement

Teachers scan English paragraphs from the board or teaching materials, but small or blurry text can be misrecognized before the existing grammar analysis runs. The plugin should automatically retry OCR on a limited set of enhanced images and avoid silently guessing uncertain words.

## User Stories

- **[P1]** As a teacher, I want small or blurry captures to be enlarged and retried automatically so that I can scan a passage without changing tools or settings.
  Accepted when: the current OCR result remains the fallback, and a bounded retry evaluates no more than two enhanced variants in addition to the original image.

- **[P1]** As a teacher, I want the plugin to choose the best OCR candidate and retain paragraph reading order so that the existing analysis receives a coherent passage.
  Accepted when: candidate selection is deterministic for the same input, and multi-line benchmark passages are reconstructed in the same reading order as their source text.

- **[P1]** As a teacher, I want dictionary corrections only when the evidence is strong so that uncertain or uncommon words are not silently replaced.
  Accepted when: corrections require a documented confidence and lexical-match rule; words below the threshold remain as recognized, and tests cover both corrected and preserved cases.

- **[P2]** As a teacher, I want OCR quality changes measured against known source text so that image processing does not make clean scans worse.
  Accepted when: a reproducible generated benchmark reports character and word error rates for the original and enhanced paths.

## Functional Requirements

1. FR-01: Preserve the existing paragraph-snipping entry point, `/analyze-svo` image request, and downstream analysis response shape.
2. FR-02: Reuse the current offline OCR model. Add bounded image variants for small or low-confidence input, including enlargement and conservative contrast/sharpness processing.
3. FR-03: Carry OCR confidence through token reconstruction where the engine provides it; do not infer confidence for paths that do not provide it.
4. FR-04: Select among original and retry candidates deterministically, using OCR confidence and documented text-quality checks while preserving line and paragraph reading order.
5. FR-05: Apply English dictionary correction only when both the OCR and lexical evidence meet documented thresholds. Preserve the original recognized token when evidence is insufficient.
6. FR-06: If OCR is unavailable, errors, or yields no usable candidate, retain the existing fallback behavior and return a graceful result.
7. FR-07: Add tests for preprocessing decisions, candidate selection, confidence-aware correction, paragraph ordering, empty/clean/degraded inputs, and fallback behavior.

## Non-Functional Requirements

- Performance: At most 2 retry variants per image; end-to-end `/analyze-svo` p95 response latency is at most 3 seconds for a 1280×720 image on the benchmark machine.
- Offline: Core OCR and enhancement continue to work without a network or AI API.
- Compatibility: No new mandatory OCR engine or large model download in this scope.
- Accuracy: Use a fixed, generated benchmark from known text; report CER and WER for baseline and enhanced paths. The enhanced path must reduce median CER by at least 10% relative on degraded samples and increase clean-sample median CER by no more than 2 percentage points.

## Success Criteria

- [x] A fixed benchmark contains at least 20 generated image samples spanning clean text, reduced text size, and blur; the same source strings are used to calculate CER and WER.
- [x] On degraded samples, the enhanced path lowers median CER by at least 10% relative to the baseline path; if baseline CER is zero, it must not regress.
- [x] On clean samples, enhanced processing does not increase median CER by more than 2 percentage points.
- [x] End-to-end `/analyze-svo` p95 response latency is at most 3 seconds for 1280×720 benchmark images on the same offline machine; gate applies to aggregate and each image condition.
- [x] Automated tests verify dictionary corrections are applied only above the selected confidence threshold and uncertain tokens are preserved.
- [x] The existing API response shape and paragraph analysis workflow remain compatible.

## Out of Scope

- Replacing RapidOCR or adding a new mandatory OCR model.
- A manual OCR correction editor, preview controls, or user-configurable enhancement settings.
- Broad English Text Profiler metrics such as CEFR dashboards and readability scores.
- Claims that synthetic benchmark performance guarantees accuracy on real camera or projector images.

## Assumptions

- The current offline OCR model remains the primary engine.
- Initial reproducible benchmark images can be generated locally from fixed known English passages; real classroom scans may be added later.
- The existing vocabulary data may be reused, but its licensing/provenance and fuzzy-match safety must be checked before expanding its role.

