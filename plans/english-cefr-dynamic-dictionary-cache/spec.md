# Spec: English CEFR Dynamic Dictionary Cache

**Date:** 2026-10-26
**Status:** Implemented and verified

---

## Problem Statement

The offline CEFR lexicon cannot identify every English word, so common, rare, proper, or subject-specific terms may appear as unassigned. Teachers need dictionary metadata for those words without delaying the initial text profile or assigning an unsupported CEFR level.

---

## User Stories

- **[P1]** As a teacher, I want unique unassigned words looked up automatically in the background so that I can see dictionary metadata without waiting for the profile to open.
  Accepted when: the first profile is rendered from the offline engine before any network response is awaited; API results enrich the view asynchronously.

- **[P1]** As a teacher, I want API-resolved words to remain CEFR Unknown unless a trusted CEFR level exists so that the profiler does not present guessed levels as facts.
  Accepted when: Free Dictionary API responses never change a token's CEFR level or the CEFR count; the token remains in “Chưa định danh” and indicates that an API dictionary entry exists.

- **[P1]** As a teacher, I want successful lookups cached locally and duplicate requests deduplicated so that repeated passages and repeated words do not cause redundant network traffic.
  Accepted when: one normalized lemma causes at most one in-flight/successful lookup, and its API data is available from local storage after app restart.

- **[P2]** As a teacher, I want to inspect API-provided pronunciation, part of speech, and definitions for an unassigned word so that I can understand why the word may matter.
  Accepted when: selecting a token with an API cache entry can show its cached dictionary metadata.

- **[P2]** As a teacher, I want to refresh a cached word manually so that I can retrieve updated or corrected dictionary metadata when needed.
  Accepted when: a manual refresh bypasses the successful cache entry, uses the shared request limit, and replaces cached metadata only after a valid API response.

- **[P2]** As a teacher, I want to manually look up a selected Unknown word that automatic proper-noun filtering skipped so that I can inspect a capitalized technical term or name when needed.
  Accepted when: an explicit lookup bypasses the automatic proper-noun filter, uses the shared request limit, and does not assign a CEFR level.

---

## Functional Requirements

1. **FR-01:** Run the existing offline CEFR lookup first. Offline matches retain their current CEFR result and must not trigger an API call.
2. **FR-02:** Keep `CefrProfiler` and the initial `TextProfilerService.profile` pass synchronous and deterministic. The offline lookup must use its normalized lowercase lemma before a token becomes Unknown. After the profile is available, submit only unassigned alphabetic tokens not classified as proper nouns to a background `DictionaryService`; sentence-initial capitalization alone must not suppress a lookup after the lowercase offline miss.
3. **FR-03:** Normalize candidates to a lowercase root word, remove duplicates within a passage, and share in-flight futures across concurrent passages for the same normalized word.
4. **FR-04:** For each automatic candidate, check the local API cache before making a network request. Persist successful API entries indefinitely as per-lemma JSON records using the existing `shared_preferences` package. A manual refresh may bypass a successful cached entry.
5. **FR-05:** Use `https://api.dictionaryapi.dev/api/v2/entries/en/{word}` with URL-safe word encoding. Parse the returned root word, phonetic text/audio when present, all available parts of speech, and definitions/examples when present. Tolerate missing optional fields and multiple entries.
6. **FR-06:** Represent CEFR level as nullable. Free Dictionary API records have no CEFR level and must be marked as source `apiCache`; they must not be converted into A1–C2 using heuristics.
7. **FR-07:** Store `word`, phonetic data, parts of speech, definitions, nullable CEFR level, source (`offlineDictionary` or `apiCache`), and `cachedAt` in the dynamic dictionary model. Store only API records in the local cache; offline vocabulary remains owned by the offline dictionary.
8. **FR-08:** Limit API concurrency to 4 requests while processing all unique lemmas in the passage. Apply a 5-second request timeout.
9. **FR-09:** Persist automatic-lookup 404 negative-cache entries for 24 hours to avoid repeating unsuccessful lookups. Do not automatically retry other network, parse, or server errors within the same profiling run; a later run may retry. A manual refresh 404 must retain the previous successful entry and must not create a negative-cache value that shadows it.
10. **FR-10:** On offline mode, timeout, 404, malformed JSON, or server error, keep the original profile usable, leave the token CEFR Unknown, and do not crash or block the UI.
11. **FR-11:** Send only individual normalized words to the API, never the complete passage.
12. **FR-12:** Keep API-resolved tokens in the existing “Chưa định danh” CEFR group and show a distinct marker that a dictionary entry was found. The marker must not imply that CEFR has been determined.
13. **FR-13:** Ignore asynchronous UI updates for a passage/profile that is no longer active, so a late response cannot update a newly selected passage. Let an already-sent request complete and persist a valid result even if the dialog closes.
14. **FR-14:** Provide a manual refresh action for an API-cached word. It must use the shared request concurrency limit, replace the cached entry only on successful parsing, and keep CEFR Unknown.
15. **FR-15:** Provide explicit lookup for a selected Unknown token skipped by automatic proper-noun filtering. The request must use the shared request concurrency limit and may add API metadata but must keep CEFR Unknown.
16. **FR-16:** When a manually looked-up proper noun is selected again, read its cached API entry and show the dictionary marker/details without starting an automatic network request.

---

## Non-Functional Requirements

- **Performance:** Show the initial offline profile without waiting for network calls; cap concurrent API requests at 4 and each request at 5 seconds.
- **Reliability:** Lookup failures must not change the initial profile or produce uncaught exceptions.
- **Deduplication:** During a passage lookup, issue no more than one request per normalized lemma; coalesce concurrent requests for the same lemma.
- **Privacy:** Network requests contain one word at a time; no passage text or surrounding sentence is transmitted.
- **Persistence:** Successful cache entries survive app restart using the repository's existing SharedPreferences integration.
- **Cache freshness:** Successful entries have no automatic expiry; manual refresh is the only refresh path in this MVP. Negative 404 entries expire after 24 hours.
- **Compatibility:** Avoid adding Hive/Isar in this MVP; consider a database only if the cache becomes a large searchable lexicon.

---

## Success Criteria

- [x] An offline dictionary hit produces zero API requests.
- [x] A passage containing repeated unassigned words triggers at most one request per unique normalized lemma.
- [x] Observed simultaneous API calls never exceed 4; each request times out within 5 seconds.
- [x] Successful API responses remain available after app restart and preserve the API source flag.
- [x] Successful API cache entries remain available indefinitely until manually refreshed or cache data is cleared; a failed manual refresh preserves the previous valid entry.
- [x] A manual lookup can resolve a selected token skipped as a likely proper noun without changing CEFR counts.
- [x] A later selection of a manually looked-up proper noun reads the local cache and causes no automatic API request.
- [x] A 404 from refreshing a previously cached word preserves the previous entry and does not shadow it with a negative-cache record.
- [x] Closing the dialog before a successful response persists the entry and causes no UI update to the disposed dialog.
- [x] API hits do not change CEFR counts or assign any estimated CEFR level.
- [x] Offline mode, 404, timeout, malformed JSON, and server errors leave the profile visible and the affected word CEFR Unknown.
- [x] A 404 is not requested again for the same lemma during its 24-hour negative-cache window.
- [x] No network request contains full passage text.

---

## Out of Scope

- Assigning CEFR from API definitions, spelling, or an unvalidated difficulty heuristic.
- Replacing or expanding the offline CEFR dictionary.
- Integrating a second provider that supplies CEFR labels.
- Uploading passages or sentence context to an external service.
- Migrating the app to Hive or Isar for this initial cache.

---

## Assumptions

- The Free Dictionary API is used only for dictionary metadata and does not provide a trusted CEFR label.
- The expected cache is small enough for per-lemma SharedPreferences JSON entries.
- Successful records persist indefinitely until manually refreshed or cache data is explicitly cleared; manual refresh is the only successful-entry refresh path in this MVP.
- Existing proper-noun detection is used to suppress automatic lookups for likely names; a selected word can still be explicitly looked up/refreshed by the teacher.
- CEFR profile counts remain based on the offline CEFR dictionary; API enrichment affects metadata and UI markers only.
