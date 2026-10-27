# Brainstorm: English CEFR Dynamic Dictionary Cache

**Date:** 2026-10-26

## Ideas Explored

- **Expand the offline CEFR list:** predictable and available offline, but requires maintaining and shipping vocabulary data updates; it also does not resolve every rare or domain-specific word.
- **Automatic background API lookup (chosen):** after the fast offline profile, fetch each unique unassigned lemma with bounded concurrency and cache successful dictionary entries.
- **Lookup only when a teacher taps a word:** minimizes network calls, but leaves the rest of the passage unresolved until interacted with; not chosen because the user wants automatic lookup.
- **Estimate CEFR from definitions or heuristics:** could reduce the Unknown count, but the chosen API does not supply CEFR and an inferred level could mislead teachers; explicitly rejected.
- **Use a CEFR-specific remote provider:** potentially gives direct levels, but adds another provider and trust/licensing considerations; out of this MVP.
- **Hive/Isar vs. SharedPreferences:** a database is appropriate for a large indexed lexicon, while SharedPreferences is already present and sufficient for the expected small per-lemma cache; choose SharedPreferences initially.

The Free Dictionary API response contains word, phonetics, meanings, part of speech, and definitions, with no CEFR field in the documented example. [Official API documentation](https://dictionaryapi.dev/)

## User's Direction

- Use a Hybrid lookup: offline CEFR dictionary first, then Local Cache, then Free Dictionary API.
- Automatically look up unique unassigned words in the background, with a limit of 4 simultaneous requests; process all unique lemmas for a passage.
- Before automatic lookup, use the existing lowercased offline lemma lookup. Skip likely proper nouns identified by the current heuristic; sentence-initial capitalization alone does not block an API lookup after the lowercase offline miss.
- Allow a teacher to explicitly look up a selected Unknown token even if the automatic proper-noun heuristic skipped it.
- Keep a fetched word at CEFR “Chưa định danh” unless a trusted CEFR source is added later. Do not guess a CEFR level from its definition or spelling.
- Keep API-resolved words in the existing unassigned category, but add a visual marker that an API dictionary entry was found.
- Keep successful entries indefinitely until manual refresh or cache deletion; expose manual refresh for a selected cached word. Cache automatic API 404 results for 24 hours. A 404 during manual refresh preserves any existing successful entry and must not shadow it. Store entries with the existing SharedPreferences dependency as per-lemma JSON records.
- If a dialog closes while a request is running, allow the request to finish and populate cache while suppressing UI updates for the disposed dialog.
- Do not send the full passage to the API; send only individual normalized words.

## Open Questions

- Planning can settle the compact presentation details for multiple definitions and pronunciations/POS values; the required data and manual refresh action are specified.

## Risks

- API outages, timeouts, rate limits, or 404 responses must leave the initial profile usable and the word safely Unknown.
- Free Dictionary API does not provide CEFR, so API hits improve word metadata but do not reduce the Unknown CEFR count.
- Proper nouns and specialized terms can generate wasted requests; deduplication, 4-request concurrency, and a 24-hour negative cache reduce repeated traffic.
- The capitalization heuristic can mistake a capitalized technical term for a proper noun; manual lookup/refresh remains available for that case.
- SharedPreferences is a small key-value store rather than a database; reassess if the cache grows into a large searchable lexicon.
