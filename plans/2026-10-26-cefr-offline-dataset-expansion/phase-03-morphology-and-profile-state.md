# Phase 03: Safe Morphology and Known-Unrated Profile State

## Objective

Improve headword matching for ordinary inflections while preventing false CEFR assignments and preserving a clear state for known words without a CEFR label.

## Scope

- Preserve exact source forms before morphology: `bitterly` keeps its source B2 label even though `bitter` is B1. The current sources provide no CEFR label for `bitterness`, so it remains recognized-unrated instead of inheriting the adjective label.
- Apply conservative plural rules (`-s`, `-es`, `-ies`) and existing verb inflections only when a candidate headword exists in the offline lexicon.
- Resolve `noodles → noodle` and `medications → medication` through plural handling.
- Remove generic `-ation → -ate`; cross-POS derivations require an explicit reviewed mapping.
- Test ambiguous/invariant forms such as `species` and negative cases that could otherwise resolve a word to an unrelated headword.
- Add a typed lexical status for graded, recognized-unrated, and not-in-lexicon words; keep recognized-unrated tokens in the existing Unknown group with a recognized marker, and route the status through `WordTokenInfo`, profiler summaries, UI coloring/counts, existing API metadata enrichment, and difficulty metrics.
- Preserve proper-noun filtering and ensure actual misses still use the current asynchronous API queue without blocking the initial profile.

## Affected Areas

- `frontend/lib/features/studio_board/services/profiler/text_tokenizer.dart`
- `frontend/lib/features/studio_board/services/profiler/cefr_dictionary_data.dart`
- `frontend/lib/features/studio_board/services/profiler/cefr_profiler.dart`
- `frontend/lib/features/studio_board/domain/models/text_profile_models.dart`
- Relevant profiler and dictionary enrichment presentation/controller files, only if the approved status requires UI changes
- Feature tests under `frontend/test/features/studio_board/`

## Acceptance Criteria

- Exact CEFR entries precede stem candidates.
- `noodles` resolves to the reviewed `noodle` entry; `medications` resolves to `medication` and never to `medicate` as a fallback.
- `bitterly` keeps its exact source label when `bitter` has another level; `bitterness` remains recognized-unrated because the sources provide no exact CEFR label.
- A true lexicon miss stays Unknown and reaches the existing async enrichment path.
- A recognized-unrated entry stays in Unknown with a recognized marker; API metadata never changes CEFR level or advanced difficulty.
- Recognized-unrated words do not silently count as any CEFR level or C1/C2 difficulty.
