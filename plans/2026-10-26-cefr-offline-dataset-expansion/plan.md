# Plan: Offline CEFR Lexicon Expansion and Safe Lemmatization

Mode: --hard
Risk: normal â€” Expands static vocabulary data and changes synchronous lexical classification; no network or persistence schema changes.

## Overview

Grow the Text Profiler's verified, CEFR-labeled offline headwords from 4,698 current `wordToCefr` entries to 8,000â€“10,000 unique CEFR-labeled headwords. Prioritize A1â€“A2 and B1 everyday vocabulary, retain source and license provenance, and improve inflection handling without promoting a word based on an unsafe stem. Report AWL-only and recognized-unrated headwords separately; neither counts toward the 8,000â€“10,000 CEFR-labeled target.

The current CEFR-J core contains 4,000 entries; `wordToCefr` contains 4,698 entries; adding the 570 AWL headwords yields 4,722 unique headwords after overlap. The 3,094 AWL family forms are forms, not additional headwords. The complete CEFR-J CSV contains 6,863 unique single-token headwords. The published CEFR-J plus Octanove sources contain 8,679 unique normalized tokens including 356 source-listed inflectional forms; the conservative headword count excluding those forms is 8,323. `noodle` is absent from those labeled sources; `medication` is labeled B2 and can be recovered from `medications` by plural normalization in the tokenizer.

## Scope Challenge

- **Exists?** The synchronous profiler, a CEFR-J core, curated CEFR chunks, AWL headwords/forms, and bounded suffix candidates already exist. The data is split across Dart files and currently lacks the requested everyday headword coverage.
- **Minimum?** Add a traceable data source and deterministic Dart generation/validation, add reviewed vocabulary, refine exact-first morphology, and carry recognized-but-unrated vocabulary separately if the user approves that state.
- **Mode:** `--hard` because this spans data representation, dataset provenance/generation, tokenizer/profiler behavior, and validation.
- **Risk:** normal â€” static offline data and synchronous app logic only; no external API or persistence changes.

## Baseline and Invariants

1. Keep `CefrDictionaryData.lookupCefr` synchronous and preserve its current public behavior for callers.
2. Count unique CEFR-labeled headwords separately from AWL-only headwords, recognized-unrated lexemes, and inflectional/family forms. The 8,000â€“10,000 target applies only to unique entries with a supported CEFR label. Report all counts independently.
3. Assign CEFR only when the source supports a level. Frequency, word length, dictionary presence, or an API response must not be presented as an official CEFR label.
4. Keep per-entry provenance and license metadata in the source data and generated attribution notes.
5. The repository license note says CEFR-J v1.5 can be used commercially with citation. The user confirmed this app distribution is non-commercial, so AWL may be used with attribution under the University terms; if distribution changes to commercial, written permission is required before redistribution. AWL-only entries remain excluded from the CEFR target. [AWL source](https://www.wgtn.ac.nz/lals/resources/academicwordlist), [University copyright terms](https://www.wgtn.ac.nz/site-info/copyright). Do not add Oxford lists or other restricted data unless their license is cleared.
6. Exact lexical matches take precedence over generated inflection candidates. `bitterly` retains its source level; `bitterness` has no source CEFR label and remains recognized-unrated.
7. Inflection candidates are accepted only when the resulting headword is present. Do not use a generic `-ation â†’ -ate` transformation; add `medication` as its own reviewed entry and resolve `medications â†’ medication` as plural inflection.
8. Keep the profiler's initial pass offline and synchronous. Network enrichment remains asynchronous and is only a fallback for unresolved words under the existing rules.

## Proposed Architecture

- Add a normalized, reviewable lexeme source record with `lemma`, optional `cefrLevel`, `partOfSpeech`, `sourceId`, and license/provenance reference. Keep inflected forms or explicit derivation mappings in a separate field/table rather than inflating the headword count.
- Add a deterministic generator/validator that emits compact Dart maps/shards consumed by `CefrDictionaryData`. It must validate allowed CEFR values, duplicate/conflicting labels, normalization collisions, required provenance, and the unique CEFR-labeled headword target before overwriting generated files.
- Preserve source POS-level labels in the raw source files. Since the current profiler is word-keyed, its generated projection uses the lowest CEFR label actually assigned to that headword in the source (earliest source level) and reports all multi-label/POS collisions for audit; no new label is inferred.
- Phase 02 begins only after documenting a permitted source capable of contributing trustworthy CEFR labels. If the source review cannot support the planned count, report the reachable count and revise the target with the user; do not estimate CEFR from frequency or morphology.
- Phase 02 uses the complete CEFR-J v1.5 source plus Octanove C1/C2 where required. CEFR-J permits commercial use with citation; Octanove is CC BY-SA 4.0 and its attribution/share-alike notice must accompany the derived data. [CEFR-J terms](https://github.com/openlanguageprofiles/olp-en-cefrj), [Octanove license](https://creativecommons.org/licenses/by-sa/4.0/).
- Preserve exact lookup, then try conservative plural/verb inflections. Cross-POS and derivational changes require explicit reviewed mappings.
- Represent â€œrecognized English, CEFR unassignedâ€ internally distinctly from a true lexicon miss, but keep it in the existing Unknown group with a â€œrecognizedâ€ marker. Preserve the current API metadata enrichment rules; an API response must not assign CEFR or advanced difficulty.
- Benchmark first-use initialization separately from repeated dictionary lookup. A synchronous hash lookup is not a guarantee of zero startup cost.

## Phases

- [x] Phase 01: [Lexeme schema, provenance, generator, and validation](phase-01-lexeme-schema-and-generator.md) â€” establish a reproducible source of truth and safe generated data.
- [x] Phase 02: [Reviewed A1â€“B1 dataset expansion](phase-02-reviewed-dataset-expansion.md) â€” add daily-life headwords and meet the unique-headword target without relying on restricted lists.
- [x] Phase 03: [Safe morphology and known-unrated profile state](phase-03-morphology-and-profile-state.md) â€” resolve inflections correctly and keep recognized-unrated words in Unknown with a marker.
- [x] Phase 04: [Coverage, performance, and repository gates](phase-04-validation-and-performance.md) — verified and approved.

## Confirmed During Validation

1. Count only unique CEFR-labeled headwords toward the 8,000â€“10,000 target; report AWL-only and recognized-unrated separately.
2. Assign CEFR only when the source provides a supported CEFR label; otherwise use the recognized-unrated state.
3. Use the accepted budgets: p95 repeated lookup â‰¤1 ms, first-use dictionary initialization â‰¤10 ms, and compiled app size growth â‰¤1 MB on the agreed reference build/device. Record the current baseline before dataset expansion.
4. The current app distribution is non-commercial; use AWL with attribution. Revisit permission before any commercial distribution or redistribution change.
5. Recognized-unrated offline entries stay in the existing Unknown group with a marker; API enrichment may add dictionary metadata under the current rules but cannot change CEFR or difficulty classification.

## Risks

- New words do not carry trustworthy CEFR labels merely because they are common. Unverified entries need a recognized-but-unrated state or must stay outside the graded CEFR map.
- Over-aggressive suffix rules can match a related but different word or part of speech. Exact-first lookup, bounded candidate generation, POS-aware explicit mappings, and negative tests mitigate this.
- A future change to commercial distribution would require written permission before AWL redistribution.
- A generated map can increase first-profile initialization and memory use. Measure the baseline and final dataset on supported desktop/web targets before choosing one merged map versus shards.
- A licensed source may not provide enough CEFR-labeled words to meet the target. Phase 02 must establish source feasibility before bulk curation; if it fails, pause the target expansion rather than add unsupported levels.
- Hand-curated additions can drift without reproducible source files and validation. Generated files must be deterministic and checked for staleness.

## Verification Strategy

- Unit tests: exact-form precedence, `noodles â†’ noodle` as recognized-unrated unless a trusted label exists, `medications â†’ medication`, `medication` not resolving through `medicate`, `species` remaining valid, hyphenated forms, proper nouns, and truly unknown words continuing to the existing asynchronous enrichment path.
- Data validation: 8,000â€“10,000 unique CEFR-labeled headwords; report AWL-only and recognized-unrated counts separately; no unresolved duplicate-level conflicts; every graded entry has a valid CEFR level and traceable source; every included source has a recorded license; generated output is reproducible.
- Performance: record current and final first-use initialization, p95 repeated lookup latency, and compiled size on the same reference build/device. Meet the approved budgets (10 ms, 1 ms, and 1 MB growth respectively); lookup remains synchronous.
- Repository gates from the project instructions: `node scripts/validate_plugins.mjs`, `flutter test test/architecture_test.dart`, and `flutter analyze --no-fatal-infos`; run focused profiler tests and `git diff --check` as well.
- No plugin files are expected to change; if that scope changes, follow plugin packaging requirements.

## Session Notes
<!-- Updated by bb-cook. -->

**Last active:** 2026-10-26 22:03 Asia/Saigon
**Phase in progress:** complete
**Status:** All four phases have been implemented, verified, and approved. Final results and measurements are recorded in [phase-04-validation-and-performance.md](phase-04-validation-and-performance.md).
### Decisions made this session
- Use a deterministic local generator and keep generated Dart data synchronous at runtime.
- Preserve one CEFR label per token; resolve source POS collisions with an explicit, reported policy.

### Next immediate action
Plan complete; all approved phases and repository gates are recorded.
