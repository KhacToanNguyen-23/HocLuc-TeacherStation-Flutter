# Phase 01: Dictionary Models, API, Cache, and Service

## Objective

Implement a testable dictionary metadata model and `DictionaryService` that follows offline → local cache → Free Dictionary API ordering, deduplicates terms, persists successful results, and safely falls back to Unknown.

## Stories / Requirements

- Covers **P1** local cache, API lookup, deduplication, bounded concurrency, timeouts, and graceful errors.
- Implements spec FR-01, FR-03–FR-11.

## Scope

- Define immutable model types for entry, phonetic data, meaning/definition, nullable CEFR, source, and cache timestamp.
- Parse the API's top-level entry list and optional `phonetics`, `meanings`, POS, definitions, examples, and audio fields. Malformed optional fields must not fail the whole candidate.
- Inject `http.Client` and a lightweight cache boundary backed by existing `shared_preferences`; do not introduce Hive/Isar.
- Persist successful records indefinitely per normalized lemma; represent negative 404 cache records with a 24-hour expiration. Support an explicit refresh path that bypasses a successful cache hit and replaces it only after a valid response.
- Implement offline lookup bypass, cache-first resolution, single-word URL encoding, global in-flight Future deduplication, a four-request concurrency cap, 5-second timeout, and no immediate retry loop after non-404 errors.
- Store Free Dictionary results with `cefrLevel == null` and `source == apiCache`; never infer CEFR.
- Keep the service returning typed success/not-found/failure outcomes so UI code does not interpret raw HTTP status or JSON.

## Affected Files

- `frontend/lib/features/studio_board/domain/models/dynamic_dictionary_entry.dart` (new)
- `frontend/lib/features/studio_board/services/profiler/dictionary_service.dart` (new)
- `frontend/lib/features/studio_board/services/profiler/dictionary_cache.dart` (new; interface + SharedPreferences implementation if separation is needed)
- `frontend/test/features/studio_board/services/profiler/dictionary_service_test.dart` (new)
- `frontend/test/features/studio_board/services/profiler/dynamic_dictionary_entry_test.dart` (new)

## Tests / Acceptance Criteria

- Offline dictionary hits produce no HTTP request.
- Cache hits return persisted data without HTTP; a reload from mocked preferences retains source, phonetics, POS, definitions, and timestamp.
- Duplicate tokens and concurrent calls for the same normalized lemma issue only one request.
- Parallel requests never exceed 4; URI encoding and 5-second timeout are verified with an injected/mock client.
- Parse multiple entries and missing optional fields; malformed JSON, 404, timeout, and server error yield typed non-crashing outcomes.
- An automatic 404 is not fetched again during its 24-hour TTL; transient errors can retry on a later service invocation. A failed explicit refresh, including 404, preserves the previous successful entry, and a refresh 404 does not create a negative-cache record that shadows it.
- API entries have null CEFR and never affect the offline profiler.
- Test command from `frontend/`: `flutter test test/features/studio_board/services/profiler/dictionary_service_test.dart test/features/studio_board/services/profiler/dynamic_dictionary_entry_test.dart`.

## Risks / Failure Cases

- Preferences writes racing between duplicate resolutions: coalesce same-lemma in-flight work before writing.
- API fields can be absent or contain multiple meanings: preserve lists and parse each optional field defensively.
- Automatic proper-noun filtering reduces unnecessary requests; a teacher can explicitly query a selected filtered token. Deduplicate requests and negative-cache only automatic 404 results.
