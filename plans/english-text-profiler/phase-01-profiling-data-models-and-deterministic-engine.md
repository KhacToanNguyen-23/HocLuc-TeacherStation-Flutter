# Phase 01: Profiling Data Models & Deterministic Engine

## Objective
Define the typed result models for the text profiler and implement deterministic text tokenization, sentence segmentation, and syllable counting algorithms.

## Scope
- Create `frontend/lib/features/studio_board/domain/models/text_profile_models.dart`:
  - `TextProfileResult`
  - `TextStatistics` (total characters, letters, words, sentences, syllables, polysyllables, complex words)
  - `WordTokenInfo` (surface word, normalized word, lemma, pos, cefrLevel, isProperNoun, isNumber, isAcademic, syllables)
  - `ReadabilityMetricItem` (name, score, interpretation, gradeLevelEquivalent, formula, factors, limitations, references)
  - `LexicalDiversityResult` (ttr, mattr, mtld, uniqueWordCount, topRepeatedWords, academicWordCount, academicPercentage)
  - `SyntacticComplexityResult` (sentenceCount, avgSentenceLength, minSentenceLength, maxSentenceLength, lengthDistribution, simpleCount, compoundCount, complexCount, passiveCount, relativeClauseCount, challengingStructures)
  - `VocabularyCoverageResult` (k1Percent, k2Percent, k3Percent, k4PlusPercent, offListPercent, preTeachWords)
  - `PedagogicalRecommendation` (category, title, description, priority, actionableStep)
  - `ExamProfileComparison` (examName, targetLevel, overallFit, scoreAlignment, notes)
- Implement `SyllableCounter` and `SentenceTokenizer` deterministic utilities in `frontend/lib/features/studio_board/services/profiler/`.

## Affected Files
- `frontend/lib/features/studio_board/domain/models/text_profile_models.dart`
- `frontend/lib/features/studio_board/services/profiler/syllable_counter.dart`
- `frontend/lib/features/studio_board/services/profiler/text_tokenizer.dart`

## Tests / Acceptance Criteria
- Syllable count matches standard benchmarks for common English words, including silent 'e', diphthongs, and suffixes (-le, -ed, -es, -tion).
- Sentence tokenizer correctly identifies sentence boundaries without splitting on common abbreviations (e.g., Dr., Mr., etc., e.g., i.e., U.S.).

