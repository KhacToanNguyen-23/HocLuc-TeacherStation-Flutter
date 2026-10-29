# Profiler data provenance

The files in `lib/src/profiler/` and `lib/src/models/` are a plugin-owned Dart
port of the deterministic profiler at baseline commit `116510b`. The Flutter
UI, online dictionary enrichment, HTTP client, and `SharedPreferences` cache
are intentionally excluded.

## CEFR vocabulary

- **CEFR-J Vocabulary Profile 1.5**: Tono, Y. (2013), Tokyo University of
  Foreign Studies. The baseline's source comment records research and commercial
  use at no charge with citation, with copyright retained by Tono Laboratory.
  Source: <https://github.com/openlanguageprofiles/olp-en-cefrj>.
- **Octanove Vocabulary Profile C1/C2 1.0**: Octanove Labs (2016), attributed
  under CC BY-SA 4.0. Derived and redistributed data retains attribution and
  share-alike terms. License: <https://creativecommons.org/licenses/by-sa/4.0/>.
- **Coxhead Academic Word List**: Coxhead, A. (2000), “A New Academic Word
  List,” *TESOL Quarterly* 34(2). The included 570 headwords and family forms
  are used as an academic-vocabulary signal and are not presented as an
  official CEFR rating. Source: <https://www.wgtn.ac.nz/lals/resources/academicwordlist/sublist>.
- **Daily-life vocabulary**: explicitly marked `Daily-Life Curated` in the
  source. This is a locally curated recognition set; its CEFR labels are kept
  separate from official source-backed labels where no supported rating
  exists.

## Merge and uncertainty policy

Generated CEFR source parts are spread in numeric order into one map. An exact
duplicate key would therefore be resolved by the later part, matching Dart map
spread behavior. A source scan at migration time found 8,678 labeled entries
across the parts and no duplicate keys or conflicting labels. The existing
offline lookup precedence remains: daily-life entries and exact source forms,
safe inflections, curated derivations, then unknown. Recognized-but-unrated
items remain distinct from words absent from the lexicon.

No word-list generator or upstream source archive is added in this phase. The
port carries the generated Dart data as-is; refresh tooling and license/source
revalidation remain required before changing or redistributing updated data.

## DGNL grammar and collocations

- Grammar metadata was transcribed from the legacy `engine/grammar_rules.py`.
  Only surface-verifiable rules are evaluated in Dart. Parser/dependency rules
  such as general passive voice and relative clauses are listed as unsupported;
  surface matches are heuristic and may include false positives.
- `academic_collocations_data.dart` is generated from the legacy
  `engine/data/academic_collocations.json` (104 entries at the time of port).
  The source file does not declare an external dataset, author, retrieval date,
  or license. Its provenance and redistribution terms remain **unknown**. This
  port preserves the data for parity work but does not assert that it is
  independently licensed. Resolve attribution and licensing before packaging.

## OCR scope

OCR is out of scope by product decision on 2026-10-29. OCR code, tests and model
assets have been removed. The historical dependency audit and benchmark JSON
are retained as migration records only and are not used by the plugin runtime.
