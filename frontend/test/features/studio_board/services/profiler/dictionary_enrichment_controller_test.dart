import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/domain/models/text_profile_models.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_cache.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_enrichment_controller.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_profiler_service.dart';

const _response = [
  {
    'word': 'quincunx',
    'phonetics': [
      {'text': '/ˈkwɪn.kʌŋks/'},
    ],
    'meanings': [
      {
        'partOfSpeech': 'noun',
        'definitions': [
          {'definition': 'An arrangement of five objects.'},
        ],
      },
    ],
  },
];

http.Response _apiResponse(Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200);

PdfDgnlPassage _passage(
  String id,
  String rawText, {
  TextProfileResult? profile,
}) => PdfDgnlPassage(
  id: id,
  pageNumber: 1,
  rawText: rawText,
  normalizedBounds: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.3),
  spans: const [],
  metrics: const {},
  clozeQuestions: const [],
  textProfile: profile,
);

Future<
  ({
    DictionaryEnrichmentController controller,
    SharedPreferencesDictionaryCache cache,
    List<Uri> requests,
  })
>
_harness({
  Future<http.Response> Function(http.Request request)? respond,
}) async {
  SharedPreferences.setMockInitialValues({});
  final cache = SharedPreferencesDictionaryCache(
    preferences: await SharedPreferences.getInstance(),
  );
  final requests = <Uri>[];
  final client = MockClient((request) async {
    requests.add(request.url);
    return respond == null ? _apiResponse(_response) : respond(request);
  });
  final service = DictionaryService(
    cache: cache,
    offlineLookup: CefrDictionaryData.lookupCefr,
    client: client,
    requestTimeout: const Duration(milliseconds: 100),
  );
  return (
    controller: DictionaryEnrichmentController(dictionaryService: service),
    cache: cache,
    requests: requests,
  );
}

Future<void> _waitFor(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Expected async enrichment to finish');
}

Future<void> _waitForCache(
  SharedPreferencesDictionaryCache cache,
  String word,
) async {
  for (var i = 0; i < 100; i++) {
    if (await cache.getEntry(word) != null) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Expected $word to be persisted in the dictionary cache');
}

void main() {
  group('DictionaryEnrichmentController', () {
    test(
      'stored profile returns synchronously and enriches in background',
      () async {
        final gate = Completer<http.Response>();
        final harness = await _harness(respond: (_) => gate.future);
        final stored = TextProfilerService.profile('Quincunx and quincunx.');
        final passage = _passage(
          'stored',
          stored.originalText,
          profile: stored,
        );

        final returned = harness.controller.profileAndEnrich(passage);

        expect(returned, same(stored));
        expect(returned, isA<TextProfileResult>());
        expect(harness.controller.activePassageId, 'stored');
        await _waitFor(() => harness.requests.isNotEmpty);
        expect(gate.isCompleted, isFalse);
        expect(harness.requests, hasLength(1));
        expect(harness.requests.single.pathSegments.last, 'quincunx');

        gate.complete(_apiResponse(_response));
        await _waitFor(
          () => harness.controller.entryFor('stored', 'quincunx') != null,
        );
        expect(returned.cefrCounts['Unknown'], greaterThan(0));
        expect(returned.tokens.first.cefrLevel, 'Unknown');
      },
    );

    test('fallback profile is created and returned synchronously', () async {
      final gate = Completer<http.Response>();
      final harness = await _harness(respond: (_) => gate.future);
      final passage = _passage('fallback', 'Quincunx is juice.');

      final returned = harness.controller.profileAndEnrich(passage);

      expect(returned, isA<TextProfileResult>());
      expect(returned.originalText, passage.rawText);
      expect(harness.controller.activePassageId, 'fallback');
      await _waitFor(() => harness.requests.isNotEmpty);
      expect(gate.isCompleted, isFalse);
      gate.complete(_apiResponse(_response));
      await _waitFor(
        () => harness.controller.entryFor('fallback', 'quincunx') != null,
      );
    });

    test(
      'unresolved hyphenated compounds are enriched without difficulty promotion',
      () async {
        final harness = await _harness();
        final profile = TextProfilerService.profile(
          'Quincunx-like is unusual.',
        );
        final token = profile.tokens.firstWhere(
          (item) => item.surface == 'Quincunx-like',
        );

        expect(token.cefrLevel, 'Unknown');
        expect(token.lemma, 'quincunx-like');
        harness.controller.profileAndEnrich(
          _passage('compound', profile.originalText, profile: profile),
        );

        await _waitFor(() => harness.requests.isNotEmpty);
        expect(harness.requests.single.pathSegments.last, 'quincunx-like');
        await _waitFor(
          () =>
              harness.controller.entryFor('compound', 'quincunx-like') != null,
        );
        expect(
          harness.controller.hasApiDictionaryEntry('compound', token),
          isTrue,
        );
        expect(
          harness.controller.apiDictionaryEntryCount('compound', profile),
          1,
        );
        expect(harness.controller.advancedDifficultyPercent(profile), 0);
      },
    );

    test(
      'deduplicates repeated unknown words and is idempotent for same passage',
      () async {
        final gate = Completer<http.Response>();
        final harness = await _harness(respond: (_) => gate.future);
        final profile = TextProfilerService.profile('Quincunx and quincunx.');
        final passage = _passage(
          'duplicate',
          profile.originalText,
          profile: profile,
        );

        final first = harness.controller.profileAndEnrich(passage);
        final repeated = harness.controller.profileAndEnrich(passage);
        expect(repeated, same(first));
        await _waitFor(() => harness.requests.isNotEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(harness.requests, hasLength(1));

        gate.complete(_apiResponse(_response));
        await _waitFor(
          () => harness.controller.entryFor('duplicate', 'quincunx') != null,
        );
        expect(
          harness.controller.apiDictionaryEntryCount('duplicate', first),
          1,
        );
      },
    );

    test(
      'skips likely proper nouns but allows sentence-initial lowercase misses',
      () async {
        final harness = await _harness();
        final capitalizedOfflineProfile = TextProfilerService.profile(
          'It is Juice.',
        );
        final juice = capitalizedOfflineProfile.tokens.singleWhere(
          (token) => token.lemma == 'juice',
        );
        expect(juice.isProperNoun, isTrue);
        expect(juice.cefrLevel, 'Unknown');
        harness.controller.profileAndEnrich(
          _passage(
            'capitalized-offline',
            capitalizedOfflineProfile.originalText,
            profile: capitalizedOfflineProfile,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(harness.requests, isEmpty);

        final properNounProfile = TextProfilerService.profile(
          'It is Naringin.',
        );
        final properNounPassage = _passage(
          'proper',
          properNounProfile.originalText,
          profile: properNounProfile,
        );
        harness.controller.profileAndEnrich(properNounPassage);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(harness.requests, isEmpty);

        final sentenceInitialProfile = TextProfilerService.profile(
          'Naringin is juice.',
        );
        final sentenceInitialPassage = _passage(
          'sentence-start',
          sentenceInitialProfile.originalText,
          profile: sentenceInitialProfile,
        );
        harness.controller.profileAndEnrich(sentenceInitialPassage);

        await _waitFor(() => harness.requests.isNotEmpty);
        expect(
          harness.requests.map((uri) => uri.pathSegments.last),
          contains('naringin'),
        );
      },
    );

    test('looks up recognized derivations by their surface lexeme', () async {
      final harness = await _harness(
        respond: (_) async => _apiResponse([
          {
            'word': 'bitterness',
            'phonetics': [
              {'text': '/b\u026at\u0259n\u0259s/'},
            ],
            'meanings': [
              {
                'partOfSpeech': 'noun',
                'definitions': [
                  {'definition': 'The quality or state of being bitter.'},
                ],
              },
            ],
          },
        ]),
      );
      final profile = TextProfilerService.profile('Bitterness matters.');
      final token = profile.tokens.firstWhere(
        (item) => item.surface == 'Bitterness',
      );
      final countsBefore = Map<String, int>.from(profile.cefrCounts);

      expect(token.lexicalStatus, LexicalStatus.recognizedUnrated);
      expect(token.cefrLevel, 'Unknown');
      expect(token.lemma, 'bitterness');
      harness.controller.profileAndEnrich(
        _passage(
          'derivational-unknown',
          profile.originalText,
          profile: profile,
        ),
      );

      await _waitFor(
        () =>
            harness.controller.entryFor('derivational-unknown', 'bitterness') !=
            null,
      );
      expect(harness.requests.map((uri) => uri.pathSegments.last), [
        'bitterness',
      ]);
      expect(profile.cefrCounts, countsBefore);
      expect(token.cefrLevel, 'Unknown');
    });

    test('API enrichment does not mutate tokens or CEFR counts', () async {
      final gate = Completer<http.Response>();
      final harness = await _harness(respond: (_) => gate.future);
      final profile = TextProfilerService.profile('Quincunx and juice.');
      final countsBefore = Map<String, int>.from(profile.cefrCounts);
      final tokenLevelsBefore = profile.tokens
          .map((token) => token.cefrLevel)
          .toList();

      final returned = harness.controller.profileAndEnrich(
        _passage('immutable', profile.originalText, profile: profile),
      );
      expect(returned, same(profile));
      await _waitFor(() => harness.requests.isNotEmpty);
      gate.complete(_apiResponse(_response));
      await _waitFor(
        () => harness.controller.entryFor('immutable', 'quincunx') != null,
      );

      expect(profile.cefrCounts, countsBefore);
      expect(
        profile.tokens.map((token) => token.cefrLevel).toList(),
        tokenLevelsBefore,
      );
      expect(profile.cefrCounts['Unknown'], greaterThan(0));
    });

    test('API metadata does not change advanced difficulty', () async {
      final harness = await _harness();
      final profile = TextProfilerService.profile('Quincunx and juice.');
      final token = profile.tokens.singleWhere(
        (item) => item.lemma == 'quincunx',
      );
      final countsBefore = Map<String, int>.from(profile.cefrCounts);
      final difficultyBefore = harness.controller.advancedDifficultyPercent(
        profile,
      );

      harness.controller.profileAndEnrich(
        _passage('extended', profile.originalText, profile: profile),
      );
      await _waitFor(
        () => harness.controller.entryFor('extended', 'quincunx') != null,
      );

      expect(
        harness.controller.hasApiDictionaryEntry('extended', token),
        isTrue,
      );
      expect(
        harness.controller.apiDictionaryEntryCount('extended', profile),
        1,
      );
      expect(
        harness.controller.advancedDifficultyPercent(profile),
        difficultyBefore,
      );
      expect(profile.cefrCounts, countsBefore);
      expect(token.cefrLevel, 'Unknown');

      final properProfile = TextProfilerService.profile('It is Naringin.');
      final properToken = properProfile.tokens.singleWhere(
        (item) => item.lemma == 'naringin',
      );
      expect(properToken.isProperNoun, isTrue);
      expect(
        harness.controller.hasApiDictionaryEntry('extended', properToken),
        isFalse,
      );
    });

    test('404 results stay out of the estimated advanced group', () async {
      final harness = await _harness(
        respond: (_) async => http.Response('Not found', 404),
      );
      final profile = TextProfilerService.profile('Quincunx and juice.');
      final token = profile.tokens.singleWhere(
        (item) => item.lemma == 'quincunx',
      );

      harness.controller.profileAndEnrich(
        _passage('missing-entry', profile.originalText, profile: profile),
      );
      await _waitFor(
        () =>
            harness.controller.statusFor('missing-entry', 'quincunx') ==
            DictionaryEnrichmentStatus.notFound,
      );

      expect(
        harness.controller.hasApiDictionaryEntry('missing-entry', token),
        isFalse,
      );
      expect(
        harness.controller.apiDictionaryEntryCount('missing-entry', profile),
        0,
      );
    });

    test(
      'stale passage response caches but does not notify or update current passage',
      () async {
        final gates = <String, Completer<http.Response>>{
          'quincunx': Completer<http.Response>(),
          'moiety': Completer<http.Response>(),
        };
        final harness = await _harness(
          respond: (request) => gates[request.url.pathSegments.last]!.future,
        );
        final first = TextProfilerService.profile('Quincunx is juice.');
        harness.controller.profileAndEnrich(
          _passage('old', first.originalText, profile: first),
        );
        await _waitFor(
          () => harness.requests.any(
            (uri) => uri.pathSegments.last == 'quincunx',
          ),
        );

        final second = TextProfilerService.profile('Moiety is juice.');
        harness.controller.profileAndEnrich(
          _passage('current', second.originalText, profile: second),
        );
        await _waitFor(
          () =>
              harness.requests.any((uri) => uri.pathSegments.last == 'moiety'),
        );
        expect(harness.controller.activePassageId, 'current');

        var notifications = 0;
        harness.controller.addListener(() => notifications++);
        gates['quincunx']!.complete(_apiResponse(_response));
        await _waitForCache(harness.cache, 'quincunx');

        expect(await harness.cache.getEntry('quincunx'), isNotNull);
        expect(harness.controller.entryFor('old', 'quincunx'), isNull);
        expect(harness.controller.entryFor('current', 'quincunx'), isNull);
        expect(harness.controller.activePassageId, 'current');
        expect(notifications, 0);

        gates['moiety']!.complete(
          _apiResponse([
            {
              'word': 'moiety',
              'meanings': [
                {
                  'partOfSpeech': 'noun',
                  'definitions': [
                    {'definition': 'A part.'},
                  ],
                },
              ],
            },
          ]),
        );
        await _waitFor(
          () => harness.controller.entryFor('current', 'moiety') != null,
        );
        expect(await harness.cache.getEntry('moiety'), isNotNull);
      },
    );
  });
}
