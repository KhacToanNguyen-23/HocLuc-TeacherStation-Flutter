# Phase 01 Baseline (`116510b`)

> Historical measurements describe commit `116510b`. OCR implementation and scanned-image recovery were later removed from product scope on 2026-10-29; these results are retained for provenance only.

**Captured:** 2026-10-28, Windows development machine. Inputs are synthetic/public test passages; no teacher PDF or private text was captured. This is a component baseline, not a whole-app performance measurement.

## Current Behavior at the Baseline Commit

- Python `service.py` exposes `/health`, image/text `/analyze-svo`, legacy `/analyze`, `/api/dgnl/analyze` and `/api/dgnl/generate-cloze`.
- Flutter calls `/analyze-svo` from `EnglishSentenceAnalyzer` for typed role analysis and handwriting image OCR. PDF passage scan calls `DgnlService` separately for DGNL and Cloze, with an offline English fallback. Plugin `ui/app.js` calls `/analyze`.
- Normal PDF text extraction and character-box collection remain in the Flutter PDF path; OCR recovery is the separate image-upload path and is not currently integrated as PDF text extraction fallback.
- Dart Text Profiler is deterministic and offline in Flutter Core. It is not yet running in the plugin sidecar.

## Verification Baseline

| Command | Result |
|---|---|
| `python -m unittest discover -s plugins/english_assistant/engine/tests -p 'test_*.py' -v` | 28 passed, 0 failed. Covers S-V-O text/image response cases and OCR recovery/correction/geometry/24-sample fixture generation. Starlette emitted an `httpx` deprecation warning. |
| `python plugins/english_assistant/engine/tests/test_api.py` | Passed. One TestClient DGNL request took 16.4 ms in this run; it checks a 500 ms bound. Cloze route test generated 3 valid items. |
| `python plugins/english_assistant/engine/tests/test_rules.py` | Passed. Dataset/POS, surface matcher and spaCy dependency matcher sample checks passed. |
| `flutter test test/features/studio_board/text_profiler_test.dart` from `frontend/` | 22 passed, 0 failed; includes deterministic profiler, tokenizer/offset, CEFR, readability, lexical-diversity, complexity and widget cases. |
| `flutter test test/architecture_test.dart` from `frontend/` | 12 passed, 0 failed. |

Flutter tests initially hung in the restricted sandbox with no output. They passed after running with a process-scoped `safe.directory=D:/flutter` setting and access to the installed SDK/cache; no global Git configuration was changed. `flutter pub get` reported 42 dependency updates available but incompatible with current constraints; the tracked lockfile was not changed.

## Current Dart Profiler Microbenchmark

A temporary Dart VM harness outside the repository used a deterministic synthetic passage repeated to 32, 128 and 512 words. It called `TextProfilerService.profile` once per fresh Dart process for the cold sample and 7 times for warm samples; these timings exclude process startup, PDF/Flutter work and memory measurement.

| Target words | Actual profile words | Characters | Distinct words | First profile call | Warm median (7 calls) |
|---:|---:|---:|---:|---:|---:|
| 32 | 32 | 244 | 20 | 41.834 ms | 1.312 ms |
| 128 | 128 | 996 | 20 | 37.208 ms | 4.131 ms |
| 512 | 512 | 3,988 | 20 | 54.502 ms | 8.927 ms |

The harness ran with the Flutter package config in Dart VM mode. It was removed after capture. These measurements establish the current in-process Dart algorithm baseline only; Phase 02 must repeat them with the plugin package and compiled executable.

## Current Python Sidecar Process Baseline

The existing `service.py --port <OS-assigned-loopback-port>` was launched in a separate Python process twice. Both runs reported `/health` with spaCy and OCR available. The second run measured five warm text requests per route using a 167-byte JSON body (160-byte form body for `/analyze-svo`); no image was submitted, so this measures text analysis only.

| Measurement | Result |
|---|---:|
| Cold process start to `/health` | 2.520 s (second run; first 2.484 s) |
| Sidecar process RSS after health | 210,882,560 bytes (about 201.1 MiB) |
| `/api/dgnl/analyze` response | 1,653 bytes; warm requests 10.96, 36.10, 9.34, 22.55, 32.04 ms (median 22.55 ms; max 36.10 ms) |
| `/analyze` response | 1,188 bytes; warm requests 43.41, 22.50, 32.39, 19.17, 10.07 ms (median 22.50 ms; max 43.41 ms) |
| `/analyze-svo` response | 1,816 bytes; warm requests 7.58, 29.61, 32.75, 36.23, 31.70 ms (median 31.70 ms; max 36.23 ms) |

These are five-sample loopback measurements on one local Windows run, not p95 estimates or end-to-end PDF performance. CPU utilization was not captured in this run. The earlier 16.4 ms TestClient figure is retained only as a separate in-process reference.

## OCR Quality/Latency Evidence

The checked-in generated fixture uses 24 fixed 1280×720 images (8 clean, 8 small text, 8 blurred). The historical one-pass report is `plugins/english_assistant/engine/benchmarks/baseline.json` (generated 2026-10-23); the recovery report is `final.json` (generated 2026-10-24, 5 repeats × 24 samples = 120 requests). Their SHA-256 values at this commit:

- `baseline.json`: `0FCD6681763A82E6D1EFE3A2A790E3B31E4423129232BF3005F37E906FAB31C8`
- `final.json`: `935D99FBA4E1DA931E7F2BAEBF931B73DE22BD6E441DC1C964505CDAF45F8C34`

| Image class | One-pass median CER / WER | One-pass p95 latency | Recovery median CER / WER | Recovery p95 latency |
|---|---:|---:|---:|---:|
| Clean | 0.7957 / 0.8856 | 2.5259 s | 0.0130 / 0.0833 | 0.9265 s |
| Small | 0.4296 / 0.6424 | 1.5348 s | 0.0043 / 0.0278 | 0.7844 s |
| Blurred | 0.4879 / 0.6760 | 1.6606 s | 0.0000 / 0.0000 | 0.9994 s |
| Aggregate | 0.7716 / 0.7895 | 1.7541 s | 0.0000 / 0.0000 | 0.9265 s |

The recovery report passes its 3-second aggregate and per-class p95 gate. It records 8 logical CPUs and 76.9% CPU utilization during measured requests. These are historical synthetic-image results from the legacy Python/RapidOCR stack; they are a quality/latency target for candidate comparison, not a guarantee for real PDFs or another OCR engine. No OCR benchmark was re-run or written over during this audit.

## Performance Gaps

- The 16.4 ms DGNL figure is one in-process FastAPI TestClient request, not process startup, loopback HTTP, PDF extraction, Flutter UI, or whole-machine timing.
- The Dart profiler tests establish behavior but do not contain a reproducible wall-time/RSS benchmark report. Phase 02 must add a Dart-only benchmark runner for identical synthetic short/medium/long fixtures, with cold/warm process and request timings.
- No live Teacher Station/PDF was open for this audit. PDF extraction fallback visits, crop rendering, annotation geometry, Flutter build/raster frames, end-to-end CPU/RSS and OCR-on-real-page timing remain unmeasured.
- The normal PDF extraction path was not changed or re-benchmarked in Phase 01. Future integration must demonstrate zero OCR invocation for text-bearing input and compare that unchanged path separately.

## Frozen Behavioral Sources

- Text Profiler expected behavior: `frontend/test/features/studio_board/text_profiler_test.dart`, `services/profiler/cefr_dictionary_data_test.dart`, `services/profiler/generated_cefr_source_words_test.dart`, `offline_lexeme_and_profiler_expansion_test.dart`, and relevant model/enrichment tests. Port deterministic offline assertions; exclude Flutter/network cache behavior.
- OCR expected behavior: `engine/tests/test_ocr_recovery.py`, `test_analyze_svo.py`, and checked-in 24-image benchmark metadata/reports.
- Text/DGNL expected behavior: `engine/tests/test_api.py`, `test_rules.py`, `dgnl_analyzer.py`, `grammar_rules.py`, `EnglishSentenceAnalyzer` and `DgnlService` callsites.
- Generic offset/geometry examples are frozen in `host-span-fixtures.json`.
