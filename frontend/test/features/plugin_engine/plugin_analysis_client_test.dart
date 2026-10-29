import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_analysis_client.dart';

void main() {
  late HttpServer server;
  late Future<void> Function(HttpRequest) handler;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) => handler(request));
  });

  tearDown(() => server.close(force: true));

  test(
    'sends text-only schema and accepts correlated code-point spans',
    () async {
      handler = (request) async {
        final body = jsonDecode(await utf8.decodeStream(request)) as Map;
        expect(body['source']['kind'], 'text');
        expect(body['source']['offsetUnit'], 'unicodeCodePoint');
        expect(body['source']['text'], 'A 😀 word');
        request.response
          ..statusCode = HttpStatus.ok
          ..write(
            jsonEncode({
              'schemaVersion': 1,
              'requestId': body['requestId'],
              'selectionToken': body['selectionToken'],
              'offsetUnit': 'unicodeCodePoint',
              'status': 'complete',
              'spans': [
                {
                  'start': 4,
                  'end': 8,
                  'text': 'word',
                  'style': {'id': 'vocabulary', 'metadata': {}},
                },
              ],
            }),
          );
        await request.response.close();
      };

      final response = await PluginAnalysisClient().analyze(
        port: server.port,
        text: 'A 😀 word',
        requestId: 'request-1',
        selectionToken: 'selection-1',
      );
      expect(response['status'], 'complete');
    },
  );

  test('rejects stale selection correlation and spans beyond source', () async {
    handler = (request) async {
      final body = jsonDecode(await utf8.decodeStream(request)) as Map;
      request.response
        ..statusCode = HttpStatus.ok
        ..write(
          jsonEncode({
            'schemaVersion': 1,
            'requestId': body['requestId'],
            'selectionToken': 'stale',
            'offsetUnit': 'unicodeCodePoint',
            'status': 'complete',
            'spans': [
              {
                'start': 0,
                'end': 200,
                'style': {'id': 'grammar', 'metadata': {}},
              },
            ],
          }),
        );
      await request.response.close();
    };
    await expectLater(
      PluginAnalysisClient().analyze(
        port: server.port,
        text: 'text',
        requestId: 'request-2',
        selectionToken: 'selection-2',
      ),
      throwsFormatException,
    );
  });
}
