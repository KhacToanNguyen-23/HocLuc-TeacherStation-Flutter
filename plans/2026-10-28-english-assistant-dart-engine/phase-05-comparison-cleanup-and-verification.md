# Phase 05: Comparison, Cleanup and Verification

**Depends on:** Phases 01–04 reviewed and accepted.

## Tasks

1. [x] Compare ported profiler contract, grammar limitations, OCR/S-V-O/Cloze removals and PDF handoff; publish the behavior-difference report.
2. [~] Measure sidecar cold/warm behavior. UI/PDF frame data and same-fixture parity are not available; report these limits without claiming a speedup.
3. [x] Audit old Python/OCR/spaCy/FastAPI/Cloze implementation and API paths. Removed the unused Core `DgnlService`, its old collocation lexicon and tests that asserted fallback behavior. Kept independent PDF annotation, highlight policy and profiler tests.
4. [x] Verify the plugin source tree contains no `.py` source/build/benchmark/test files or Python runtime dependency. The stale data builder and OCR assets were removed earlier; preserve provenance and historical benchmark JSON.
5. [x] Confirm no runtime or app flow reads legacy Cloze annotations; do not migrate or reinterpret stored payloads.
6. [x] Dart engine, Node cleanup, selected Flutter regressions, architecture gate and frontend analyzer pass. Source-only plugin validation passes. The standard archive validator still flags the production archive as stale; production packaging remains deferred by user direction.
7. [x] Use synthetic passage data only. Refresh the development archive under `.run/dev`; keep the production `.hlep` unchanged.

## Tests to Write First

- Final acceptance suite must cover text PDF, unsupported scan/image feedback, standard text extraction unchanged and end-to-end annotation offsets.
- Runtime/source audit reports zero OCR implementation/assets, zero Python source/build/test files and zero active Python/spaCy/FastAPI/Cloze paths inside the plugin.

## Gate

Phase 05 is complete. The unused Core passage analyzer and its collocation lexicon have been removed. Production packaging is a separate future action after an explicit user request.
