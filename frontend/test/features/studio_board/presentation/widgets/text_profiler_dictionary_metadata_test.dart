import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/dynamic_dictionary_entry.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/domain/models/text_profile_models.dart';
import 'package:teaching_companion/features/studio_board/presentation/widgets/text_profiler_dialog.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_cache.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_enrichment_controller.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_profiler_service.dart';

const _apiEntry = [
  {
    'word': 'zorblaxian',
    'phonetics': [
      {'text': '/zorblaxian/'},
    ],
    'meanings': [
      {
        'partOfSpeech': 'noun',
        'definitions': [
          {
            'definition': 'A fictional technical term.',
            'example': 'The term appeared in a paper.',
          },
        ],
      },
    ],
  },
];

http.Response _response(Object body, {int statusCode = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), statusCode);

DynamicDictionaryEntry _cachedEntry({String definition = 'Old definition.'}) =>
    DynamicDictionaryEntry(
      word: 'naringin',
      phonetics: const [DictionaryPhonetic(text: '/nəˈrɪndʒɪn/')],
      meanings: [
        DictionaryMeaning(
          partOfSpeech: 'noun',
          definitions: [DictionaryDefinition(definition: definition)],
        ),
      ],
      cefrLevel: null,
      source: DictionaryEntrySource.apiCache,
      cachedAt: DateTime.utc(2026, 10, 26),
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
    return respond?.call(request) ?? _response(_apiEntry);
  });
  final controller = DictionaryEnrichmentController(
    dictionaryService: DictionaryService(
      cache: cache,
      offlineLookup: CefrDictionaryData.lookupCefr,
      client: client,
    ),
  );
  return (controller: controller, cache: cache, requests: requests);
}

PdfDgnlPassage _passage(String id, String text) => PdfDgnlPassage(
  id: id,
  pageNumber: 1,
  rawText: text,
  normalizedBounds: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.3),
  spans: const [],
  metrics: const {},
  clozeQuestions: const [],
  textProfile: TextProfilerService.profile(text),
);

Future<void> _waitFor(WidgetTester tester, bool Function() condition) async {
  await tester.runAsync(() async {
    for (var i = 0; i < 100 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
  await tester.pump();
  expect(condition(), isTrue, reason: 'Expected dictionary UI state to settle');
}

Future<void> _openVocabularyTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.pie_chart));
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'cached Unknown token shows dictionary marker and metadata without changing CEFR',
    (tester) async {
      _setViewport(tester);
      final harness = await _harness();
      await harness.cache.putEntry(
        DynamicDictionaryEntry.fromJson({
          'word': 'zorblaxian',
          'phonetics': [
            {'text': '/zorblaxian/'},
          ],
          'meanings': [
            {
              'partOfSpeech': 'noun',
              'definitions': [
                {
                  'definition': 'A fictional technical term.',
                  'example': 'The term appeared in a paper.',
                },
              ],
            },
          ],
          'cefrLevel': null,
          'source': 'apiCache',
          'cachedAt': DateTime.utc(2026, 10, 26).toIso8601String(),
        }),
      );
      final passage = _passage('cached', 'Zorblaxian.');
      final profile = harness.controller.profileAndEnrich(passage);
      await _waitFor(
        tester,
        () => harness.controller.entryFor('cached', 'zorblaxian') != null,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextProfilerDialog(
              passage: passage,
              profile: profile,
              enrichmentController: harness.controller,
            ),
          ),
        ),
      );
      await _openVocabularyTab(tester);
      await tester.tap(find.text('Zorblaxian').first);
      await tester.pumpAndSettle();

      expect(
        find.byTooltip(
          'Dictionary metadata found; CEFR and difficulty unchanged',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('api-dictionary-entry-token')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('extended-advanced-token')), findsNothing);
      expect(
        find.text('Dictionary metadata found; CEFR remains Unknown'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Unique dictionary entries found: 1 · API entries do not change CEFR or difficulty.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('A fictional technical term.'),
        findsOneWidget,
      );
      expect(
        find.textContaining('The term appeared in a paper.'),
        findsOneWidget,
      );
      expect(find.text('/zorblaxian/'), findsOneWidget);
      expect(find.text('CEFR Unknown'), findsOneWidget);
      expect(profile.cefrCounts['Unknown'], 1);
      expect(profile.tokens.single.cefrLevel, 'Unknown');
      expect(harness.requests, isEmpty);
    },
  );

  testWidgets(
    'long dictionary definitions scroll without overflowing the dialog',
    (tester) async {
      _setViewport(tester);
      final harness = await _harness();
      await harness.cache.putEntry(
        DynamicDictionaryEntry(
          word: 'zorblaxian',
          phonetics: const [],
          meanings: [
            DictionaryMeaning(
              partOfSpeech: 'noun',
              definitions: List.generate(
                18,
                (index) => DictionaryDefinition(
                  definition:
                      'Definition ${index + 1}: a long dictionary explanation that should remain inside the scrollable metadata area.',
                ),
              ),
            ),
          ],
          cefrLevel: null,
          source: DictionaryEntrySource.apiCache,
          cachedAt: DateTime.utc(2026, 10, 26),
        ),
      );
      final passage = _passage('long-entry', 'It is Zorblaxian.');
      final profile = harness.controller.profileAndEnrich(passage);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextProfilerDialog(
              passage: passage,
              profile: profile,
              enrichmentController: harness.controller,
            ),
          ),
        ),
      );
      await _openVocabularyTab(tester);
      await tester.tap(find.text('Zorblaxian').first);
      await _waitFor(
        tester,
        () => harness.controller.entryFor('long-entry', 'zorblaxian') != null,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final lastDefinition = find.textContaining('Definition 18:');
      final detailsScroll = find.descendant(
        of: find.byKey(const Key('dictionary-details-scroll')),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        lastDefinition,
        180,
        scrollable: detailsScroll,
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .getRect(lastDefinition)
            .overlaps(
              tester.getRect(
                find.byKey(const Key('dictionary-details-scroll')),
              ),
            ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected proper noun can be looked up manually and remains CEFR Unknown',
    (tester) async {
      _setViewport(tester);
      final harness = await _harness();
      final passage = _passage('manual', 'It is Zorblaxian.');
      final profile = harness.controller.profileAndEnrich(passage);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextProfilerDialog(
              passage: passage,
              profile: profile,
              enrichmentController: harness.controller,
            ),
          ),
        ),
      );
      await _openVocabularyTab(tester);
      await tester.tap(find.text('Zorblaxian').first);
      await tester.pumpAndSettle();

      expect(harness.requests, isEmpty);
      await tester.tap(find.text('Look up dictionary entry'));
      await tester.pumpAndSettle();
      await _waitFor(
        tester,
        () => harness.controller.entryFor('manual', 'zorblaxian') != null,
      );
      await tester.pumpAndSettle();

      expect(harness.requests, hasLength(1));
      expect(
        find.textContaining('A fictional technical term.'),
        findsOneWidget,
      );
      expect(find.text('CEFR Unknown'), findsOneWidget);
      expect(profile.cefrCounts['Unknown'], 1);
      expect(
        profile.tokens
            .singleWhere((token) => token.lemma == 'zorblaxian')
            .cefrLevel,
        'Unknown',
      );

      harness.controller.deactivate('manual');
      final laterPassage = _passage('manual-later', 'It is Zorblaxian.');
      final laterProfile = harness.controller.profileAndEnrich(laterPassage);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextProfilerDialog(
              passage: laterPassage,
              profile: laterProfile,
              enrichmentController: harness.controller,
            ),
          ),
        ),
      );
      await _openVocabularyTab(tester);
      await tester.tap(find.text('Zorblaxian').first);
      await _waitFor(
        tester,
        () => harness.controller.entryFor('manual-later', 'zorblaxian') != null,
      );
      await tester.pumpAndSettle();

      expect(harness.requests, hasLength(1));
      expect(
        find.byTooltip(
          'Dictionary metadata found; CEFR and difficulty unchanged',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('A fictional technical term.'),
        findsOneWidget,
      );
      expect(laterProfile.cefrCounts['Unknown'], 1);
    },
  );

  testWidgets(
    'failed manual refresh preserves cached metadata and does not assign CEFR',
    (tester) async {
      _setViewport(tester);
      final harness = await _harness(
        respond: (_) async => _response([], statusCode: 404),
      );
      await harness.cache.putEntry(_cachedEntry());
      final passage = _passage('refresh', 'It is Naringin.');
      final profile = harness.controller.profileAndEnrich(passage);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextProfilerDialog(
              passage: passage,
              profile: profile,
              enrichmentController: harness.controller,
            ),
          ),
        ),
      );
      await _openVocabularyTab(tester);
      await tester.tap(find.text('Naringin').first);
      await tester.pumpAndSettle();
      await _waitFor(
        tester,
        () => harness.controller.entryFor('refresh', 'naringin') != null,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Old definition.'), findsOneWidget);
      await tester.tap(find.text('Refresh dictionary entry'));
      await tester.pumpAndSettle();
      await _waitFor(
        tester,
        () =>
            harness.controller.statusFor('refresh', 'naringin') ==
            DictionaryEnrichmentStatus.found,
      );
      await tester.pumpAndSettle();

      expect(harness.requests, hasLength(1));
      expect(find.textContaining('Old definition.'), findsOneWidget);
      expect(find.text('CEFR Unknown'), findsOneWidget);
      expect(profile.cefrCounts['Unknown'], 1);
    },
  );

  testWidgets('known CEFR tokens do not show the Unknown dictionary panel', (
    tester,
  ) async {
    _setViewport(tester);
    final harness = await _harness();
    final passage = _passage('known', 'Juice.');
    final profile = harness.controller.profileAndEnrich(passage);
    expect(profile.tokens.single.cefrLevel, 'A1');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextProfilerDialog(
            passage: passage,
            profile: profile,
            enrichmentController: harness.controller,
          ),
        ),
      ),
    );
    await _openVocabularyTab(tester);
    await tester.tap(find.text('Juice').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dictionary-manual-action')), findsNothing);
    expect(find.textContaining('CEFR remains Unknown'), findsNothing);
    expect(harness.requests, isEmpty);
  });

  testWidgets('recognized-unrated offline word stays Unknown and is marked', (
    tester,
  ) async {
    _setViewport(tester);
    final harness = await _harness(
      respond: (_) async => _response([], statusCode: 404),
    );
    final passage = _passage('recognized-unrated', 'Noodle and zorblaxian.');
    final profile = harness.controller.profileAndEnrich(passage);
    final noodle = profile.tokens.singleWhere(
      (token) => token.lemma == 'noodle',
    );
    final miss = profile.tokens.singleWhere(
      (token) => token.lemma == 'zorblaxian',
    );
    expect(noodle.cefrLevel, 'Unknown');
    expect(noodle.isRecognizedUnrated, isTrue);
    expect(miss.lexicalStatus, LexicalStatus.notInLexicon);
    expect(profile.cefrCounts['Unknown'], 2);
    expect(profile.recognizedUnratedCount, 1);
    expect(profile.notInLexiconCount, 1);

    await _waitFor(
      tester,
      () =>
          harness.controller.statusFor('recognized-unrated', 'noodle') ==
          DictionaryEnrichmentStatus.notFound,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextProfilerDialog(
            passage: passage,
            profile: profile,
            enrichmentController: harness.controller,
          ),
        ),
      ),
    );
    await _openVocabularyTab(tester);

    expect(
      find.byTooltip('Recognized offline; CEFR level unavailable'),
      findsNWidgets(2),
    );
    expect(find.byKey(const Key('recognized-unrated-marker')), findsOneWidget);
    await tester.tap(find.text('Noodle').first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('recognized-unrated-detail-marker')),
      findsOneWidget,
    );
    expect(find.text('Đã nhận diện: 1 • Chưa có mục từ: 1'), findsOneWidget);
    expect(find.text('CEFR Unknown'), findsOneWidget);
    expect(profile.cefrCounts['Unknown'], 2);
  });

  testWidgets('manual lookup bypasses a cached automatic 404', (tester) async {
    _setViewport(tester);
    var requestCount = 0;
    final harness = await _harness(
      respond: (_) async {
        requestCount++;
        return requestCount == 1
            ? _response([], statusCode: 404)
            : _response([
                {
                  'word': 'naringin',
                  'meanings': [
                    {
                      'partOfSpeech': 'noun',
                      'definitions': [
                        {'definition': 'A citrus flavonoid.'},
                      ],
                    },
                  ],
                },
              ]);
      },
    );
    final passage = _passage('negative-cache', 'Naringin.');
    final profile = harness.controller.profileAndEnrich(passage);
    await _waitFor(
      tester,
      () =>
          harness.controller.statusFor('negative-cache', 'naringin') ==
          DictionaryEnrichmentStatus.notFound,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextProfilerDialog(
            passage: passage,
            profile: profile,
            enrichmentController: harness.controller,
          ),
        ),
      ),
    );
    await _openVocabularyTab(tester);
    await tester.tap(find.text('Naringin').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look up dictionary entry'));
    await tester.pumpAndSettle();
    await _waitFor(
      tester,
      () => harness.controller.entryFor('negative-cache', 'naringin') != null,
    );

    expect(harness.requests, hasLength(2));
    expect(find.textContaining('A citrus flavonoid.'), findsOneWidget);
    expect(profile.tokens.single.cefrLevel, 'Unknown');
    expect(profile.cefrCounts['Unknown'], 1);
  });
}
