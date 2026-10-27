# Vietnamese literature dictionary

Mode: fast, scoped implementation following the approved standalone prototype.
Risk: normal — local dictionary assets and a permission-gated generic PDF selection event; no external runtime API.

## Accepted scope

- New `plugins/vietnamese_dictionary` marketplace package on `feat/vietnamese-dictionary`.
- Manual word/phrase input, source-labeled offline definitions, prefix suggestions.
- Combine the three evaluated snapshots, preserving notices and origin labels. Do not represent mixed-source provenance as independently cleared.
- Add a small original, explicitly labeled draft literature glossary with references.
- Load dictionary definition shards on demand; no Python sidecar or network dependency.
- Declarative active text-selection tool fills input from selectable PDF text; scanned PDFs need manual typing or the existing snip/OCR path.
- Generic host selection handling only, no hardcoded subject/plugin IDs.

## Acceptance / verification

- Look up `vô hình trung`, `hồng quân`, `đào lẳng`, `đào thương`; show distinct source attribution and glossary draft label.
- Selection arrives only while the declared tool is active and authorized; switching off stops automatic input replacement.
- Selection during initial data load is retained; stale async lookups cannot replace newer results.
- Verify offline shard lookup, normalization, source filtering, missing term and malformed input behavior.
- Package using `node scripts/package_plugin.mjs vietnamese_dictionary`, then plugin validator, architecture gate, analyzer, focused tests and independent code review.

## Out of scope

Translation, automated literary analysis, Hán-character dictionary imports, OS/browser-wide clipboard monitoring, account sync.

## Implementation evidence — 2026-10-26

- Branch `feat/vietnamese-dictionary`; local changes only.
- Four source groups (three evaluated snapshots plus eight draft literature notes), 52,436 NFC/case/whitespace-normalized headwords. Normalization merges spellings that the standalone demo counted separately; source senses remain separate.
- 128 generated definition shards; four-shard runtime cache; packaged archive synchronized.
- `node --test scripts/tests/vietnamese_dictionary.test.cjs`: 5/5 passing, including active/inactive selection events and selection received before index initialization.
- `flutter test --no-pub test/architecture_test.dart test/features/plugin_engine/plugin_text_selection_test.dart`: 15/15 passing (12 architecture + 3 selection tests).
- `flutter analyze --no-fatal-infos`: no issues.
- `node scripts/validate_plugins.mjs`: all four plugins valid and fresh.
- Independent review found inherited-key handling in JS lookup; fixed with own-property/array checks and regression cases.
- Browser preview verified manual `đào thương` lookup with glossary draft label and reference. Native desktop PDF drag gesture has not been exercised end to end; rebuild/restart desktop app to test the new host capability.
- Mixed-source dataset provenance remains a pre-publication review item; not asserted cleared.

## Feedback fixes — 2026-10-27

- Text-only snip capability prevents dictionary scans from creating English analysis overlays; existing annotations are preserved.
- Replaced native select popup with an inline, keyboard-accessible source menu.
- Trim boundary commas/periods for typed, highlighted and scanned terms without rewriting dictionary keys or internal punctuation.
- Replaced misleading shield appearance icon and added Vietnamese explanation tooltip.
- Rebase target is `origin/develop` (the repository has no `dev` branch).
