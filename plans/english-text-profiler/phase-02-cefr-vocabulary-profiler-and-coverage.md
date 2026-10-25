# Phase 02: CEFR Vocabulary Profiler & Coverage

## Objective
Implement word-level CEFR classification across 6 levels (A1, A2, B1, B2, C1, C2), distinguish known/proper nouns/numbers/unknown tokens, and calculate K1-K3+ frequency coverage with pre-teach suggestions.

## Scope
- Create `frontend/lib/features/studio_board/services/profiler/cefr_dictionary_data.dart`:
  - Curated offline lexicon with 2,500+ headwords and POS mapping derived from Oxford 3000/5000 and CEFR profiles.
  - Academic Word List (AWL) keywords subset.
- Create `frontend/lib/features/studio_board/services/profiler/cefr_profiler.dart`:
  - Normalization, lemmatization / basic inflection stripping (plurals, verb tenses).
  - Detection of proper nouns (capitalized tokens not at sentence start), digits, abbreviations.
  - Distribution breakdown: counts & percentages for A1, A2, B1, B2, C1, C2, and Unknown.
  - Frequency coverage (K1 band = 1-1000, K2 band = 1001-2000, K3 band = 2001-3000, K4+ = advanced).
  - Pre-teach vocabulary extraction (prioritizing B2/C1/C2 low-frequency words occurring in the text).

## Affected Files
- `frontend/lib/features/studio_board/services/profiler/cefr_dictionary_data.dart`
- `frontend/lib/features/studio_board/services/profiler/cefr_profiler.dart`

## Tests / Acceptance Criteria
- Correctly assigns A1 (e.g., 'book', 'student'), A2 ('desert', 'record|NOUN'), B1 ('contract', 'wound'), B2 ('feasible', 'substantially'), C1 ('unprecedented', 'inevitable').
- Unknown words are tagged as Unknown (not defaulted to C1/C2).
- Proper nouns and numbers are classified distinctly.
- Pre-teach suggestions contain words of B2+ difficulty present in the input text.

