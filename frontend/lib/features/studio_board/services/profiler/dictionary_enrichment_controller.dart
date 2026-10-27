import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/dynamic_dictionary_entry.dart';
import '../../domain/models/studio_board_models.dart';
import '../../domain/models/text_profile_models.dart';
import 'cefr_dictionary_data.dart';
import 'dictionary_cache.dart';
import 'dictionary_service.dart';
import 'text_profiler_service.dart';

enum DictionaryEnrichmentStatus { pending, found, notFound, failed }

/// App-scoped coordinator for asynchronous dictionary metadata enrichment.
///
/// CEFR classification remains in [TextProfileResult]. This controller keeps
/// API metadata in a sidecar keyed by passage id and normalized lemma.
class DictionaryEnrichmentController extends ChangeNotifier {
  DictionaryEnrichmentController({required DictionaryService dictionaryService})
    : _dictionaryService = dictionaryService;

  static final DictionaryEnrichmentController instance =
      DictionaryEnrichmentController(
        dictionaryService: DictionaryService(
          cache: SharedPreferencesDictionaryCache(),
          offlineLookup: CefrDictionaryData.lookupCefr,
        ),
      );

  final DictionaryService _dictionaryService;
  final Map<String, Set<String>> _startedByPassage = {};
  final Map<String, Map<String, DictionaryEnrichmentStatus>> _statuses = {};
  final Map<String, Map<String, DynamicDictionaryEntry>> _entries = {};

  String? _activePassageId;
  int _activeGeneration = 0;

  String? get activePassageId => _activePassageId;

  DictionaryEnrichmentStatus? statusFor(String passageId, String lemma) =>
      _statuses[passageId]?[_normalize(lemma)];

  DynamicDictionaryEntry? entryFor(String passageId, String lemma) =>
      _entries[passageId]?[_normalize(lemma)];

  /// True when a token has API dictionary metadata. This flag is presentation
  /// metadata only and never contributes to CEFR or difficulty calculations.
  bool hasApiDictionaryEntry(String passageId, WordTokenInfo token) =>
      entryFor(passageId, token.lemma)?.source ==
      DictionaryEntrySource.apiCache;

  int apiDictionaryEntryCount(String passageId, TextProfileResult profile) {
    final lemmas = <String>{};
    for (final token in profile.tokens) {
      if (hasApiDictionaryEntry(passageId, token)) {
        lemmas.add(_normalize(token.lemma));
      }
    }
    return lemmas.length;
  }

  int advancedDifficultyCount(TextProfileResult profile) =>
      profile.tokens.where((token) {
        if (token.isProperNoun || token.isNumber) return false;
        return token.cefrLevel == 'C1' ||
            token.cefrLevel == 'C2' ||
            token.isAcademic;
      }).length;

  double advancedDifficultyPercent(TextProfileResult profile) {
    final eligible = profile.tokens
        .where((token) => !token.isProperNoun && !token.isNumber)
        .length;
    if (eligible == 0) return 0;
    return double.parse(
      ((advancedDifficultyCount(profile) / eligible) * 100).toStringAsFixed(1),
    );
  }

  /// Loads a successful cache record only. In particular, this never sends a
  /// network request for a token filtered as a likely proper noun.
  Future<void> loadCachedEntry(String passageId, String lemma) async {
    final normalized = _normalize(lemma);
    final currentStatus = statusFor(passageId, normalized);
    if (_activePassageId != passageId ||
        normalized.isEmpty ||
        entryFor(passageId, normalized) != null ||
        currentStatus != null) {
      return;
    }

    final generation = _activeGeneration;
    _statuses.putIfAbsent(passageId, () => {})[normalized] =
        DictionaryEnrichmentStatus.pending;
    notifyListeners();

    final entry = await _dictionaryService.getCachedEntry(normalized);
    if (_activePassageId != passageId || _activeGeneration != generation) {
      return;
    }
    if (entry?.source == DictionaryEntrySource.apiCache) {
      _entries.putIfAbsent(passageId, () => {})[normalized] = entry!;
      _statuses.putIfAbsent(passageId, () => {})[normalized] =
          DictionaryEnrichmentStatus.found;
    } else {
      _statuses.putIfAbsent(passageId, () => {})[normalized] =
          DictionaryEnrichmentStatus.notFound;
    }
    notifyListeners();
  }

  /// Explicit teacher lookup, including tokens automatic discovery filtered
  /// as proper nouns. Manual refresh bypasses a successful cache entry.
  Future<void> lookupManually(
    String passageId,
    String lemma, {
    bool forceRefresh = false,
  }) async {
    final normalized = _normalize(lemma);
    if (_activePassageId != passageId || normalized.isEmpty) return;
    if (statusFor(passageId, normalized) ==
        DictionaryEnrichmentStatus.pending) {
      return;
    }
    if (!forceRefresh && entryFor(passageId, normalized) != null) return;

    _startedByPassage.putIfAbsent(passageId, () => <String>{}).add(normalized);
    final generation = _activeGeneration;
    _statuses.putIfAbsent(passageId, () => {})[normalized] =
        DictionaryEnrichmentStatus.pending;
    notifyListeners();
    await _resolve(
      passageId,
      normalized,
      generation,
      forceRefresh: forceRefresh,
    );
  }

  /// Resolves the synchronous profile (using the stored result when present),
  /// starts background enrichment, and immediately returns that profile.
  TextProfileResult profileAndEnrich(PdfDgnlPassage passage) {
    final profile =
        passage.textProfile ?? TextProfilerService.profile(passage.rawText);
    _activate(passage.id);

    final started = _startedByPassage.putIfAbsent(passage.id, () => <String>{});
    final candidates = <String>{};
    for (final token in profile.tokens) {
      if (token.cefrLevel != 'Unknown' ||
          token.isProperNoun ||
          token.isNumber) {
        continue;
      }
      final lemma = _normalize(token.lemma);
      if (lemma.isEmpty ||
          !RegExp(r'^[a-z]+(?:[\x27-][a-z]+)*$').hasMatch(lemma)) {
        continue;
      }
      candidates.add(lemma);
    }

    final generation = _activeGeneration;
    var hasPendingUpdates = false;
    for (final lemma in candidates) {
      if (!started.add(lemma)) continue;
      _statuses.putIfAbsent(passage.id, () => {})[lemma] =
          DictionaryEnrichmentStatus.pending;
      hasPendingUpdates = true;
      unawaited(_resolve(passage.id, lemma, generation));
    }
    if (hasPendingUpdates) notifyListeners();
    return profile;
  }

  void _activate(String passageId) {
    if (_activePassageId == passageId) return;
    final previousPassageId = _activePassageId;
    if (previousPassageId != null) _clearPending(previousPassageId);
    _activePassageId = passageId;
    _activeGeneration++;
    notifyListeners();
  }

  /// Detaches UI updates for a dismissed/replaced dialog without cancelling
  /// already-sent requests; DictionaryService still writes successful cache
  /// entries when those requests complete.
  void deactivate(String passageId) {
    if (_activePassageId != passageId) return;
    _clearPending(passageId);
    _activePassageId = null;
    _activeGeneration++;
  }

  void _clearPending(String passageId) {
    final statuses = _statuses[passageId];
    final started = _startedByPassage[passageId];
    if (statuses == null || started == null) return;
    final pendingLemmas = statuses.entries
        .where((entry) => entry.value == DictionaryEnrichmentStatus.pending)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final lemma in pendingLemmas) {
      statuses.remove(lemma);
      started.remove(lemma);
    }
  }

  Future<void> _resolve(
    String passageId,
    String lemma,
    int generation, {
    bool forceRefresh = false,
  }) async {
    final result = await _dictionaryService.lookup(
      lemma,
      forceRefresh: forceRefresh,
    );
    if (_activePassageId != passageId || _activeGeneration != generation) {
      // The service has already persisted successful API data. Do not publish
      // results from an inactive request into any dialog's sidecar state.
      return;
    }

    final status = switch (result.status) {
      DictionaryLookupStatus.found => DictionaryEnrichmentStatus.found,
      DictionaryLookupStatus.notFound => DictionaryEnrichmentStatus.notFound,
      DictionaryLookupStatus.failed => DictionaryEnrichmentStatus.failed,
    };
    _statuses.putIfAbsent(passageId, () => {})[lemma] = status;
    final entry = result.entry;
    if (status == DictionaryEnrichmentStatus.found &&
        entry?.source == DictionaryEntrySource.apiCache) {
      _entries.putIfAbsent(passageId, () => {})[lemma] = entry!;
    }
    notifyListeners();
  }

  static String _normalize(String lemma) => lemma.trim().toLowerCase();
}
