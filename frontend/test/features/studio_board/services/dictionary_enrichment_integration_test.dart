import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_cache.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_enrichment_controller.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_profiler_service.dart';

http.Response _response(Object body, {int statusCode = 200}) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), statusCode);

PdfDgnlPassage _passage(String id, String rawText) => PdfDgnlPassage(
  id: id,
  pageNumber: 1,
  rawText: rawText,
  normalizedBounds: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.3),
  spans: const [],
  metrics: const {},
  clozeQuestions: const [],
  textProfile: TextProfilerService.profile(rawText),
);

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 100 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: 'Expected integration flow to finish');
}

void main() {
  test(
    'keeps the synchronous profile while unique lemma requests enrich cache only',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final cache = SharedPreferencesDictionaryCache(preferences: preferences);
      final gates = <String, Completer<http.Response>>{
        'quincunx': Completer<http.Response>(),
        'moiety': Completer<http.Response>(),
      };
      final requests = <http.Request>[];
      final client = MockClient((request) {
        requests.add(request);
        final lemma = request.url.pathSegments.last;
        return gates[lemma]!.future;
      });
      final controller = DictionaryEnrichmentController(
        dictionaryService: DictionaryService(
          cache: cache,
          offlineLookup: CefrDictionaryData.lookupCefr,
          client: client,
        ),
      );
      const rawText = 'Quincunx quincunx, moiety, quincunx.';
      final passage = _passage('integration', rawText);
      final expectedProfile = passage.textProfile!;
      final countsBefore = Map<String, int>.from(expectedProfile.cefrCounts);
      final levelsBefore = expectedProfile.tokens
          .map((token) => token.cefrLevel)
          .toList();

      final returnedProfile = controller.profileAndEnrich(passage);

      expect(returnedProfile, same(expectedProfile));
      expect(returnedProfile.originalText, rawText);
      expect(returnedProfile.cefrCounts, countsBefore);
      expect(gates.values.every((gate) => !gate.isCompleted), isTrue);

      await _waitFor(() => requests.length == 2);
      final requestedLemmas = requests
          .map((request) => request.url.pathSegments.last)
          .toSet();
      expect(requestedLemmas, {'quincunx', 'moiety'});
      for (final request in requests) {
        expect(request.body, isEmpty);
        expect(request.url.query, isEmpty);
        expect(request.url.toString(), isNot(contains(rawText)));
        expect(request.url.pathSegments.last, isNot(contains('quincunx,')));
      }

      gates['quincunx']!.complete(
        _response([
          {
            'word': 'quincunx',
            'phonetics': [
              {'text': '/quincunx/'},
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
        ]),
      );
      gates['moiety']!.complete(
        _response({'error': 'unavailable'}, statusCode: 503),
      );

      await _waitFor(
        () =>
            controller.statusFor('integration', 'quincunx') ==
                DictionaryEnrichmentStatus.found &&
            controller.statusFor('integration', 'moiety') ==
                DictionaryEnrichmentStatus.failed,
      );

      final enrichedEntry = controller.entryFor('integration', 'quincunx');
      expect(enrichedEntry?.cefrLevel, isNull);
      expect(enrichedEntry?.source.name, 'apiCache');
      expect(controller.entryFor('integration', 'moiety'), isNull);
      expect(returnedProfile.cefrCounts, countsBefore);
      expect(
        returnedProfile.tokens.map((token) => token.cefrLevel).toList(),
        levelsBefore,
      );
      expect(returnedProfile.cefrCounts['Unknown'], greaterThan(0));

      final reloadedCache = SharedPreferencesDictionaryCache(
        preferences: await SharedPreferences.getInstance(),
      );
      final persisted = await reloadedCache.getEntry('quincunx');
      expect(persisted?.source.name, 'apiCache');
      expect(persisted?.cefrLevel, isNull);
      expect(await reloadedCache.getEntry('moiety'), isNull);
    },
  );
}
