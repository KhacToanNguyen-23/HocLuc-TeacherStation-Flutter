# Phase 01: Lexeme Schema, Provenance, Generator, and Validation

## Objective

Create a reviewable source of truth for lexical entries and a deterministic generator that emits the Dart lexicon for Phase 02 integration into the offline profiler.

## Scope

- Define a source row for lemma, optional CEFR level, POS, source identifier, license/provenance reference, and explicit derived forms where needed.
- Keep the raw CEFR-J/Octanove source CSVs and a source manifest under `data/vocabulary_sources/`; choose a compact generated shard layout within the profiler feature.
- Capture a reproducible baseline for first-use initialization, p95 repeated lookup latency, and compiled size on the chosen reference build/device; meet the accepted budgets (10 ms, 1 ms, and 1 MB growth respectively).
- Build a deterministic generator that audits historical curated-level precedence, uses published source labels when levels conflict, and moves unmatched legacy words to recognized-unrated output.
- Validate unique headwords separately from inflected/family forms; validate CEFR values, duplicate conflicts, normalized-key collisions, required provenance, and source license records.
- Audit every existing hand-curated label against the published profiles. Keep a legacy label only when the source supports it; when the source disagrees, use the source label, and when no source label exists, emit recognized-unrated without CEFR.
- Fail generation before writing output when validation fails.
- Update `frontend/licenses/vocabulary-datasets.md` with new sources and attribution; record the confirmed non-commercial AWL use and the written-permission requirement if distribution later becomes commercial.

## Affected Areas

- `frontend/lib/features/studio_board/services/profiler/cefr_dictionary_data.dart`
- New normalized data/source files and generated Dart shards under `frontend/lib/features/studio_board/services/profiler/`
- A deterministic repository generator under `scripts/`
- `frontend/licenses/vocabulary-datasets.md`
- Feature-scoped generator/data validation tests under `frontend/test/features/studio_board/services/profiler/`

## Acceptance Criteria

- Generation is deterministic and idempotent.
- A graded entry cannot be emitted without a valid CEFR label and provenance.
- Conflicting duplicate labels and normalization collisions are reported with row/source context.
- The validator reports CEFR-labeled headwords, recognized-unrated headwords, AWL-only headwords, inflected forms, and AWL family forms separately; only CEFR-labeled headwords count toward the 8,000–10,000 target. It records POS-level CEFR collisions and applies the documented lowest-source-level projection for the current word-only lookup.
- A dry run does not modify generated files.


## Runtime Integration Boundary

Phase 01 audits and generates the replacement data but does not switch the live lookup map. Phase 02 performs that switch: published CEFR labels replace historical conflicting chunk levels, and legacy words without source labels stay recognized-unrated. The current runtime behavior is therefore transitional until Phase 02 is approved and implemented.
