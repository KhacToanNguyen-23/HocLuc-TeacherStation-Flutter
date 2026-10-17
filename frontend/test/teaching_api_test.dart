import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/services/local_service.dart';

void main() {
  test(
    'active session lookup uses companion token and preserves failure',
    () async {
      final local = LocalService(
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local"}', 200);
          }
          expect(request.headers['X-Companion-Token'], 'local');
          return http.Response('{}', 503);
        }),
      );
      await expectLater(
        local.getActiveClassroom(strict: true),
        throwsStateError,
      );
      local.dispose();
    },
  );

  test(
    'registration retries only after local session expired and keeps same payload',
    () async {
      var bootstraps = 0, posts = 0;
      final local = LocalService(
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            bootstraps++;
            return http.Response(
              jsonEncode({'token': 'local-$bootstraps'}),
              200,
            );
          }
          posts++;
          expect(
            jsonDecode(request.body)['directUrl'],
            'https://meet.google.com/abc-defg-hij',
          );
          if (posts == 1) {
            return http.Response('{"error":"Local session required"}', 401);
          }
          expect(request.headers['X-Companion-Token'], 'local-2');
          return http.Response('{"success":true,"id":"session-a"}', 200);
        }),
      );
      final result = await local.post(
        'classroom/create',
        data: {'directUrl': 'https://meet.google.com/abc-defg-hij'},
      );
      expect(result['id'], 'session-a');
      expect(posts, 2);
      expect(bootstraps, 2);
      local.dispose();
    },
  );

  test('end session uses exact id and reports rejection', () async {
    final local = LocalService(
      client: MockClient((request) async {
        if (request.url.path == '/api/bootstrap') {
          return http.Response('{"token":"local"}', 200);
        }
        expect(request.headers['X-Companion-Token'], 'local');
        expect(jsonDecode(request.body)['classroomId'], 'session-a');
        return http.Response('{"success":false}', 200);
      }),
    );
    expect(await local.endClassroom(classroomId: 'session-a'), false);
    local.dispose();
  });
}
