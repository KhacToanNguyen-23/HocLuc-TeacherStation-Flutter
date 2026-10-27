import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/dynamic_dictionary_entry.dart';
import 'dictionary_cache.dart';

enum DictionaryLookupStatus { found, notFound, failed }

class DictionaryLookupResult {
  const DictionaryLookupResult({required this.status, this.entry, this.error});

  final DictionaryLookupStatus status;
  final DynamicDictionaryEntry? entry;
  final Object? error;
}

/// Looks up one lemma at a time and caches DictionaryAPI.dev metadata.
///
/// The owning feature should keep one app-scoped instance so the four-request
/// scheduler and in-flight request map are shared across profiler dialogs.
class DictionaryService {
  DictionaryService({
    required DictionaryCache cache,
    required String? Function(String normalizedWord) offlineLookup,
    http.Client? client,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 5),
  }) : _cache = cache,
       _offlineLookup = offlineLookup,
       _client = client ?? http.Client(),
       _ownsClient = client == null,
       _clock = clock ?? DateTime.now;

  static const maxConcurrentRequests = 4;
  static const negativeCacheDuration = Duration(hours: 24);
  static const apiHost = 'api.dictionaryapi.dev';

  final DictionaryCache _cache;
  final String? Function(String normalizedWord) _offlineLookup;
  final http.Client _client;
  final bool _ownsClient;
  final DateTime Function() _clock;
  final Duration requestTimeout;
  final _RequestSemaphore _semaphore = _RequestSemaphore(maxConcurrentRequests);
  final Map<String, Future<DictionaryLookupResult>> _inFlight = {};
  bool _disposed = false;

  Future<DictionaryLookupResult> lookup(
    String word, {
    bool forceRefresh = false,
  }) async {
    final normalized = _normalize(word);
    if (normalized.isEmpty) {
      return const DictionaryLookupResult(
        status: DictionaryLookupStatus.failed,
      );
    }
    if (_disposed) {
      return const DictionaryLookupResult(
        status: DictionaryLookupStatus.failed,
      );
    }

    final running = _inFlight[normalized];
    if (running != null) return running;

    // Register the shared future before the first cache await. Otherwise two
    // callers can both miss the cache and start duplicate HTTP requests.
    final request = _lookupNormalized(normalized, forceRefresh: forceRefresh);
    _inFlight[normalized] = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlight[normalized], request)) {
        _inFlight.remove(normalized);
      }
    }
  }

  /// Reads a successful API cache record without falling through to the API.
  /// Used for proper nouns that teachers have explicitly looked up before.
  Future<DynamicDictionaryEntry?> getCachedEntry(String word) async {
    final normalized = _normalize(word);
    if (normalized.isEmpty) return null;
    try {
      return await _cache.getEntry(normalized);
    } catch (_) {
      return null;
    }
  }

  Future<DictionaryLookupResult> _lookupNormalized(
    String normalized, {
    required bool forceRefresh,
  }) async {
    try {
      final offlineLevel = _offlineLookup(normalized);
      if (offlineLevel != null) {
        return DictionaryLookupResult(
          status: DictionaryLookupStatus.found,
          entry: DynamicDictionaryEntry(
            word: normalized,
            phonetics: const [],
            meanings: const [],
            cefrLevel: offlineLevel,
            source: DictionaryEntrySource.offlineDictionary,
            cachedAt: _clock(),
          ),
        );
      }

      final cached = await _cache.getEntry(normalized);
      if (cached != null && !forceRefresh) {
        return DictionaryLookupResult(
          status: DictionaryLookupStatus.found,
          entry: cached,
        );
      }

      if (!forceRefresh) {
        final negativeUntil = await _cache.getNotFoundUntil(normalized);
        if (negativeUntil != null && negativeUntil.isAfter(_clock())) {
          return const DictionaryLookupResult(
            status: DictionaryLookupStatus.notFound,
          );
        }
        if (negativeUntil != null) await _cache.removeNotFound(normalized);
      }

      return await _fetch(
        normalized,
        previousEntry: cached,
        forceRefresh: forceRefresh,
      );
    } catch (error) {
      return DictionaryLookupResult(
        status: DictionaryLookupStatus.failed,
        error: error,
      );
    }
  }

  Future<DictionaryLookupResult> _fetch(
    String word, {
    required DynamicDictionaryEntry? previousEntry,
    required bool forceRefresh,
  }) async {
    try {
      final response = await _semaphore.withPermit(
        () => _client
            .get(
              Uri.https(apiHost, '/api/v2/entries/en/$word'),
              headers: const {'Accept': 'application/json'},
            )
            .timeout(requestTimeout),
      );

      if (response.statusCode == 404) {
        if (previousEntry != null) {
          return DictionaryLookupResult(
            status: DictionaryLookupStatus.found,
            entry: previousEntry,
          );
        }
        if (!forceRefresh) {
          await _cache.putNotFoundUntil(
            word,
            _clock().add(negativeCacheDuration),
          );
        }
        return const DictionaryLookupResult(
          status: DictionaryLookupStatus.notFound,
        );
      }

      if (response.statusCode != 200) {
        return DictionaryLookupResult(
          status: DictionaryLookupStatus.failed,
          entry: previousEntry,
          error: 'Dictionary API returned HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        return DictionaryLookupResult(
          status: DictionaryLookupStatus.failed,
          entry: previousEntry,
          error: 'Dictionary API response was not a list',
        );
      }
      final entry = _parseEntries(decoded, requestedWord: word);
      if (entry == null) {
        return DictionaryLookupResult(
          status: DictionaryLookupStatus.failed,
          entry: previousEntry,
          error: 'Dictionary API response contained no usable entry',
        );
      }

      await _cache.putEntry(entry);
      await _cache.removeNotFound(word);
      return DictionaryLookupResult(
        status: DictionaryLookupStatus.found,
        entry: entry,
      );
    } catch (error) {
      return DictionaryLookupResult(
        status: DictionaryLookupStatus.failed,
        entry: previousEntry,
        error: error,
      );
    }
  }

  DynamicDictionaryEntry? _parseEntries(
    List<dynamic> rawEntries, {
    required String requestedWord,
  }) {
    final entries = rawEntries.whereType<Map>().toList(growable: false);
    if (entries.isEmpty) return null;

    String? rootWord;
    final phonetics = <DictionaryPhonetic>[];
    final meanings = <DictionaryMeaning>[];

    for (final raw in entries) {
      final entry = Map<String, dynamic>.from(raw);
      final apiWord = entry['word']?.toString().trim();
      if (rootWord == null && apiWord != null && apiWord.isNotEmpty) {
        rootWord = apiWord.toLowerCase();
      }

      final topPhonetic = entry['phonetic']?.toString().trim();
      if (topPhonetic != null && topPhonetic.isNotEmpty) {
        _addPhonetic(phonetics, DictionaryPhonetic(text: topPhonetic));
      }
      final rawPhonetics = entry['phonetics'];
      if (rawPhonetics is List) {
        for (final rawPhonetic in rawPhonetics.whereType<Map>()) {
          final parsed = DictionaryPhonetic.fromJson(
            Map<String, dynamic>.from(rawPhonetic),
          );
          if (parsed.text.isNotEmpty || parsed.audio != null) {
            _addPhonetic(phonetics, parsed);
          }
        }
      }

      final rawMeanings = entry['meanings'];
      if (rawMeanings is List) {
        for (final rawMeaning in rawMeanings.whereType<Map>()) {
          final parsed = DictionaryMeaning.fromJson(
            Map<String, dynamic>.from(rawMeaning),
          );
          if (parsed.definitions.isNotEmpty) meanings.add(parsed);
        }
      }
    }

    if (phonetics.isEmpty && meanings.isEmpty) return null;
    return DynamicDictionaryEntry(
      word: rootWord ?? requestedWord,
      phonetics: List.unmodifiable(phonetics),
      meanings: List.unmodifiable(meanings),
      cefrLevel: null,
      source: DictionaryEntrySource.apiCache,
      cachedAt: _clock(),
    );
  }

  void _addPhonetic(
    List<DictionaryPhonetic> phonetics,
    DictionaryPhonetic value,
  ) {
    if (!phonetics.any(
      (item) => item.text == value.text && item.audio == value.audio,
    )) {
      phonetics.add(value);
    }
  }

  static String _normalize(String word) => word.trim().toLowerCase();

  void dispose() {
    _disposed = true;
    if (_ownsClient) _client.close();
  }
}

class _RequestSemaphore {
  _RequestSemaphore(this.limit);

  final int limit;
  int _active = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> withPermit<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_active < limit) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.addLast(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiters.isEmpty) {
      _active--;
    } else {
      _waiters.removeFirst().complete();
    }
  }
}
