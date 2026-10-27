# Phase 04: Integration and Validation

## Objective

Verify the complete async flow, request/persistence invariants, error handling, and repository architecture gates before handoff.

## Stories / Requirements

- Final acceptance for **P1** and **P2** stories, including success criteria across the service, profile state, and dialog.

## Scope

- Add or complete an integration test with a fake API client/cache covering multiple unknown words, duplicates, successful entries, and failures.
- Confirm initial profile rendering precedes network completion and a stale passage cannot receive a previous passage's response.
- Confirm only individual lemmas are sent; assert requests never contain passage text or adjacent context.
- Confirm all API entries retain null CEFR and do not alter CEFR counts, recommendations, or existing offline classification.
- Verify that closing the dialog during an in-flight request still persists a successful response and never updates the disposed UI.
- Verify manual lookup bypasses automatic proper-noun filtering, and a manual-refresh 404 preserves an existing successful cache entry without installing a shadowing negative-cache entry.
- Add no plugin package changes; if any plugin changes become necessary, package it and validate freshness per repository rules.
- Review the complete diff for unrelated workspace changes and do not stage or alter them.

## Affected Files

- `frontend/test/features/studio_board/services/dictionary_enrichment_integration_test.dart` (new)
- Existing dictionary service/controller/dialog tests from phases 01–03, only where integration coverage requires additions.
- Suite fixes discovered during final validation: updated toolbar tooltip assertions, added the missing function word `of`, and aligned the function-word metadata test with the current selectable-span behavior.

## Tests / Acceptance Criteria

- Targeted feature suite from `frontend/`: `flutter test test/features/studio_board`.
- Architecture gate from `frontend/`: `flutter test test/architecture_test.dart`.
- Analyzer from `frontend/`: `flutter analyze --no-fatal-infos`.
- Plugin validator from repository root: `node scripts/validate_plugins.mjs`.
- Required spec success criteria all have direct test evidence: offline bypass, local persistence, unique request count, concurrency <=4, 404 TTL, timeout/error fallback, unchanged CEFR totals, stale response ignored, and no passage upload.

## Risks / Failure Cases

- Live API tests are flaky and leak text; tests must use injected mock clients and synthetic words only.
- Architecture tests or analyzer may reveal existing baseline issues; record exact output and distinguish unrelated failures.
- Any regression that waits on HTTP before profile display blocks release, regardless of successful API tests.

## Phase 04 Verification Results (2026-10-26)

- New integration test and the focused dynamic-dictionary service/controller/dialog suite: **25 passed**. Coverage includes unique lemma requests, immediate synchronous profile, success/failure fallback, no passage upload, persistence, cache refresh behavior, concurrency cap, proper-noun filtering, stale responses, and dialog closure.
- `flutter test test/architecture_test.dart`: **12/12 passed**.
- `flutter analyze --no-fatal-infos`: **No issues found** after removing one unused import introduced in the dialog changes.
- `node scripts/validate_plugins.mjs`: **3 plugins valid and synchronized**.
- `git diff --check`: passed (only existing CRLF normalization notices).
- Initial full-suite run exposed stale toolbar tooltip expectations and a missing function-word entry (`of`). Updated the assertions and function-word set; the targeted regression tests passed.
- Final `flutter test test/features/studio_board`: **345 passed, 0 failed**.
- Independent code review found no actionable defects in the dynamic dictionary implementation, integration test, or the final validation fixes.

**Status:** Implementation and all verification gates are green. User approved finalization for `bb-cook --hard`; Phase 04 is complete.
