import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_gateway.dart';

void main() {
  const config = TutorConfig(
    baseUrl: 'https://provider.test/v1',
    model: 'model',
    apiKey: 'secret',
  );
  test(
    'lesson subject is forwarded and out-of-scope response uses fixed text',
    () async {
      final service = LocalService(
        base: 'http://127.0.0.1:1234',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-token"}', 200);
          }
          expect(jsonDecode(request.body)['lessonSubject'], 'Mathematics');
          return http.Response(
            '{"status":"out_of_scope","answer":"Do not expose unrelated advice"}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await CompanionTutorGateway(service).answer(
        config,
        'What to eat?',
        const TutorContext(
          revision: 0,
          currentPage: 1,
          sources: [],
          lessonSubject: 'Mathematics',
        ),
      );
      expect(result.confidence, TutorConfidence.outOfScope);
      expect(result.answer, 'Không thuộc phạm vi bài giảng.');
    },
  );
  test(
    'uses companion token and bounded evidence contract with per-request config',
    () async {
      final calls = <http.Request>[];
      final service = LocalService(
        base: 'http://127.0.0.1:1234',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-token"}', 200);
          }
          calls.add(request);
          return http.Response(
            jsonEncode({
              'status': 'answered',
              'answer': 'Triangles have three sides.',
              'sources': [
                {'id': 'p1', 'quote': 'Triangles have three sides.'},
              ],
              'reason': '',
            }),
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await CompanionTutorGateway(service).answer(
        config,
        'What is a triangle?',
        const TutorContext(
          revision: 1,
          currentPage: 1,
          sources: [
            TutorSource(
              id: 'p1',
              label: 'Page 1',
              text: 'Triangles have three sides.',
            ),
          ],
        ),
      );
      expect(calls.single.headers['X-Companion-Token'], 'local-token');
      expect(calls.single.url.path, '/api/tutor/answer');
      expect(jsonDecode(calls.single.body)['config']['model'], 'model');
      expect(result.evidence['p1'], 'Triangles have three sides.');
    },
  );
  test(
    'does not surface provider body with credentials and never falls back',
    () async {
      int requests = 0;
      final service = LocalService(
        base: 'http://127.0.0.1:1234',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-token"}', 200);
          }
          requests++;
          return http.Response('provider private secret', 502);
        }),
      );
      addTearDown(service.dispose);
      await expectLater(
        CompanionTutorGateway(service).test(config),
        throwsA(
          predicate(
            (Object e) =>
                e.toString().contains('502') &&
                !e.toString().contains('private secret'),
          ),
        ),
      );
      expect(requests, 1);
    },
  );
  test('review response cannot accidentally become an answer', () async {
    final service = LocalService(
      base: 'http://127.0.0.1:1234',
      client: MockClient((request) async {
        if (request.url.path == '/api/bootstrap') {
          return http.Response('{"token":"local-token"}', 200);
        }
        return http.Response(
          '{"status":"review","answer":"bad answer","sources":[{"id":"p1","quote":"bad answer"}]}',
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final result = await CompanionTutorGateway(service).answer(
      config,
      'Why?',
      const TutorContext(revision: 0, currentPage: 1, sources: []),
    );
    expect(result.evidence, isEmpty);
    expect(result.supportedBy([]), false);
    expect(result.canAutoSend([]), false);
  });

  test(
    'only explicit tentative low status permits uncited inferred answers',
    () async {
      var payload = <String, dynamic>{
        'status': 'tentative',
        'confidence': 'low',
        'answer': 'It may depend on normal atmospheric pressure.',
        'sources': [],
      };
      final service = LocalService(
        base: 'http://127.0.0.1:1234',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-token"}', 200);
          }
          return http.Response(jsonEncode(payload), 200);
        }),
      );
      addTearDown(service.dispose);
      final gateway = CompanionTutorGateway(service);
      const context = TutorContext(revision: 0, currentPage: 1, sources: []);
      final result = await gateway.answer(config, 'Why?', context);
      expect(result.confidence, TutorConfidence.tentative);
      expect(result.canAutoSend([]), true);
      for (final bad in [
        {'status': 'review', 'confidence': 'low'},
        {'status': 'answered', 'confidence': 'low'},
        {'status': 'tentative', 'confidence': 'high'},
        {'status': 'tentative'},
      ]) {
        payload = {
          ...bad,
          'answer': 'Must not bypass validation.',
          'sources': [],
        };
        expect(
          (await gateway.answer(config, 'Why?', context)).canAutoSend([]),
          false,
        );
      }
      payload = {
        'status': 'tentative',
        'confidence': 'low',
        'answer': 'Maybe.',
        'sources': [
          {'id': 'p1', 'quote': 'An existing sentence.'},
          {'id': 'p1', 'quote': 'An existing sentence.'},
        ],
      };
      expect(
        (await gateway.answer(config, 'Why?', context)).confidence,
        TutorConfidence.unavailable,
      );
    },
  );
}
