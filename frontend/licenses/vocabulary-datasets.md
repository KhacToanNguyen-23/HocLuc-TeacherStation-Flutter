# Vocabulary dataset attribution

## CEFR-J Vocabulary Profile, version 1.5

The generated offline lexicon is derived from the CEFR-J Vocabulary Profile by
Yukio Tono and Tono Laboratory, Tokyo University of Foreign Studies. The
unmodified source CSV is retained under `data/vocabulary_sources/`. The source
dataset is available at:
<https://github.com/openlanguageprofiles/olp-en-cefrj>

The project states that CEFR-J vocabulary and grammar datasets may be used for
research and commercial purposes at no charge with proper citation. The
expanded profile keeps one-token headwords with source CEFR labels. Where a
headword has multiple POS-specific labels, the generated word-level projection
uses the lowest CEFR level present in the source and records the original POS
rows in the validation report. The live profiler retains its historical chunk
precedence until Phase 02 integrates the generated replacement; the generated
lexicon itself always follows the published source labels.

Suggested citation: Tono, Y. (2013). *CEFR-J Vocabulary Profile* (Version 1.5).
Tokyo University of Foreign Studies.

The generator audits the previous local level chunks against the published
profiles. Its current report distinguishes source-supported matching labels,
source-label conflicts, and words absent from the labeled sources. The expanded
lexicon uses the published source label for conflicts; unmatched legacy words
are retained as recognized-unrated entries and do not contribute CEFR levels.
See `data/vocabulary_sources/validation_report.json` for the row-level audit.

## Octanove Vocabulary Profile C1/C2, version 1.0

The C1/C2 additions are derived from Octanove Labs' profile, distributed in the
Open Language Profiles CEFR-J repository. The source is retained under
`data/vocabulary_sources/`. The source repository identifies this dataset as
Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0).
Attribution must be retained and derived vocabulary data redistributed under
the same license terms:
<https://github.com/openlanguageprofiles/olp-en-cefrj>
<https://creativecommons.org/licenses/by-sa/4.0/>

Attribution: Octanove Labs, *Octanove Vocabulary Profile C1/C2* (Version 1.0).

## Coxhead Academic Word List

The 570 AWL headwords, sublists, and single-token family forms are attributed
to Averil Coxhead, *A New Academic Word List*, TESOL Quarterly 34(2), 2000,
pp. 213–238. The family spellings were derived from the ten primary sublist
pages maintained by Te Herenga Waka—Victoria University of Wellington.
For the profiler's academic metric only, sublists 1–5 are estimated as B2 and
sublists 6–10 as C1 based on relative frequency. This is an internal teaching
heuristic, not a CEFR-J or Coxhead CEFR assignment. The official CEFR tag for an
AWL word stays separate. All published single-token family spellings are
included in the academic lookup map; the headword set remains 570 items.
Source information:
<https://www.wgtn.ac.nz/lals/resources/academicwordlist/awl-headwords>

The University copyright page says its web material may be reproduced without
further permission for non-commercial purposes with accurate reproduction and
attribution; commercial reproduction requires prior written permission. Obtain
permission from the University before shipping this AWL data in a commercial
distribution:
<https://www.wgtn.ac.nz/site-info/copyright>
