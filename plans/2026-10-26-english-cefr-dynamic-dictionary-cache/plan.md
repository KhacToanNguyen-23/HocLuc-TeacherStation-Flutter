# Plan: English CEFR Dynamic Dictionary Cache

Mode: --hard
Risk: high-risk — Adds outbound dictionary API requests, persistent cache records, and asynchronous UI enrichment.
Spec: plans/english-cefr-dynamic-dictionary-cache/spec.md

## Overview

Add a background dictionary enrichment path for words that the existing offline CEFR profiler leaves unassigned. Preserve the synchronous offline profile as the source of CEFR counts; Free Dictionary API responses only add dictionary metadata and a “dictionary entry found” marker. Use per-lemma SharedPreferences JSON records, injected HTTP client, global in-flight deduplication, a four-request concurrency cap, 5-second timeouts, and 24-hour negative caching for 404s.

The existing `TextProfilerService.profile` / `CefrProfiler.profileTokens` remain deterministic synchronous passes. Enrichment runs after the first profile is ready and is kept in state separate from immutable `WordTokenInfo` and `TextProfileResult`. A response can update only the active passage/profile that requested it.

## Scope Challenge

- **Exists?** There is an offline CEFR profiler and SharedPreferences/HTTP dependencies, but no dynamic dictionary cache or DictionaryService.
- **Minimum?** Add the model/cache/API service, async profile enrichment state, and UI indicator/details without changing CEFR decisions.
- **Mode:** `--hard` because this crosses service, persistence, and UI boundaries and depends on an external API.
- **Risk:** high-risk — outbound API calls and persistent dynamic cache data.

## User Stories Covered

- **P1:** Automatic asynchronous lookup for unique unassigned lemmas, graceful fallback, no UI blocking, safe CEFR Unknown, local cache, and deduplication.
- **P2:** Inspect API phonetics, POS, and definitions; manually look up filtered words and refresh cached metadata.

## Architecture

1. Add immutable dictionary entry/definition/phonetic models with nullable CEFR and explicit source. Persist successful API entries indefinitely as individual JSON values keyed by normalized lemma; persist 404 expiration separately. Manual refresh is the only successful-entry refresh path in this MVP.
2. Add one app-scoped `DictionaryService` with injected `http.Client` and cache adapter/preferences. Resolve offline hits first, then local cache, then API. Its shared scheduler and in-flight map coalesce requests across all passages and enforce the four-request cap globally; do not construct it per dialog.
3. Keep enrichment results in an async notifier/controller keyed by passage id and normalized lemma. Do not mutate `WordTokenInfo`, recompute the profile, or change CEFR counts. Persist successful late results even if the dialog closes, but publish UI updates only to the matching active passage/profile.
4. Route every profile-producing path through one idempotent enrichment entry point immediately after the synchronous profile exists, including the stored DGNL profile and the dialog's fallback when `passage.textProfile` is absent. Present the offline profile without awaiting enrichment; repeated calls for the same passage/lemma must share work.
5. Automatically skip likely proper nouns using the existing capitalization heuristic, after the offline lowercase lookup has already run. Mark API-resolved words as “dictionary entry found” while retaining them in the existing Unknown CEFR group. Show cached phonetic/POS/definition metadata and a manual refresh action in the selected-word detail area.

## Phases

- [x] Phase 01: [Dictionary models, API client, cache, and service tests](phase-01-dictionary-models-api-cache-service.md) — P1 storage, parsing, offline/cache/API order, deduplication, caps, and fallback.
- [x] Phase 02: [Async profiler enrichment orchestration](phase-02-async-profile-enrichment.md) — P1 background lookup after profiling, passage-scoped state, stale-response protection, and orchestration tests.
- [x] Phase 03: [Profiler UI marker and word details](phase-03-profiler-ui-dictionary-details.md) — P1 API-hit marker and P2 cached metadata display without changing CEFR presentation/counts.
- [x] Phase 04: [End-to-end failure and repository gates](phase-04-integration-and-validation.md) — Integration coverage for network failures, persistence across reload, deduplication, stale passages, and required repository gates.

## Risks

- The API has no CEFR label; any code that assigns A1–C2 from an API hit would contradict the product decision.
- Proper nouns and specialist vocabulary may generate 404s; concurrency limiting and the negative cache reduce repeat traffic but do not remove first-time requests.
- A late API result can arrive after the teacher switched passages; state must be scoped and stale updates ignored.
- SharedPreferences is appropriate for the expected small cache, not for an indexed large lexicon. Keep the service boundary storage-agnostic enough to migrate later.
- The API may be offline, slow, malformed, or unavailable; the initial offline profile must remain usable in every failure path.

## Verification Strategy

- Run targeted tests after each phase using the phase-specific commands.
- Final frontend verification: `flutter test test/features/studio_board` and `flutter test test/architecture_test.dart` from `frontend/`; `flutter analyze --no-fatal-infos` from `frontend/`.
- Final repository verification: `node scripts/validate_plugins.mjs` from the repository root. No plugin packages are expected to change.

## Handoff

Implement phase by phase with `$bb-cook --hard --tdd plans/2026-10-26-english-cefr-dynamic-dictionary-cache/plan.md`.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-26 13:44
**Phase in progress:** complete
**Status:** All four phases implemented, reviewed, approved, and verified. Final suite passed 345/345; architecture 12/12; analyzer and plugin validator clean.

### Decisions made this session
- Keep the profiler service synchronous; the new dictionary service is separately asynchronous.
- Register a normalized lemma's in-flight future before the first cache await to prevent duplicate requests.
- A failed forced refresh returns the previous successful cache entry; a 404 must not create a shadowing negative-cache record.
- Resolve normalized offline CEFR entries before treating capitalization as a proper-noun miss, so mid-sentence `Juice` remains A2 and avoids API lookup.

### Next immediate action
None. Phase 04 approval received; implementation and repository gates are complete.

## Red-Team Review

- **ACCEPTED:** Make the app-scoped service/scheduler lifetime explicit so the concurrency cap and in-flight deduplication span dialogs and passages.
- **ACCEPTED:** Cover both stored and dialog-fallback profiles via one idempotent enrichment entry point; keep dialog presentation independent of network completion.
- **ACCEPTED:** Apply automatic lookup only to non-proper-noun Unknown words after lowercase offline lookup; allow manual lookup/refresh for a teacher-selected word if the heuristic filtered it.
- **ACCEPTED:** Keep successful entries indefinitely with manual refresh; a failed refresh (including 404) preserves and does not shadow a prior success. Cover in-flight completion after dialog disposal.
- **ACCEPTED:** A manually resolved likely proper noun must use the local cache on later selection without initiating automatic network lookup.

### Phase 02 verification
- TDD red confirmed for missing controller/dialog boundary, and a regression red confirmed capitalized offline Juice was incorrectly classified Unknown.
- Targeted phase tests plus the existing text profiler suite: 24 tests passed.
- Targeted analyzer across 5 changed source/test files: no issues.
- Independent code review passed after fixing the capitalization/offline-lookup ordering issue.
- git diff --check passed for Phase 02 files.

### Phase 03 verification
- TDD red confirmed for missing UI/controller injection, showing an Unknown panel for known CEFR tokens, and manual lookup blocked by a cached 404.
- Phase 03 widget tests, Phase 02 controller/lifecycle tests, and existing text profiler suite: 29 tests passed.
- Targeted analyzer across 7 source/test files: no issues.
- Independent code review passed after resolving the known-word panel and cached-404 lookup findings.
- git diff --check passed.
