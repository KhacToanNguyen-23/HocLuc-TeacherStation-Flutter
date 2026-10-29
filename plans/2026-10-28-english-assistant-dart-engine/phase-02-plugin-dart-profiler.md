# Phase 02: Plugin-Owned Dart Profiler

**Stories:** Existing Text Profile behavior, provenance, exact offsets  
**Depends on:** Phase 01 inventory and accepted fixtures.

## Tasks

1. Create `plugins/english_assistant/engine/dart/` as an independent pure-Dart package with typed request/result models and deterministic data loading.
2. Port the profiler modules/data already implemented in `frontend/lib/features/studio_board/services/profiler/`; remove Flutter-relative imports and create plugin-local models. Do not copy UI/enrichment controllers, HTTP dictionary service, or SharedPreferences adapter.
3. Preserve CEFR levels, recognized-unrated/unknown states, existing supported morphology, readability formulas, TTR/MATTR/MTLD, sentence metrics, warnings and teacher recommendations. Document limitations and avoid treating scores as comprehension evidence.
4. Preserve required source/version/license/attribution data. Resolve any conflicting duplicate dataset entries through an explicit, tested policy; retain unknown/conflict diagnostics.
5. Choose and document one API offset unit. Port current UTF-16 spans carefully and convert once at a defined boundary if host geometry uses a different unit.
6. Port tests from `frontend/test/features/studio_board/text_profiler_test.dart`, `services/profiler/cefr_dictionary_data_test.dart`, `offline_lexeme_and_profiler_expansion_test.dart`, generated word-list tests and relevant model tests into plugin-local tests.

## Tests to Write First

- Golden/parity fixtures for all existing profiler tests, deterministic repeated runs and malformed/empty input.
- Exact source-slice assertions for ASCII, emoji/supplementary characters, combining marks, contractions, hyphenated forms and repeated tokens.
- Dataset source, conflict, unknown, proper noun, inflection, short-text metrics and size-bound tests.

## Gate

All baseline Dart profiler cases pass inside the plugin package. Treat results from `116510b` as the compatibility baseline; any algorithm change requires a demonstrated defect/provenance issue, before/after fixtures, and a documented difference accepted before adding DGNL or changing host code. OCR is out of scope by later product decision.

## Rollback

Additive plugin package only. Keep the Core implementation available as a reference until Phase 05 comparison is accepted.

## Phase Outcome — 2026-10-28

- Created an independent plugin-local Dart package with typed text request/result models and Unicode code-point span serialization. Existing profiler internals remain UTF-16, with conversion at the API boundary.
- Ported the deterministic profiler, CEFR/AWL/daily-life datasets, local models, and 25 generated source-word parts. Flutter UI, network enrichment and shared-preferences adapters were excluded.
- Added source/license attribution and merge policy in `DATA_PROVENANCE.md`; a scan found 8,678 labeled generated entries and no duplicate keys/conflicting labels.
- Ported profiler, lexicon, readability, lexical-diversity, syntax, morphology, dataset and model tests into the package. Added request validation and exact span tests for supplementary/combining characters and leading whitespace.
- Verification: `dart test` — 40 passed; `dart analyze` — no issues; independent review — PASS. No Core implementation was changed and no `.hlep` archive was produced.
