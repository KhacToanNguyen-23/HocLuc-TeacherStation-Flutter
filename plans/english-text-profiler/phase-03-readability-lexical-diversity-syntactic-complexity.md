# Phase 03: Readability, Lexical Diversity & Syntactic Complexity

## Objective
Implement the 6 standard English readability formulas, 3 lexical diversity algorithms (TTR, MATTR, MTLD), and sentence/syntactic complexity analysis.

## Scope
- Implement `ReadabilityCalculator` in `frontend/lib/features/studio_board/services/profiler/readability_calculator.dart`:
  1. Flesch Reading Ease
  2. Flesch–Kincaid Grade Level
  3. Gunning Fog Index (with complex word syllable criteria and suffix handling)
  4. SMOG Index (with sentence length scaling and sample size caveats)
  5. Coleman–Liau Index
  6. Automated Readability Index (ARI)
  - For each: score, grade equivalent, qualitative interpretation, formula, main factors, limitations, references.
  - Safe guards for text too short (< 5 words) with descriptive warning rather than false scores.
- Implement `LexicalDiversityCalculator` in `frontend/lib/features/studio_board/services/profiler/lexical_diversity_calculator.dart`:
  - Total tokens and unique types.
  - Raw TTR with text length warning.
  - Moving-Average Type-Token Ratio (MATTR) with fixed sliding window (window = 25 tokens or min(total, 25)).
  - Measure of Textual Lexical Diversity (MTLD) using bidirectional threshold factor (default factor = 0.72).
  - Frequency list of top repeated words (excluding stop words) and Academic Word List (AWL) usage.
- Implement `SyntacticComplexityAnalyzer` in `frontend/lib/features/studio_board/services/profiler/syntactic_complexity_analyzer.dart`:
  - Sentence lengths, mean, min, max, standard deviation / distribution (short < 12, medium 12-25, long > 25).
  - Sentence patterns: Simple, Compound (coordinating conjunctions), Complex (subordinating conjunctions/relative pronouns), Compound-Complex.
  - Voice & structures: Passive voice, relative clauses, conditional/inversion/participial clauses.

## Affected Files
- `frontend/lib/features/studio_board/services/profiler/readability_calculator.dart`
- `frontend/lib/features/studio_board/services/profiler/lexical_diversity_calculator.dart`
- `frontend/lib/features/studio_board/services/profiler/syntactic_complexity_analyzer.dart`

## Tests / Acceptance Criteria
- Verified against published benchmark text (e.g. Gettysburg Address or standard readability reference passages).
- MATTR and MTLD produce stable, length-adjusted metrics.
- Syntactic analyzer identifies long sentences (>25 words) and passive voice accurately.

