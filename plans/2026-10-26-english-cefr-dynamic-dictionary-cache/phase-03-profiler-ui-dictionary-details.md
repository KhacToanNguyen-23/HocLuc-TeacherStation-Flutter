# Phase 03: Profiler UI Marker and Dictionary Details

## Objective

Show when an Unknown CEFR word has an API dictionary entry and allow teachers to inspect its cached metadata without implying that the word now has a CEFR level.

## Stories / Requirements

- Covers **P1** distinct “dictionary entry found” marker in the Unknown group.
- Covers **P2** pronunciation, POS, and definition inspection.
- Implements spec FR-05–FR-07 and FR-12, FR-14–FR-15.

## Scope

- Connect the profiler dialog's selectable tokens to the async enrichment state from phase 02.
- Add a compact, accessible indicator for API-resolved entries while retaining the Unknown CEFR color/count and the current “Chưa định danh” grouping.
- In the selected-word detail area, show available phonetic transcription/audio link (if supported), all available POS labels, and definitions/examples from cache. Handle empty optional fields.
- Add a manual refresh action for an API-cached word and a manual lookup action for a selected Unknown token filtered from automatic requests as a likely proper noun. A failed refresh, including 404, keeps previously cached metadata; all manual requests use the app-scoped concurrency limit.
- Preserve distinct provenance (`apiCache`) and label the result as dictionary metadata, not an assigned CEFR level.
- Avoid rebuilding the full profile or changing CEFR chart values when metadata changes.

## Affected Files

- `frontend/lib/features/studio_board/presentation/widgets/text_profiler_dialog.dart`
- `frontend/lib/features/studio_board/services/profiler/dictionary_enrichment_controller.dart`
- `frontend/lib/features/studio_board/services/profiler/dictionary_service.dart`
- `frontend/lib/features/studio_board/presentation/widgets/text_profiler_tab_views.dart` (only if the CEFR tokens are rendered there)
- `frontend/lib/features/studio_board/presentation/widgets/dynamic_dictionary_word_details.dart` (new, if extraction improves testability)
- `frontend/test/features/studio_board/presentation/widgets/text_profiler_dictionary_metadata_test.dart` (new)

## Tests / Acceptance Criteria

- Unknown tokens without a cache hit retain the existing visual state.
- API-resolved Unknown tokens show an unambiguous dictionary-found marker but remain gray/Unknown and do not change CEFR totals.
- Selecting an enriched token displays phonetics/POS/definitions; absent data renders safely without blank error UI.
- Manual refresh bypasses the positive cache; successful responses replace it, failed responses preserve it, and CEFR remains Unknown.
- A selected likely proper noun can be looked up manually; a refresh 404 neither removes nor shadows a previous successful cache entry.
- A later selection of a manually looked-up proper noun reads its cache entry and shows metadata without triggering an automatic API request.
- API lookup failure leaves the existing dialog usable and no CEFR level is fabricated.
- Test command from `frontend/`: `flutter test test/features/studio_board/presentation/widgets/text_profiler_dictionary_metadata_test.dart`.

## Risks / Failure Cases

- The label must not imply CEFR identification; use “Có mục từ” / equivalent rather than “Đã nhận diện CEFR”.
- Dynamic loading must not make the dialog jump or reset the selected word/tab.
- Do not start network requests from individual chip build methods; lookup belongs to the enrichment controller.
