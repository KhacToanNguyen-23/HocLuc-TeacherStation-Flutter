import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/meet_tutor/domain/models/tutor_models.dart';
import 'package:teaching_companion/features/meet_tutor/services/tutor_gateway.dart';

void main() {
  test(
    'environment mode sends no provider URL, model or key from the app',
    () async {
      final service = LocalService(
        base: 'http://127.0.0.1:1234',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-token"}', 200);
          }
          expect(request.headers['X-Companion-Token'], 'local-token');
          expect(jsonDecode(request.body)['config'], {'useEnvironment': true});
          expect(request.body, isNot(contains('apiKey')));
          expect(request.body, isNot(contains('baseUrl')));
          expect(request.body, isNot(contains('model')));
          return http.Response(
            '{"status":"tentative","confidence":"low","answer":"Maybe.","sources":[]}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final result = await CompanionTutorGateway(service).answer(
        const TutorConfig(baseUrl: '', model: '', useEnvironment: true),
        'Question',
        const TutorContext(revision: 0, currentPage: 1, sources: []),
      );
      expect(result.confidence, TutorConfidence.tentative);
    },
  );
}
