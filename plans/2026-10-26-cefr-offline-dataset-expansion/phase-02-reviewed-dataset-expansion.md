# Phase 02: Reviewed A1–B1 Dataset Expansion

## Objective

Expand validated offline coverage to 8,000–10,000 unique headwords with priority on A1–A2 and B1 daily-life vocabulary.

## Scope

- Add source-reviewed entries in common noun/verb groups, including food and health vocabulary such as `noodle` and `medication`.
- Import the full CEFR-J v1.5 vocabulary profile (citation required) and Octanove C1/C2 profile (CC BY-SA 4.0 attribution/share-alike); include both notices. Do not import Oxford lists or other restricted lists without license clearance.
- Before bulk curation, document a licensed source with trustworthy CEFR labels and enough relevant coverage to make the target feasible. If none qualifies, stop and agree a revised target instead of inferring labels.
- The user confirmed non-commercial distribution, so AWL may be used with attribution under the University terms. Any later commercial distribution requires written permission before redistribution. AWL-only entries do not count toward this phase's target.
- Assign CEFR levels only when supported by a trusted source. Store lexemes without a trusted level as recognized-unrated records and show them in Unknown with a recognized marker.
- Deduplicate against existing curated chunks, CEFR-J entries, and AWL headwords before calculating the milestone.
- Replace the current hand-curated runtime CEFR map with generated published-source labels; do not preserve conflicting legacy CEFR values.
- Integrate the generated recognized-unrated set into the existing Unknown group and show the approved recognized marker.
- Generate compact Dart output and update dataset attribution/count reports.

## Acceptance Criteria

- The unique CEFR-labeled headword count is between 8,000 and 10,000; AWL-only, recognized-unrated, and inflectional variants do not inflate it.
- Every added graded entry has provenance and a permitted license recorded.
- Coverage checks prove `noodle` is resolved offline as recognized-unrated with a visible marker because the approved CEFR-labeled sources do not include it. `medication` resolves to its CEFR-J source label.
- `medication` is represented as a lexical headword rather than inferred from `medicate`.
- A repeat generation produces no diff.
