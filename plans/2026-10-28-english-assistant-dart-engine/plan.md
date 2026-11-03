# Plan: English Assistant Plugin-Owned Dart Engine

**Date:** 2026-10-28  
**Slug:** english-assistant-dart-engine  
**Mode:** --hard --tdd  
**Risk:** high-risk — replaces a plugin runtime/API and moves language analysis and PDF spans across the Core/plugin boundary.  
**Spec:** `plans/2026-10-28-english-assistant-dart-engine/spec.md`

## Scope Challenge

- **Exists?** Text Profile already runs in deterministic Dart under `frontend/lib/features/studio_board/services/profiler/`; the Python plugin owned DGNL, OCR recovery, and service routes. Core also contained a separate sentence-role feature slated for complete removal.
- **Minimum?** Move the reusable pure-Dart profiler and data into a plugin-local package, port supported DGNL/collocation behavior, expose one local text API, switch the plugin to a self-contained Dart Windows binary, and leave only generic selection/span/PDF text transport in Core.
- **Complexity:** Hard — cross-boundary extraction, behavior reconciliation, migration API, and staged cleanup.

## Decisions Already Made

- Engine implementation belongs to the independent plugin, not Flutter Core.
- Reuse the existing Dart Text Profiler as the primary source for profile behavior rather than translating its algorithms from Python.
- Treat profiler output at `116510b` as the compatibility baseline; change an algorithm only for a demonstrated defect/provenance issue, with before/after fixtures and a documented difference.
- Dart-only NLP; no spaCy or Cloze. Document unsupported parser-dependent behavior.
- Python may remain temporarily in source during side-by-side comparison only; the accepted final plugin has one Dart runtime and no plugin-owned Python source/build/test code or Python dependency.
- One versioned `POST /api/analyze`; no old analysis aliases. Stop reading legacy Cloze annotations.
- Self-contained Dart executable, separate plugin process, Windows Desktop first, dynamic port. No `.hlep` packaging until the user requests it.
- Keep normal PDF text extraction unchanged.
- OCR is out of scope by product decision on 2026-10-29. Remove OCR code, tests, model/dictionary assets and image request paths. If a selected region has no usable text, direct the teacher to “Nhập văn bản”.
- Host additions remain generic and carry correlation tokens plus plugin-produced spans/annotations.

## Phases

| # | Phase | Purpose | Gate |
|---|---|---|---|
| 01 | `phase-01-audit-and-baseline.md` | Inventory commit `116510b`, freeze profiler/Python behavior and provenance, map host boundary, record baseline. | Reviewed migration matrix, historical OCR audit, text-only host contract, tests/fixtures and baseline. |
| 02 | `phase-02-plugin-dart-profiler.md` | Create plugin-local Dart package and port existing pure-Dart profiler/models/data with exact tests. | Package tests match existing profiler behavior and offset boundary is explicit. |
| 03 | `phase-03-dgnl-and-ocr.md` | Port grammar/collocation; remove OCR, S-V-O, spaCy and Cloze paths. | Grammar/collocation tests pass; no OCR implementation/assets, S-V-O/Cloze workflow, spaCy runtime or Python analysis sidecar remains. Normal PDF extraction/highlights remain unchanged. |
| 04 | `phase-04-sidecar-and-generic-pdf-bridge.md` | Serve one text-only `/api/analyze`, switch manifest to generic binary, update plugin UI and generic PDF/span handoff. | Windows executable health/API checks and PDF annotation regressions pass; image-only regions show text-input guidance. |
| 05 | `phase-05-comparison-cleanup-and-verification.md` | Compare behavior, verify source cleanup and run repository gates without production packaging. | Runtime audit clean, performance/behavior report accepted, archive untouched. |

## Phase Status

- [x] Phase 01: Audit and baseline — inventory, host contract, fixtures, current test results, Dart profiler microbenchmark, Python sidecar process baseline and OCR dependency/license audit recorded.
  - [x] Phase 02: Plugin-owned Dart profiler.
- [x] Phase 03: Remove OCR, S-V-O/spaCy/Cloze; port DGNL grammar and collocation.
- [x] Phase 04: Dart sidecar and generic PDF bridge.
- [x] Phase 05: Comparison, cleanup and verification — Core fallback removed, source audit clean, and Dart/Node/Flutter/architecture gates passed. Production archive freshness remains deferred as requested.

## Source Reuse and Boundary

Pure-Dart profiler candidates under `frontend/lib/features/studio_board/services/profiler/`: `text_profiler_service.dart`, `cefr_profiler.dart`, `text_tokenizer.dart`, `readability_calculator.dart`, `lexical_diversity_calculator.dart`, `syllable_counter.dart`, `syntactic_complexity_analyzer.dart`, `exam_profiler.dart`, `teacher_recommendation_engine.dart`, and local lexical datasets/lemmatizer. Port only required model/data dependencies from `frontend/lib/features/studio_board/domain/models/text_profile_models.dart` and associated lexeme models. Do not carry Flutter controllers, `SharedPreferences` cache, `package:http` dictionary enrichment, or UI code into the engine.

`TextTokenizer` returns Dart `Match.start/end` indexes, which are UTF-16 code-unit offsets. The plugin API and PDF host mapping must agree on an offset unit. Preserve UTF-16 only if the host char-box map is also demonstrably UTF-16; otherwise convert to code-point offsets at the boundary and test supplementary/combining Unicode. Never silently treat the current indices as code points.

User direction on 2026-10-29 expanded S-V-O removal to the entire application and reaffirmed Dart-only NLP with no spaCy or Cloze. The later product decision removed OCR from this feature. The legacy Python analysis service, spaCy analyzer, grammar matcher, Cloze route, OCR recovery implementation and model assets are removed; the manifest declares no sidecar until Phase 04 provides the Dart executable. The plugin-local Dart package owns the profiler and supported surface grammar/collocation logic. Core temporarily retains the existing offline passage fallback until Phase 04 connects the generic plugin span API. Preserve only unclassified text annotations, without role interpretation or role colors. When PDF text extraction returns no usable text, show guidance to enter or paste the text manually.

Historical OCR behavior and dependency findings are preserved only in `phase-01-audit-and-baseline.md`, `ocr-engine-dependency-audit.md` and benchmark JSON. They are archival evidence, not an implementation target. No OCR engine, model, image transport or scan recovery is planned.

## Performance Protocol

- Use existing Text Profiler unit fixtures, frozen short/medium/long passages and PDF character-box fixture.
- At least three cold and warm sidecar runs per text fixture; record latency, CPU/RSS, response bytes, spans and UI/PDF frames when a Windows desktop run is available.
- No whole-machine or Dart-vs-Python performance claim without same-machine, same-fixture measurements.

## Development Rules

- Phase 01 is a hard gate. Final cleanup removes every Python source/build/test file belonging to this plugin; the stale data builder was removed after confirming it did not reproduce the checked-in data and was not used by the Dart runtime.
- Each implementation phase uses TDD: add/port failing tests first, then implementation, then review before phase acceptance.
- Do not add English analyzer logic or plugin IDs to `frontend/lib`.
- Do not create/refresh the production `plugins/english_assistant.hlep`. The explicitly requested development archive is `.run/dev/english_assistant.hlep`.
- Follow repository architecture and CI rules. Do not delete shared/unmapped files.

## Handoff

After review and acceptance, implement with `$bb-cook --hard --tdd plans/2026-10-28-english-assistant-dart-engine/plan.md`.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-29 01:38 Asia/Saigon  
**Phase complete:** phase-04-sidecar-and-generic-pdf-bridge  
**Status:** Phase 04 implements the self-contained Windows Dart sidecar, generic host analysis call, PDF span mapping and sectioned plugin UI. Phase 05 remains pending for final audit and repository-wide gates.

### Decisions made this session
- Baseline commit is `116510b`; preserve the existing Dart profiler output as the compatibility reference.
- Python is comparison-only during migration; final plugin has no Python runtime/source/build/test files.
- OCR and scanned-image recovery are out of scope by user direction on 2026-10-29; no engine or model will be selected.
- Ported profiler metrics and labels remain unchanged from baseline; API spans convert UTF-16 token bounds to Unicode code-point offsets once at the plugin boundary.
- Source lexicon chunks contain no duplicate keys; unknown and recognized-unrated categories remain distinct.
- Package runtime imports only Dart SDK and local package modules; UI, HTTP enrichment and SharedPreferences adapters stay out.
- Python analysis sidecar, spaCy analyzer, Cloze generation/UI/data fields, OCR implementation/assets and the stale Python data builder have been removed; the plugin runtime and source tree are Dart-only.
- The development Windows executable and `.run/dev/english_assistant.hlep` were rebuilt; the production archive remains unchanged.

### Next immediate action
Complete Phase 05: record the current engine behavior/performance comparison, run source and repository gates, and resolve the remaining Core analyzer audit. Scanned/image-only PDF regions remain unsupported and direct teachers to manual text input. Keep the production `.hlep` untouched.
