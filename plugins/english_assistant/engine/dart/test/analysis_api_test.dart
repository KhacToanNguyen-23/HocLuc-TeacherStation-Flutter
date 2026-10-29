import 'dart:convert';
import 'dart:io';

import 'package:english_assistant_engine/english_assistant_engine.dart';
import 'package:test/test.dart';

void main() {
  group('text analysis API', () {
    const sourceText =
        '😀 Never have I seen students take into account new evidence.';
    const request = {
      'schemaVersion': 1,
      'requestId': 'api-test-1',
      'selectionToken': 'selection-1',
      'source': {
        'kind': 'text',
        'offsetUnit': 'unicodeCodePoint',
        'text': sourceText,
      },
    };

    test(
      'returns profile, grammar/collocation spans and correlation tokens',
      () {
        final response = EnglishAssistantAnalysisApi().analyze(request);

        expect(response['status'], 'complete');
        expect(response['requestId'], 'api-test-1');
        expect(response['selectionToken'], 'selection-1');
        final analysis = response['analysis'] as Map<String, Object?>;
        expect(analysis['originalText'], sourceText);
        expect(analysis['statistics'], isA<Map>());
        expect(analysis['vocabularyCoverage'], isA<Map>());

        final spans = response['spans'] as List;
        expect(
          spans.any(
            (span) => span['style']['metadata']['ruleId'] == 'INVERSION_NEG',
          ),
          isTrue,
        );
        expect(
          spans.any((span) => span['text'] == 'take into account'),
          isTrue,
        );
        for (final span in spans) {
          expect(span['offsetUnit'], 'unicodeCodePoint');
          final range = span as Map<String, Object?>;
          expect(
            String.fromCharCodes(
              sourceText.runes.toList().sublist(
                range['start']! as int,
                range['end']! as int,
              ),
            ),
            range['text'],
          );
        }
      },
    );

    test(
      'retains all vocabulary and marks teaching priority on vocabulary spans',
      () {
        const passage =
            'The students conducted a detailed study of biotechnology and naringin.';
        final response = EnglishAssistantAnalysisApi().analyze({
          ...request,
          'requestId': 'vocabulary-contract',
          'source': {
            'kind': 'text',
            'offsetUnit': 'unicodeCodePoint',
            'text': passage,
          },
        });

        final analysis = response['analysis'] as Map<String, Object?>;
        final tokens = analysis['tokens'] as List;
        expect(tokens.any((token) => token['clean'] == 'the'), isTrue);
        expect(tokens.any((token) => token['clean'] == 'naringin'), isTrue);
        expect(tokens.any((token) => token['cefrLevel'] == 'Unknown'), isTrue);

        final reviewSpans = response['spans'] as List;
        final vocabularySpans = reviewSpans
            .where((span) => span['style']['id'] == 'vocabulary')
            .toList();
        final biotechnologySpan = vocabularySpans.firstWhere(
          (span) => span['text'] == 'biotechnology',
        );
        final naringinSpan = vocabularySpans.firstWhere(
          (span) => span['text'] == 'naringin',
        );
        expect(
          biotechnologySpan['style']['metadata']['isPedagogical'],
          isTrue,
        );
        expect(naringinSpan['style']['metadata']['isPedagogical'], isFalse);
      },
    );

    test(
      'reports unsupported parser-dependent grammar without false detections',
      () {
        const text = 'The document is written in English.';
        final response = EnglishAssistantAnalysisApi().analyze({
          ...request,
          'source': {
            'kind': 'text',
            'offsetUnit': 'unicodeCodePoint',
            'text': text,
          },
        });
        final spans = response['spans'] as List;

        expect(
          spans.where((span) => span['style']['id'] == 'grammar'),
          isEmpty,
        );
        expect(
          (response['diagnostics'] as List).join(' '),
          contains('PASSIVE_VOICE'),
        );
      },
    );

    test('rejects image and unknown source kinds', () {
      final response = EnglishAssistantAnalysisApi().analyze({
        ...request,
        'source': {'kind': 'image', 'data': 'AA=='},
      });

      expect(response['status'], 'invalidRequest');
      expect(response['spans'], isEmpty);
      expect(response['diagnostics'], isNotEmpty);
    });
  });

  group('analysis HTTP server', () {
    late AnalysisHttpServer server;
    late HttpClient client;
    late Uri baseUri;

    setUp(() async {
      server = AnalysisHttpServer();
      final port = await server.start(port: 0);
      baseUri = Uri.parse('http://127.0.0.1:$port');
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.close();
    });

    test('serves health and one text-only analyze route', () async {
      final health = await client.getUrl(baseUri.resolve('/health'));
      final healthResponse = await health.close();
      expect(healthResponse.statusCode, HttpStatus.ok);

      final request = await client.postUrl(baseUri.resolve('/api/analyze'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'schemaVersion': 1,
          'requestId': 'http-test',
          'source': {
            'kind': 'text',
            'offsetUnit': 'unicodeCodePoint',
            'text': 'Teachers take into account new evidence.',
          },
        }),
      );
      final response = await request.close();
      final payload = jsonDecode(await utf8.decoder.bind(response).join());
      expect(response.statusCode, HttpStatus.ok);
      expect(payload['status'], 'complete');
      expect(payload['requestId'], 'http-test');
    });

    test('rejects oversized bodies before JSON analysis', () async {
      final request = await client.postUrl(baseUri.resolve('/api/analyze'));
      request.headers.contentType = ContentType.json;
      request.write(' ' * (AnalysisHttpServer.maxRequestBytes + 1));
      final response = await request.close();
      expect(response.statusCode, HttpStatus.requestEntityTooLarge);
    });

    test(
      'returns method and route errors without leaking request content',
      () async {
        final response = await client.getUrl(baseUri.resolve('/missing'));
        final result = await response.close();
        expect(result.statusCode, HttpStatus.notFound);
      },
    );
  });
}
