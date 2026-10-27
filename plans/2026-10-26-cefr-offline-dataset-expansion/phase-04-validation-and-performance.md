# Phase 04: Coverage, Performance, and Repository Gates

## Objective

Prove dataset quality, morphology correctness, runtime cost, and compatibility with existing profiler and repository behavior.

## Scope

- Add regression tests for the named vocabulary, exact-form precedence, plural handling, ambiguous suffixes, capitalization, compound tokens, API fallback, and recognized-unrated marker behavior.
- Add data quality checks for target headword count, source/license coverage, duplicates, level conflicts, and generated-file freshness.
- Benchmark first-use initialization separately from repeated synchronous lookup at the final dataset size; measure generated asset/source size and memory impact.
- Compare performance against the Phase 01 baseline on the same build/device. Meet the approved limits: p95 repeated lookup ≤1 ms, first-use initialization ≤10 ms, and compiled size growth ≤1 MB.
- Run full repository verification gates and inspect the final diff for generated artifacts or unrelated changes.

## Acceptance Criteria

- Focused data, tokenizer, profiler, and enrichment tests pass.
- First-use, p95 steady-state lookup, and compiled-size measurements are recorded for the agreed reference target; approved budgets are met and no network wait occurs in the initial profile.
- The CEFR-labeled unique-headword count meets 8,000–10,000; AWL-only, recognized-unrated, inflectional, and AWL family-form counts are reported separately with source attribution.
- `node scripts/validate_plugins.mjs` passes.
- `flutter test test/architecture_test.dart` passes.
- `flutter analyze --no-fatal-infos` reports zero errors and warnings.
- No plugin package changed; if a plugin changes, package it and rerun plugin validation.

## Final Validation Results

- **Dataset:** 8,323 unique CEFR-labeled headwords (A1 1,061; A2 1,229; B1 2,120; B2 2,454; C1 925; C2 890), 356 source-listed inflectional forms, 189 recognized-unrated entries, 78 AWL-only headwords, 570 AWL headwords, and 3,094 AWL family forms. The source audit reports 771 POS/level collisions; the documented projection picks the earliest source CEFR label and preserves the full audit report.
- **Generated source size:** 301,473 bytes across the index and 25 generated shards; largest shard is 700 lines. The index and shards are deterministic and `generate_cefr_lexicon.py --check` passes.
- **AOT lookup benchmark (Windows host):** first lookup 291 µs; 100 batches of 100 exact/inflection lookups yielded a 748 µs p95 batch (7.48 µs per lookup), below the 1 ms budget. Phase 01 recorded 940 µs first lookup and 568 µs p95 batch. The comparison uses the same batch workload; measurements are single-host samples, not device-wide percentiles.
- **Memory sample:** standalone AOT benchmark process working set after dictionary access was 17,870,848 bytes. No Phase 01 working-set baseline was captured, so this is an absolute runtime sample rather than an attributed dictionary memory delta.
- **Windows Release size:** 54,337,017 bytes across 38 files, including a 91,136-byte executable. Phase 01 baseline was 54,189,561 bytes, for a growth of 147,456 bytes (under the 1 MB budget). The final build succeeded; the environment reported missing NuGet and a CMake developer-policy warning, neither prevented the build.
- **Repository gates:** plugin validator passed (3 plugins); architecture test passed 12/12; `flutter analyze --no-fatal-infos` reported no issues; focused profiler/dictionary/dialog suite passed 58/58; Python generator suite passed 9/9; generator freshness check passed; `git diff --check` passed (Git emitted only existing CRLF conversion notices).
- **Architecture adjustment:** the generated lexicon is split into bounded source shards so no generated Dart file exceeds 900 lines. The profiler dialog header was extracted to `text_profiler_dialog_header.dart`; the dialog source is now 835 lines, allowing the architecture gate to pass.
