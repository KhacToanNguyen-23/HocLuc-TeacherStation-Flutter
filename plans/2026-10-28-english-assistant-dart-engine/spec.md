# Spec: English Assistant Plugin-Owned Dart Engine

**Date:** 2026-10-28  
**Status:** Draft

## Problem

The English Assistant used a Python sidecar for DGNL and OCR while the Teacher Station already contains a deterministic Dart Text Profiler. The legacy sentence-role feature is being removed from both plugin and Core. Product direction is now text-layer PDFs only: OCR and scanned-image recovery are out of scope. The plugin must own its analysis implementation and run independently without Python, while preserving reading-analysis behavior and ordinary PDF integration.

## User Stories

- **[P1]** As a teacher, I want the English Assistant to analyze passages through a plugin-owned Dart engine so scans do not require a Python runtime.  
  Accepted when the Windows plugin sidecar is a self-contained Dart executable; no Python runtime or Python source/build/test code belonging to the plugin remains after cleanup.
- **[P1]** As a teacher, I want CEFR vocabulary, readability, lexical diversity, sentence statistics, warnings and recommendations to retain the existing Dart profiler behavior so that migration does not discard analysis I already use.  
  Accepted when the existing profiler fixtures pass against the plugin package, differences are documented, and all required datasets include provenance or an explicit unknown status.
- **[P1]** As a teacher, I want grammar and collocation highlights to stay useful and align with the selected PDF passage.  
  Accepted when supported Dart rules have positive and negative cases, preserve annotation style metadata, and spans map to exact source text through a generic host contract.
- **[P1]** As a teacher, I want a clear explanation when the selected PDF region has no usable text layer.  
  Accepted when the app reports that scanned/image-only regions are unsupported and directs the teacher to the existing “Nhập văn bản” tool.
- **[P1]** As a teacher, I want one scan request to populate analysis sections and filters so switching views does not rerun analysis.  
  Accepted when one versioned `POST /api/analyze` response contains all supported results and local view/filter changes issue no analysis request.
- **[P1]** As a teacher, I want Cloze generation and reading legacy Cloze annotations removed.  
  Accepted when plugin UI, API, host readers/renderers and runtime have no active Cloze behavior.
- **[P2]** As a maintainer, I want the analysis engine and data isolated inside the English Assistant plugin.  
  Accepted when Core contains only generic process, text, span and annotation APIs and imports no plugin engine code.

## Functional Requirements

1. Audit the exact code, data, dependency, API and caller graph at commit `116510b` before changing behavior or deleting files.
2. Reuse the working Dart profiler as the primary source for deterministic Text Profile behavior. Move/copy/adapt its engine, models, and required data into a plugin-owned Dart package; no cross-imports between `frontend/lib` and `plugins/`.
3. Keep UI/network dictionary enrichment, Flutter controllers, SharedPreferences adapters, and host widgets out of the sidecar engine unless replaced by a plugin-local equivalent explicitly required by the API.
4. Preserve CEFR classification, lexical certainty/unknown states, sentence and word statistics, readability, TTR/MATTR/MTLD, supported morphology, recommendations, and source metadata. Do not treat readability as definitive evidence of comprehension.
5. Port DGNL, grammar and collocation behavior into plugin-owned Dart. Reconcile Python rule/data sources; preserve only evidence-supported rules and document spaCy-dependent losses. S-V-O was explicitly removed from the whole application by user direction on 2026-10-29.
6. Expose exact text offsets and typed style/metadata spans. Define one offset unit at the API boundary and convert Dart UTF-16 indices explicitly; test emoji/supplementary characters, combining marks, apostrophes and repeated words.
7. Keep ordinary PDF text extraction and character-box mapping unchanged. Do not rasterize PDF pages or send image data for analysis.
8. Keep the plugin analysis API text-only; reject image/crop request sources. Return profile/rule results, diagnostics and spans. Do not retain DGNL/Profile/Cloze compatibility endpoints.
9. Change only generic host APIs for plugin text handoff, correlation tokens, span validation, PDF mapping, annotation styles and navigation. No English-specific engine, category logic or plugin ID in Core.
10. Run the sidecar as a separate self-contained Dart executable using the existing generic dynamic-port contract (`--port` and/or `HOCLUC_PLUGIN_PORT`) and loopback binding. Target Windows Desktop only.
11. Remove OCR implementation, OCR tests, model/dictionary assets and any OCR process adapter. Historical audit and benchmark records may remain clearly marked as archival evidence.
12. Remove Python source/build/test code and runtime dependencies belonging to the English Assistant, spaCy, Cloze and the old annotation reader after caller/data audit. Port required non-OCR data generation/import tools to Dart or remove them after verifying that their outputs and provenance are preserved.
13. Do not create or refresh the production `plugins/english_assistant.hlep` during development. A development archive may be created only when explicitly requested.

## Non-Functional Requirements and Success Criteria

- Existing profiler deterministic tests are ported before engine behavior is changed; parity differences are recorded.
- One request performs analysis once; switching tabs, filters, search results or selecting a word does not rerun analysis.
- No OCR implementation or OCR model/runtime assets are present in the plugin. Image-only PDF regions are reported as unsupported.
- Measure cold/warm text-analysis latency, process CPU/RSS, response size and UI/PDF span counts against fixed fixtures.
- No `.py` source, build, benchmark or test file, Python runtime dependency, spaCy/FastAPI path or Cloze route/reader remains under `plugins/english_assistant` after cleanup; unrelated repository Python tools stay intact.
- Text-based PDF spans map to existing PDF character boxes and annotation coordinates without changing normal extraction behavior.
- Windows executable starts on a dynamic loopback port and passes health/API smoke tests without installed Python or Dart SDK on runtime PATH.
- Plugin manifest/source validation, architecture test, Flutter analysis and Windows desktop build pass. No production `.hlep` archive is produced in this development plan.

## Out of Scope

- Web, macOS and Linux runtime support.
- Restoring spaCy parser parity or inventing POS/dependency evidence.
- OCR and scanned-image PDF support.
- Cloze generation or interpretation of saved Cloze annotations.
- English-specific implementation inside Flutter Core.
- Marketplace release packaging until separately requested.

## Assumptions

- Commit `116510b` is the source baseline and current checked-out commit.
- Existing Dart profiler output at `116510b` is the compatibility baseline. Change algorithms only to fix a demonstrated defect or provenance problem, and record before/after evidence in tests and the behavior ledger.
- Scanned/image-only PDF support is intentionally deferred; teachers can paste text through “Nhập văn bản”.
- Legacy Python remains available only as a comparison source until cleanup.
- Existing plugin sidecar supervisor can launch a generic binary using its dynamic port and health check; verify this against the actual manifest/runtime path.
