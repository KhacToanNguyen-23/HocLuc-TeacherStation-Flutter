import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/dynamic_dictionary_entry.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_cache.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_service.dart';

const _apiEntries = [
  {
    'word': 'quincunx',
    'phonetics': [
      {'text': '/ˈkwɪn.kʌŋks/', 'audio': 'https://audio.test/q.mp3'},
      {'text': '/kwɪnˈkʌŋks/'},
    ],
    'meanings': [
      {
        'partOfSpeech': 'noun',
        'definitions': [
          {
            'definition': 'An arrangement of five objects.',
            'example': 'The dots formed a quincunx.',
          },
        ],
      },
      {
        'partOfSpeech': 'adjective',
        'definitions': [
          {'definition': 'Arranged in a quincunx.'},
        ],
      },
    ],
  },
  {
    'word': 'quincunx',
    'meanings': [
      {
        'partOfSpeech': 'noun',
        'definitions': [
          {'definition': 'A second entry.'},
        ],
      },
    ],
  },
];

Future<SharedPreferencesDictionaryCache> _cache() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferencesDictionaryCache(
    preferences: await SharedPreferences.getInstance(),
  );
}

http.Response _ok(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

DynamicDictionaryEntry _cachedEntry(String word, DateTime cachedAt) =>
    DynamicDictionaryEntry(
      word: word,
      phonetics: const [],
      meanings: const [],
      cefrLevel: null,
      source: DictionaryEntrySource.apiCache,
      cachedAt: cachedAt,
    );

void main() {
  group('DictionaryService', () {
    test('offline CEFR hit returns offline entry and bypasses HTTP', () async {
      var requests = 0;
      final service = DictionaryService(
        cache: await _cache(),
        offlineLookup: (word) => word == 'juice' ? 'A2' : null,
        client: MockClient((_) async {
          requests++;
          return _ok(_apiEntries);
        }),
      );

      final result = await service.lookup('Juice');

      expect(result.status, DictionaryLookupStatus.found);
      expect(result.entry?.word, 'juice');
      expect(result.entry?.cefrLevel, 'A2');
      expect(result.entry?.source, DictionaryEntrySource.offlineDictionary);
      expect(requests, 0);
    });

    test('local cache hit avoids HTTP', () async {
      final cache = await _cache();
      await cache.putEntry(
        _cachedEntry('quincunx', DateTime.utc(2026, 10, 26)),
      );
      var requests = 0;
      final service = DictionaryService(
        cache: cache,
        offlineLookup: (_) => null,
        client: MockClient((_) async {
          requests++;
          return _ok(_apiEntries);
        }),
      );

      final result = await service.lookup('QUINCUNX');

      expect(result.status, DictionaryLookupStatus.found);
      expect(result.entry?.source, DictionaryEntrySource.apiCache);
      expect(requests, 0);
    });

    test(
      'parses multiple meanings and tolerates missing optional fields',
      () async {
        final service = DictionaryService(
          cache: await _cache(),
          offlineLookup: (_) => null,
          client: MockClient((_) async => _ok(_apiEntries)),
        );

        final result = await service.lookup('quincunx');
        final entry = result.entry!;

        expect(result.status, DictionaryLookupStatus.found);
        expect(entry.phonetics, hasLength(2));
        expect(entry.phonetics.last.audio, isNull);
        expect(entry.meanings, hasLength(3));
        expect(
          entry.meanings.map((m) => m.partOfSpeech),
          contains('adjective'),
        );
        expect(entry.meanings[1].definitions.single.example, isNull);
        expect(entry.cefrLevel, isNull);
        expect(entry.source, DictionaryEntrySource.apiCache);
      },
    );

    test(
      'normalizes and URL-encodes a single lemma in the request path',
      () async {
        Uri? requestedUri;
        final service = DictionaryService(
          cache: await _cache(),
          offlineLookup: (_) => null,
          client: MockClient((request) async {
            requestedUri = request.url;
            return _ok(_apiEntries);
          }),
        );

        await service.lookup('Ice Cream');

        expect(requestedUri?.host, 'api.dictionaryapi.dev');
        expect(
          requestedUri?.toString(),
          contains('/api/v2/entries/en/ice%20cream'),
        );
        expect(requestedUri?.query, isEmpty);
        expect(requestedUri?.toString(), isNot(contains('Ice Cream')));
      },
    );

    test(
      'coalesces simultaneous requests for normalized duplicate lemmas',
      () async {
        final response = Completer<http.Response>();
        var requests = 0;
        final service = DictionaryService(
          cache: await _cache(),
          offlineLookup: (_) => null,
          client: MockClient((_) {
            requests++;
            return response.future;
          }),
        );

        final first = service.lookup('Quincunx');
        final second = service.lookup('quincunx');
        await Future<void>.delayed(Duration.zero);
        expect(requests, 1);
        response.complete(_ok(_apiEntries));

        final results = await Future.wait([first, second]);
        expect(
          results.map((result) => result.status),
          everyElement(DictionaryLookupStatus.found),
        );
        expect(requests, 1);
      },
    );

    test('caps simultaneous requests at four across distinct lemmas', () async {
      final release = Completer<void>();
      var active = 0;
      var maximumActive = 0;
      final service = DictionaryService(
        cache: await _cache(),
        offlineLookup: (_) => null,
        client: MockClient((_) async {
          active++;
          if (active > maximumActive) maximumActive = active;
          await release.future;
          active--;
          return _ok(_apiEntries);
        }),
      );

      final pending = [
        for (var i = 0; i < 8; i++) service.lookup('rareword$i'),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(maximumActive, lessThanOrEqualTo(4));
      release.complete();
      expect(await Future.wait(pending), hasLength(8));
      expect(maximumActive, lessThanOrEqualTo(4));
    });

    test('timeout returns failed without throwing', () async {
      final response = Completer<http.Response>();
      final service = DictionaryService(
        cache: await _cache(),
        offlineLookup: (_) => null,
        client: MockClient((_) => response.future),
        requestTimeout: const Duration(milliseconds: 10),
      );

      final result = await service.lookup('quincunx');
      expect(result.status, DictionaryLookupStatus.failed);
      expect(result.entry, isNull);
    });

    test('caches automatic 404 for 24 hours', () async {
      final cache = await _cache();
      var now = DateTime.utc(2026, 10, 26, 4);
      var requests = 0;
      final service = DictionaryService(
        cache: cache,
        offlineLookup: (_) => null,
        clock: () => now,
        client: MockClient((_) async {
          requests++;
          return http.Response('Not found', 404);
        }),
      );

      expect(
        (await service.lookup('unlistedword')).status,
        DictionaryLookupStatus.notFound,
      );
      expect(
        (await service.lookup('unlistedword')).status,
        DictionaryLookupStatus.notFound,
      );
      expect(requests, 1);
      now = now.add(const Duration(hours: 24, milliseconds: 1));
      await service.lookup('unlistedword');
      expect(requests, 2);
    });

    test('refresh 404 keeps a cached success and cannot shadow it', () async {
      final cache = await _cache();
      final existing = _cachedEntry('quincunx', DateTime.utc(2026, 10, 1));
      await cache.putEntry(existing);
      var requests = 0;
      final service = DictionaryService(
        cache: cache,
        offlineLookup: (_) => null,
        client: MockClient((_) async {
          requests++;
          return http.Response('Not found', 404);
        }),
      );

      final refresh = await service.lookup('quincunx', forceRefresh: true);
      final laterLookup = await service.lookup('quincunx');

      expect(refresh.status, DictionaryLookupStatus.found);
      expect(refresh.entry?.cachedAt, existing.cachedAt);
      expect(laterLookup.status, DictionaryLookupStatus.found);
      expect(laterLookup.entry?.cachedAt, existing.cachedAt);
      expect(await cache.getNotFoundUntil('quincunx'), isNull);
      expect(requests, 1);
    });

    test('transient failures can retry on a later lookup', () async {
      var requests = 0;
      final service = DictionaryService(
        cache: await _cache(),
        offlineLookup: (_) => null,
        client: MockClient((_) async {
          requests++;
          return requests == 1
              ? http.Response('Unavailable', 503)
              : _ok(_apiEntries);
        }),
      );

      expect(
        (await service.lookup('quincunx')).status,
        DictionaryLookupStatus.failed,
      );
      expect(
        (await service.lookup('quincunx')).status,
        DictionaryLookupStatus.found,
      );
      expect(requests, 2);
    });

    test('malformed JSON returns failed without throwing', () async {
      final service = DictionaryService(
        cache: await _cache(),
        offlineLookup: (_) => null,
        client: MockClient((_) async => http.Response('{broken', 200)),
      );

      final result = await service.lookup('quincunx');
      expect(result.status, DictionaryLookupStatus.failed);
      expect(result.entry, isNull);
    });
  });

  test(
    'SharedPreferences cache survives reconstruction with metadata intact',
    () async {
      final cache = await _cache();
      final timestamp = DateTime.utc(2026, 10, 26, 3);
      await cache.putEntry(
        DynamicDictionaryEntry(
          word: 'quincunx',
          phonetics: const [DictionaryPhonetic(text: '/kwɪnˈkʌŋks/')],
          meanings: const [
            DictionaryMeaning(
              partOfSpeech: 'noun',
              definitions: [
                DictionaryDefinition(definition: 'A five-object arrangement.'),
              ],
            ),
          ],
          cefrLevel: null,
          source: DictionaryEntrySource.apiCache,
          cachedAt: timestamp,
        ),
      );

      final reloaded = SharedPreferencesDictionaryCache(
        preferences: await SharedPreferences.getInstance(),
      );
      final entry = await reloaded.getEntry('quincunx');

      expect(entry?.source, DictionaryEntrySource.apiCache);
      expect(entry?.cefrLevel, isNull);
      expect(entry?.phonetics.single.text, '/kwɪnˈkʌŋks/');
      expect(
        entry?.meanings.single.definitions.single.definition,
        'A five-object arrangement.',
      );
      expect(entry?.cachedAt, timestamp);
    },
  );
}
