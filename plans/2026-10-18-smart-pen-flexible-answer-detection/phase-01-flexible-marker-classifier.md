# Phase 01 — Marker extraction and flexible local grouping

## Stories

Covers **P1 — Recognize flexible layouts** and **P1 — Preserve semantic safety**.

## Goal

Turn PDF text fragments into conservative marker candidates with hit bounds on the marker itself, and recognize the reported local layouts without weakening the current false-positive safeguards.

## Work

- Inspect and document the current `SmartPenAnswerCandidate` construction, text fragment geometry, grouping thresholds, and fixture generator in `smart_pen_answer_index.dart` and `smart_pen_index_test.dart`.
- Introduce a marker-candidate representation separating raw leading-label extraction from semantic answer-group classification. Preserve source fragment, prefix/marker bounds, full option bounds, line/column position, evidence, and rejection reason.
- Support exact and attached leading labels such as `A`, `A.`, `(A)`, and `A.Thất`; use character geometry when available and a bounded prefix-bound fallback when the extractor gives only a combined fragment.
- Replace the fixed nearby-text gap as the sole association rule with page-relative scale-aware row/column proximity plus neighboring marker/group evidence. Cover long formula spans and horizontally dispersed options without associating text from the next question/column.
- Preserve vertically arranged and two-column choice groups. Add a distinct conservative pattern for bare A-D error-identification markers below a numbered sentence.
- Permit credible incomplete clusters at the top/bottom page edge for the next phase, while keeping ordinary isolated/ambiguous labels ineligible for hit testing.
- Extend the labeled generated-PDF fixture corpus for attached text, wide formula gaps, bare error markers, watermark overlap, prose and heading distractors, duplicate labels, and ambiguous layouts.

## Acceptance Tests

- Intended markers in all supported local fixture layouts yield marker-specific candidate bounds and can be hit-tested.
- Prose `A`/`A.`, section headings, watermark-only fragments, repeated labels, unrelated nearby text, and ambiguous groupings yield no accepted candidate.
- Partial page-edge groups are exposed as linker input but are not independently promoted to complete question groups without enough local evidence.
- Existing vertical/two-column fixture outputs remain stable; existing pen hit-target coordinate behavior is unchanged.

## Likely Files

- `frontend/lib/services/smart_pen_answer_index.dart`
- `frontend/test/smart_pen_index_test.dart`
- Generated PDF fixture assets/generator used by `smart_pen_index_test.dart`

## Verification

```powershell
flutter test test/smart_pen_index_test.dart
flutter analyze lib/services/smart_pen_answer_index.dart
```

## Exit Criteria

The classifier exposes sufficient raw marker and partial-cluster evidence for cross-page linking, and all targeted positive/negative fixtures pass. Continue to Phase 02 only after ambiguity handling is reviewed.
