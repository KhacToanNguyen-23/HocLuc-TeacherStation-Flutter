# Phase 02: Async Profile Enrichment Orchestration

## Objective

Start dictionary lookups only after a synchronous profile is available, keep API metadata separate from CEFR tokens/counts, and prevent late results from updating a different active passage.

## Stories / Requirements

- Covers **P1** background resolution, immediate profile display, safe Unknown state, deduplication integration, and graceful failure.
- Implements spec FR-02, FR-12–FR-13.

## Scope

- Add a passage-scoped enrichment controller/notifier that stores API lookup state by passage id and normalized lemma.
- Provide it one app-scoped `DictionaryService` instance (owned at the studio feature/app composition boundary, not constructed per dialog) so the in-flight map and four-request scheduler are shared across passages.
- Feed unique `Unknown` alphabetic lemmas that are not classified as likely proper nouns into `DictionaryService`; the offline profiler must already have tried the normalized lowercase lemma. Sentence-initial capitalization alone does not disqualify a candidate. Offline CEFR hits never enter the request queue.
- Resolve cache hits and API results asynchronously; do not await them before showing `TextProfilerDialog` or use them to rerun `TextProfilerService.profile`.
- Add a synchronous `profileAndEnrich(passage)` boundary that returns `passage.textProfile` or computes the fallback with `TextProfilerService.profile`, then starts idempotent enrichment without awaiting it. Route `TextProfilerDialog.show` through this shared boundary so stored and fallback profiles use the same path.
- Keep immutable `WordTokenInfo` and `TextProfileResult` unchanged. Expose lookup state in a sidecar map, including pending, found, and unavailable/not-found state as needed by UI.
- Guard UI updates by passage id/profile generation and dispose/cancel subscriptions when the dialog/passage is no longer active. A successful response may still populate the persistent cache after the dialog closes.
- Integrate at the shared profiler presentation boundary. `DgnlService.analyze` creates a profile before a `PdfDgnlPassage` id exists, while the dialog is the only caller of `TextProfilerDialog.show`; avoid launching separately from DGNL to prevent missed/duplicate requests.

## Affected Files

- `frontend/lib/features/studio_board/services/profiler/dictionary_enrichment_controller.dart` (new or equivalent scoped state holder)
- `frontend/lib/features/studio_board/presentation/widgets/text_profiler_dialog.dart`
- `frontend/test/features/studio_board/services/profiler/dictionary_enrichment_controller_test.dart` (new)
- `frontend/test/features/studio_board/presentation/widgets/text_profiler_enrichment_flow_test.dart` (new)

## Tests / Acceptance Criteria

- Initial profile is available before any mocked HTTP response completes.
- Repeated words yield one lemma candidate; concurrent passages share in-flight requests at service scope.
- `TextProfilerDialog.show` uses the stored profile or synchronous fallback, returns that profile immediately, and triggers enrichment once per normalized lemma while the app-scoped service enforces no more than 4 simultaneous requests across dialogs.
- Likely proper nouns are omitted from automatic requests; lowercase offline misses at sentence starts remain eligible.
- Successful lookups update sidecar metadata only; token CEFR and profile CEFR counts remain unchanged.
- A response arriving after passage/profile replacement is ignored.
- Closing the dialog before a successful response persists the result in cache, but the disposed dialog receives no UI update.
- Offline, timeout, 404, parse, and server failures preserve the initial profile and leave CEFR Unknown.
- Test command from `frontend/`: `flutter test test/features/studio_board/services/profiler/dictionary_enrichment_controller_test.dart test/features/studio_board/services/dgnl_dictionary_enrichment_test.dart`.

## Risks / Failure Cases

- There are multiple ways to create a profile; identify and use the common boundary to avoid missed or duplicate enrichment.
- The service must be app-scoped; a dialog-scoped instance would silently break the global request cap and cross-passage deduplication.
- `PdfDgnlPassage.textProfile` may be reused. Never mutate a shared result or recompute it after metadata arrives.
- Dialog dismissal and passage replacement can race in-flight results; use stable passage id plus generation/disposal checks.
