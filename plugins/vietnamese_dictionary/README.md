# Ngữ văn · Từ điển tiếng Việt

Standalone Schema v2.1 HTML/JS plugin, no sidecar or runtime network calls.

## Use

Install from Marketplace, open the plugin and type a Vietnamese word or phrase. The source selector compares dictionary meanings. Enable **Bôi đen để tra từ** in the plugin or its contributed tool palette, then drag-select text on a PDF with a text layer. Selection replaces the search field and triggers lookup. Disable the tool to stop selection-driven lookup. Scanned PDF images require typing or the existing **Quét từ trên ảnh** snipping/OCR path.

Version 1.0.1: source choices use an inline expandable button list rather than a native WebView popup. Leading/trailing commas and periods are removed from typed/selected/snipped terms, while punctuation inside a term is preserved. The scan contribution declares `snip_text_only: true` so raw text is delivered without English analysis. Existing saved analysis overlays are hidden while a raw-text plugin is active, not deleted. The host's appearance control has an opacity icon and Vietnamese tooltip (it controls transparency, not security).

The host receives only a generic `text_selection_mode` contribution and emits `board:text_selected` with `{text, target}` through the SDK. No plugin identity is hardcoded in Flutter. Desktop PDF selection is the target; this is not OS-wide/browser-wide text monitoring.

## Data and attribution

- VNTK: https://github.com/vntk/dictionary — repository MIT notice in `licenses/LICENSE-vntk.txt`.
- Vietnamese Wiktionary contributors via Kaikki: https://kaikki.org/viwiktionary/ — CC BY-SA / GFDL; this package uses CC BY-SA 4.0, legal text in `licenses/CC-BY-SA-4.0.txt`. Individual entry links lead to Wiktionary pages and histories. Snapshot extracted 2026-10-25 from the 2026-10-02 dump.
- @minhqnd: https://dict.minhqnd.com and https://github.com/minhqnd/dictionary/releases/tag/v2.0.0 — upstream declares CC BY-SA 4.0 for data. See `licenses/LICENSE-minhqnd.txt`. This is a mixed-source aggregation, not independent corroboration; some examples were supplemented by AI. Underlying mixed-source rights/provenance are not independently cleared by this prototype.
- `literature-glossary.json`: original draft teaching notes, explicitly shown as requiring teacher review. Linked reference material is not copied wholesale or imported as another dictionary. The new draft glossary is offered under CC BY-SA 4.0.

Changes to upstream data: Vietnamese definitions only; normalized lookup keys; retained original headwords, POS, examples and available source labels; grouped without flattening source attribution; partitioned into 128 deterministic JSON shards. Keep upstream notices when redistributing. No claim of an authoritative or complete V-ACT dictionary. Literary readings may be absent or differ across sources.

The compact headword index loads once; definitions load on demand with a four-shard cache. Original database downloads and temporary demo server files are not included.

## Rebuild

`node scripts/build_vietnamese_dictionary.mjs <evaluated-demo-directory>`

The input directory contains the evaluated `data/combined.json` snapshot and data notices. It is an explicit local build input, not a runtime dependency. Then run `node scripts/package_plugin.mjs vietnamese_dictionary` and `node scripts/validate_plugins.mjs`.
