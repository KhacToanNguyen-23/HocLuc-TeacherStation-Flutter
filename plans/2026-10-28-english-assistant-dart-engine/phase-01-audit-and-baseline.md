# Phase 01: Audit and Baseline

> This is a historical audit of commit `116510b`. Its OCR observations describe legacy behavior only; OCR was removed from the product scope by decision on 2026-10-29.

**Depends on:** None  
**Gate:** No implementation deletion, route cutover, or engine switch until the inventory, source reuse map, measurements, and generic host contract are reviewed.

## Tasks

1. Inventory all `plugins/english_assistant` files, routes, callers, manifests, build steps, datasets, licenses, tests and Python requirements at commit `116510b`.
2. Trace Flutter text extraction, `DgnlService`, `EnglishSentenceAnalyzer` S-V-O/OCR calls, English fallback rules, PDF char boxes, annotations, page navigation, Cloze readers and plugin bridge permissions.
3. Inventory the Dart profiler dependency graph; identify pure-Dart modules/data and Flutter/network/cache-only code. Record exactly which tests establish current behavior.
4. Reconcile profiler CEFR/collocation datasets with Python `cefr_lexicon.json`, `academic_collocations.json`, grammar rules and provenance. Do not silently choose one conflicting source.
5. Audit legacy OCR trigger/input/output/error behavior, RapidOCR/Tesseract dependencies and assets, licenses, Windows availability, output boxes/confidence and historical 24-image results. Verify engine, detector/recognizer models and native DLLs are local and no network model download is needed at runtime. Record candidate decision; if an engine is not installed, state the exact pending local spike and do not imply it passed. Do not implement OCR yet.
6. Freeze synthetic passage, PDF geometry and OCR fixtures/hashes. Capture current Dart profiler results plus Python sidecar cold/warm process/response baseline. Clearly mark unavailable live PDF/frame metrics.
7. Define the API and generic host contract: source text or scoped image crop, request correlation token, offset unit, span styles/metadata, OCR status/diagnostics and stale-selection handling. OCR boxes must map from crop coordinates through a tested crop-to-page transform to PDF annotation geometry.
8. Update the migration matrix with destination/removal, tests, provenance and evidence per file/module/route/dependency.

## Tests to Write First

- No new runtime code in this phase. Identify exact existing profiler tests to port and freeze expected output before implementation.
- Add/identify contract fixtures for supplementary characters, combining marks, repeated words and annotation geometry.
- Add OCR fixtures for normal text (OCR bypass), scan, unreadable image, malformed recognition output and engine error.
- Add a scanned-PDF geometry fixture that asserts crop-relative OCR boxes map to expected page rectangles and stale/wrong-page transforms are rejected.

## Deliverables

- `python_to_dart_migration_matrix.md`, `host-span-contract.md`, `host-span-fixtures.json`, `baseline.md` and `ocr-engine-dependency-audit.md`.
- A dependency/license decision record for a Windows OCR engine. The local audit found Tesseract unavailable; Phase 03 cannot integrate or remove legacy OCR assets until a selected engine's actual Windows binary, models, DLLs, licenses, offline launch, geometry, CER and latency are validated.

## Rollback

Planning and baseline only. Keep all runtime files and `.hlep` unchanged.

## Phase Outcome — 2026-10-28

- Inventory completed at commit `116510b`; mapping covers plugin routes, Python modules/tests/data/OCR assets, existing Core Dart profiler dependencies, S-V-O and PDF call paths, Cloze readers and manifest/process supervision.
- Generic code-point span contract and crop-to-page OCR geometry fixtures are recorded. Normal PDF text extraction remains host-owned and is the first path; only a selected missing-text crop is eligible for OCR.
- Baseline: 28 Python unittest cases, Python API/rule scripts, 22 Text Profiler Flutter tests and 12 architecture tests pass. Dart profiler cold/warm microbench and actual Python sidecar startup/RSS/endpoint samples are in `baseline.md`.
- Existing OCR one-pass and recovery reports are preserved, not overwritten. The current local OCR stack runs under Python but is not declared in plugin requirements; Tesseract is not installed. Tesseract is the first candidate, but no engine is approved for redistribution until its Windows binary/model/DLL and local no-download launch pass review and OCR gates. Phase 03 remains gated on this proof.
- TDD test-first for implementation begins in Phase 02; Phase 01 changes no runtime code. No Python/OCR asset deletion, route cutover or `.hlep` write occurred.
