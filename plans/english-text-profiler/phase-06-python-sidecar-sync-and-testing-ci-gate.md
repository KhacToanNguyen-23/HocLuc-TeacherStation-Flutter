# Phase 06: Python Sidecar Sync, Unit Tests & CI Gate

## Objective
Sync the Python sidecar engine (`dgnl_analyzer.py` / `service.py`) with profiler endpoints, package `english_assistant.hlep`, write comprehensive automated tests in Flutter and Python, and verify all CI architecture gates.

## Scope
- Update `plugins/english_assistant/engine/dgnl_analyzer.py` & `service.py`:
  - Enrich CEFR lexicon lookup for 6 levels.
  - Expose `/api/dgnl/profile` endpoint returning readability, diversity, and sentence complexity.
- Package plugin via `node scripts/package_plugin.mjs english_assistant` to update `english_assistant.hlep`.
- Add automated Flutter unit tests in `frontend/test/features/studio_board/text_profiler_test.dart`:
  - Unit tests for Syllable Counter, Sentence Tokenizer, Readability formulas (against known baselines).
  - Unit tests for TTR, MATTR, MTLD lexical diversity.
  - Unit tests for 6-level CEFR classification and unknown word handling.
  - Unit tests for K1-K3 coverage and pre-teach recommendation logic.
  - Unit tests for short text, empty input, and malformed punctuation handling.
- Run CI verification:
  - `node scripts/validate_plugins.mjs` (0 errors)
  - `flutter test test/architecture_test.dart` (12/12 passed)
  - `flutter analyze --no-fatal-infos` (0 errors, 0 warnings)
  - `flutter test test/features/studio_board/text_profiler_test.dart` (all pass)

## Affected Files
- `plugins/english_assistant/engine/dgnl_analyzer.py`
- `plugins/english_assistant/engine/service.py`
- `plugins/english_assistant.hlep`
- `frontend/test/features/studio_board/text_profiler_test.dart`

## Tests / Acceptance Criteria
- All automated unit tests pass.
- All CI gates pass without warnings or architectural violations.

