import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/screens/google_workspace_screen.dart';
import 'package:teaching_companion/services/google_workspace_api.dart';

void main() {
  test('provider error keeps recovery code without treating network as revoked consent', () async {
    final api = GoogleWorkspaceApi(email: 'teacher@example.com', client: MockClient((request) async {
      if (request.url.path.endsWith('bootstrap')) return http.Response('{"token":"local"}', 200);
      return http.Response('{"code":"GOOGLE_NETWORK","message":"Mạng tạm lỗi"}', 503, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    await expectLater(api.call('courses'), throwsA(isA<GoogleWorkspaceFailure>()
      .having((e) => e.code, 'code', 'GOOGLE_NETWORK')
      .having((e) => e.needsConsent, 'needsConsent', false)
      .having((e) => e.temporary, 'temporary', true)));
    api.close();
  });
  for (final state in ['REAUTH_REQUIRED', 'TEMPORARY_ERROR']) {
    testWidgets('$state presents correct recovery without opening OAuth for retry', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var checks = 0, connects = 0;
      final api = GoogleWorkspaceApi(email: 'teacher@example.com', client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) return http.Response('{"token":"local"}', 200);
        if (request.url.path.endsWith('connect')) connects++;
        if (request.url.path.endsWith('status')) checks++;
        return http.Response(jsonEncode({'configured': true, 'connected': false, 'state': state, 'message': 'Kiểm tra kết nối'}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
      await tester.pumpAndSettle();
      if (state == 'TEMPORARY_ERROR') {
        expect(find.widgetWithText(FilledButton, 'Thử lại'), findsOneWidget);
        expect(find.text('Cấp quyền lại'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
        await tester.pumpAndSettle();
        expect(checks, 2);
        expect(connects, 0);
      } else {
        expect(find.widgetWithText(FilledButton, 'Cấp quyền lại'), findsOneWidget);
        expect(find.text('Google cần cấp quyền lại'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }
  test('email input validates, normalizes and deduplicates', () {
    expect(
      GoogleWorkspaceApi.parseEmails(
        ' An@Example.com; an@example.com\nbinh@example.com ',
      ),
      ['an@example.com', 'binh@example.com'],
    );
    expect(
      () => GoogleWorkspaceApi.parseEmails('invalid'),
      throwsFormatException,
    );
  });

  test(
    'bridge sends local session and teacher email, never a Google token',
    () async {
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"local-session"}', 200);
          }
          expect(request.headers['X-Companion-Token'], 'local-session');
          expect(
            request.headers['X-Google-Teacher-Email'],
            'teacher@example.com',
          );
          expect(request.headers.containsKey('Authorization'), false);
          return http.Response(
            '{"message":"Chưa cấp quyền"}',
            403,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await expectLater(
        api.call('courses'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Chưa cấp quyền',
          ),
        ),
      );
      api.close();
    },
  );

  for (final width in [360.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('workspace roster and pending states fit width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          Object data;
          if (request.url.path == '/api/bootstrap') {
            data = {'token': 'local-session'};
          } else if (request.url.path.endsWith('/status')) {
            data = {
              'configured': true,
              'connected': true,
              'email': 'teacher@example.com',
            };
          } else {
            data = {
              'courses': [
                {
                  'id': 'test-course',
                  'title': 'Toán 12A',
                  'meetingUrl': 'https://meet.google.com/abc-defg-hij',
                  'warnings': <String>[],
                  'students': [
                    {
                      'name': 'Nguyễn An',
                      'email': 'an.nguyen@example.com',
                      'classroomStatus': 'JOINED',
                      'meetStatus': 'GRANTED',
                    },
                    {
                      'name': 'Trần Bình',
                      'email': 'binh.tran@example.com',
                      'classroomStatus': 'INVITED',
                      'meetStatus': 'NOT_GRANTED',
                    },
                  ],
                },
              ],
            };
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Google đã kết nối'), findsOneWidget);
      expect(find.text('Toán 12A'), findsNWidgets(2));
      await tester.scrollUntilVisible(find.text('Chưa cấp quyền'), 250);
      expect(find.text('Chờ chấp nhận'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    });
  }

  testWidgets(
    'missing configuration shows setup status without fake connect success',
    (tester) async {
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient(
          (r) async => http.Response(
            r.url.path == '/api/bootstrap'
                ? '{"token":"local"}'
                : '{"configured":false,"connected":false}',
            200,
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Ứng dụng chưa được cấu hình'),
        findsOneWidget,
      );
      final connect = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Kết nối Google'),
      );
      expect(connect.onPressed, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
    },
  );
}
