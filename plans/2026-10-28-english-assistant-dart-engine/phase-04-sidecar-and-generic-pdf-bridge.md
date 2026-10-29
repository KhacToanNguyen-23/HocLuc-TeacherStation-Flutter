# Phase 04: Sidecar and Generic PDF Bridge

**Stories:** Plugin isolation, one scan API, PDF alignment, no repeated analysis  
**Depends on:** Phases 02 and 03 accepted.

## Tasks

1. [x] Add plugin-local Dart HTTP service with `/health` and one versioned `POST /api/analyze`. Accept extracted text only. Return profile, supported grammar/collocation results, diagnostics and spans together.
2. [x] Bind loopback only; parse `--port` and `HOCLUC_PLUGIN_PORT`; enforce payload/text bounds and safe JSON errors. Reject image/crop sources.
3. [x] Build a self-contained Windows executable at `engine/bin/english_assistant_engine.exe` and update `manifest.json` to generic binary backend with the development executable entry. Keep the runtime process separate from Flutter.
4. [x] Replace the scan overlay's Core analysis call with a generic plugin text/result contract. Validate correlation tokens and Unicode code-point spans, map returned annotations onto existing PDF character boxes, and keep existing category styles and PDF controls.
5. Preserve standard PDF text extraction path and text character-box mapping. When no usable text exists, tell the teacher the selected scan/image has no text layer and direct them to “Nhập văn bản”. Do not rasterize or OCR the selected region.
6. [x] Update plugin UI to request analysis for typed text, reuse scan results, and render local sections/search/filters. Remove Cloze UI and routes.

## Tests to Write First

- API contract, health/dynamic port, bad/empty/oversized requests, text-only source validation and typed failure diagnostics.
- Generic host tests for permission, correlation token, stale selection, bounds, page generation, code-unit conversion and normal PDF char-box mapping.
- Plugin UI test asserts one `/api/analyze` call per passage and zero requests for local section/filter/search changes.
- Regression tests for annotation colors/styles, navigation, save/apply and no legacy Cloze reader behavior.

## Verification

- Dart package tests and analyzer pass; the Windows executable passes direct `/health` and `/api/analyze` smoke requests.
- Flutter plugin/UI and PDF regression tests pass, including architecture invariants.
- Plugin source validator passes in `--source-only` mode. Standard archive freshness validation remains red because the production `.hlep` is frozen during development.

## Gate

Windows executable passes health/API smoke tests with no Dart/Python SDK on runtime PATH; normal extraction remains unchanged; generic host has no plugin ID or language-specific analysis.

## Rollback

Cutover remains reversible while the host bridge is in development. Refresh only the explicitly requested development archive under `.run/dev`; leave the production archive unchanged.
