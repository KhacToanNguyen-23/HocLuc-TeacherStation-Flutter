# Phase 05 comparison and verification

**Captured:** 2026-10-29, Windows development machine  
**Runtime under test:** self-contained Dart Windows executable, loopback API  
**Input:** synthetic, public-domain style passage; no teacher PDF or private text

## Behavior differences

| Area | Current Dart behavior | Difference / limitation |
|---|---|---|
| Profiler | Ported deterministic profile and local datasets; code-point offsets at API boundary | Profile compatibility tests are in the plugin-local Dart package. No Python runtime is required. |
| Grammar | Supported surface patterns run in Dart | Parser/dependency-based rules remain explicitly unsupported; surface rules can produce false positives. |
| Collocation | Local phrase dataset and rule matcher | Dataset source, retrieval date and redistribution terms are unknown; resolve before any release distribution. |
| OCR | No image source, OCR engine, model or recovery path | Image-only PDF selections require manual text input, per the product decision on 2026-10-29. |
| S-V-O and Cloze | No active UI/API/runtime paths | These behaviors were intentionally removed by earlier user direction. |
| PDF integration | One plugin response is reused for plugin UI and existing host PDF annotations | PDF character boxes remain host-owned; per-frame rendering performance was not measured. Stale document generations are rejected. |

The sidecar response carries profile, token, diagnostic and annotation data together. This is larger than the old DGNL-only endpoint response because it includes the detailed reading profile.

## Windows sidecar measurement

Three fresh process launches were measured to `/health`; each process then handled five warm requests. Measurements include loopback HTTP and JSON encoding/decoding in a PowerShell client.

| Metric | Result |
|---|---:|
| Cold process start to health, mean of 3 | 153.46 ms |
| Warm `/api/analyze`, 15 requests, median | 8.02 ms |
| Last measured JSON response | 21,305 bytes |
| Process working set after health | 14.8 MiB |

The historical Python baseline reports a 22.55 ms median and 1,653-byte response for `/api/dgnl/analyze`, but it used a different request fixture, response contract and runtime stack. These figures are not a same-fixture speedup claim. UI/PDF frame time, CPU utilization and a controlled same-input comparison were not captured.

## Verification evidence

- Plugin Dart package: `dart test` — 52 tests passed after Phase 05 contract coverage; rerun `dart analyze` for final verification.
- Windows binary: compiled with `dart compile exe`; direct health and text-analysis smoke requests returned `ok` and `complete`.
- Flutter: selected plugin client, PDF regression, end-to-end and architecture tests — 44 passed, including all 12 architecture invariants.
- Plugin Node checks: 9 passed.
- `node scripts/validate_plugins.mjs --source-only` — passed.
- Standard `node scripts/validate_plugins.mjs` — reports the production archive is stale. The production `plugins/english_assistant.hlep` remains unchanged by user direction; the development archive is `.run/dev/english_assistant.hlep`.
- `flutter analyze --no-fatal-infos` — no issues after the final code-point geometry adjustment.

## Remaining Phase 05 items

- The independent code-review command is unavailable in this run; implementation was manually reviewed and the relevant verification commands were rerun.
- Removed the unused Core `DgnlService` and its standalone fallback-specific tests after migrating the display-mode and overlap tests to data-driven spans. PDF and annotation regression tests remain.
- Final verification: plugin Dart `dart test` — 52 passed; plugin Dart `dart analyze` — no issues; Node cleanup checks — 9 passed; selected Flutter and architecture tests — 44 passed; `flutter analyze --no-fatal-infos` — no issues; source-only plugin validation — passed; `git diff --check` — passed.
- The standard plugin validator reports `OUT_OF_SYNC_HLEP` because the production archive is intentionally untouched. No production package was written.
- Production archive freshness remains intentionally deferred until the user requests production packaging.
