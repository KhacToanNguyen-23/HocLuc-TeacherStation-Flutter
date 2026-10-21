import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'dart:convert';

void main() {
  test(
    'board save sends expected revision and applies acknowledged revision',
    () async {
      final content = <String, dynamic>{
        'boardRevision': 3,
        'pages': [[]],
      };
      final local = LocalService(
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"companion"}', 200);
          }
          final body = jsonDecode(request.body) as Map;
          expect(body['expectedRevision'], 3);
          return http.Response(
            '{"id":"p","title":"Lesson","boardRevision":4}',
            200,
          );
        }),
      );
      addTearDown(local.dispose);
      expect(await local.updatePlanning(id: 'p', content: content), isNotNull);
      expect(content['boardRevision'], 4);
    },
  );
  test(
    'board conflict is actionable and does not retry stale snapshot',
    () async {
      var calls = 0;
      final local = LocalService(
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"companion"}', 200);
          }
          calls++;
          return http.Response('{}', 409);
        }),
      );
      addTearDown(local.dispose);
      expect(
        await local.updatePlanning(id: 'p', content: {'boardRevision': 3}),
        isNull,
      );
      expect(local.planningSaveError, contains('thay đổi'));
      expect(calls, 1);
    },
  );
  test(
    'planning lookup refreshes rejected app session and companion together',
    () async {
      final refreshes = <bool>[];
      LocalService.appSessionProvider = ({required bool forceRefresh}) async {
        refreshes.add(forceRefresh);
        return forceRefresh ? 'new-session' : 'expired-session';
      };
      addTearDown(() => LocalService.appSessionProvider = null);
      var calls = 0;
      final local = LocalService(
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"companion"}', 200);
          }
          calls++;
          expect(request.headers['X-Companion-Token'], 'companion');
          if (calls == 1) {
            expect(request.headers['Authorization'], 'Bearer expired-session');
            return http.Response('{}', 401);
          }
          expect(request.headers['Authorization'], 'Bearer new-session');
          return http.Response('[]', 200);
        }),
      );
      addTearDown(local.dispose);
      expect(await local.getPlannings(), isEmpty);
      expect(refreshes, [false, true]);
      expect(calls, 2);
    },
  );
}
