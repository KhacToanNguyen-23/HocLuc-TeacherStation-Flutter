import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/presentation/widgets/text_profiler_dialog.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_cache.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_enrichment_controller.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dictionary_service.dart';

void main() {
  testWidgets(
    'dialog opens before API completes and closing keeps background cache write',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final cache = SharedPreferencesDictionaryCache(
        preferences: await SharedPreferences.getInstance(),
      );
      final response = Completer<http.Response>();
      var requestCount = 0;
      final service = DictionaryService(
        cache: cache,
        offlineLookup: CefrDictionaryData.lookupCefr,
        client: MockClient((_) {
          requestCount++;
          return response.future;
        }),
      );
      final controller = DictionaryEnrichmentController(
        dictionaryService: service,
      );
      final passage = PdfDgnlPassage(
        id: 'dialog-passage',
        pageNumber: 1,
        rawText: 'Quincunx is juice.',
        normalizedBounds: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.3),
        spans: const [],
        metrics: const {},
        clozeQuestions: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(
                  TextProfilerDialog.show(
                    context,
                    passage,
                    enrichmentController: controller,
                  ),
                ),
                child: const Text('Open profiler'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open profiler'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byType(TextProfilerDialog), findsOneWidget);
      expect(requestCount, 1);
      expect(response.isCompleted, isFalse);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      response.complete(
        http.Response(
          jsonEncode([
            {
              'word': 'quincunx',
              'meanings': [
                {
                  'partOfSpeech': 'noun',
                  'definitions': [
                    {'definition': 'A five-object arrangement.'},
                  ],
                },
              ],
            },
          ]),
          200,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();

      expect(await cache.getEntry('quincunx'), isNotNull);
      expect(tester.takeException(), isNull);
      expect(find.byType(TextProfilerDialog), findsNothing);
    },
  );
}
