# Phase 03: DGNL Grammar and Collocation; Remove S-V-O and OCR

**Stories:** grammar/collocation; remove OCR, S-V-O, spaCy and Cloze by user direction on 2026-10-29  
**Depends on:** Phase 01 source/engine audit and Phase 02 package API.

## Tasks

1. Reconcile Python grammar patterns, dependency-only grammar rules, and plugin collocation data. Port surface-verifiable patterns and collocations into the plugin package with source spans, rule IDs, styles, examples and negative cases. Mark parser-only patterns unsupported; do not approximate them.
2. Remove S-V-O routes/UI/models, spaCy analysis and dependency matchers, all Cloze routes/generation/UI/answer fields, and Python analysis sidecar. Preserve generic free-text chalk annotations and the current offline passage fallback until Phase 04 connects Dart analysis; no Python runtime is declared.
3. Remove OCR from this feature: delete Dart OCR orchestration/tests, the legacy Python OCR helper/tests, OCR model and dictionary assets, and any OCR process adapter. Keep the API text-only and do not add image/crop request support.
4. Preserve standard PDF text-layer extraction and character-box mapping unchanged. If a selected region yields no usable text, explain that scanned/image regions are unsupported and direct the teacher to “Nhập văn bản”.
5. Keep benchmark JSON and `ocr-engine-dependency-audit.md` only as historical migration evidence; label them as out of scope and ensure no production path references them. Remove stale Python data-build tooling after confirming Dart runtime data does not depend on it.

## Tests to Write First

- Grammar/collocation positive/negative tests, rule IDs/styles, offset slices and overlap priorities.
- Removal regression tests: no sentence-role routes, plugin UI/tools, Core analyzer, role fields/styles, or analysis callsites remain.
- Runtime cleanup regression: manifest has no Python backend; no plugin Python source imports spaCy or implements Cloze; Core has no Cloze passage workflow; collocation data has no answer/distractor fields.
- API contract rejects image/crop sources and accepts only text requests.
- PDF no-text feedback directs teachers to “Nhập văn bản”; text-bearing extraction and highlight geometry remain unchanged.
- Source regression confirms there is no OCR code or model/runtime asset in the plugin.

## Gate

Grammar/collocation positive and negative cases pass; S-V-O, spaCy, Cloze and OCR are removed; the Python analysis sidecar is disabled; text-only API validation passes; and ordinary PDF extraction/highlight regression tests pass. Scanned/image-only PDF regions are explicitly unsupported and guide teachers to text input.

## Rollback

The sentence-role endpoint and OCR recovery are removed by user direction. Historical OCR benchmark JSON and audit notes may remain for traceability, but no OCR implementation, model, process, image API or PDF fallback may be restored without a new product decision.
