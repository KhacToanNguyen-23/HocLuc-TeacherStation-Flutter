import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/screens/google_workspace_screen.dart';
import 'package:teaching_companion/services/google_workspace_api.dart';

void main() {
  for (final pending in [false, true]) {
    testWidgets(
      'one click prepares Calendar and launches correct room, pending=$pending',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var starts = 0;
        final requests = <String>[];
        String? launched;
        Map<String, dynamic> course() => {
          'id': 'calendar-class',
          'title': 'Lớp Calendar',
          'warnings': [],
          'admissionMode': 'CALENDAR',
          'calendarStatus': starts == 0
              ? 'NOT_PREPARED'
              : pending && starts == 1
              ? 'PENDING'
              : 'READY',
          if (starts > 0 && (!pending || starts > 1))
            'meetingUrl': 'https://meet.google.com/new-room-aaa',
          'students': [
            {
              'email': 'pending@example.com',
              'classroomStatus': 'INVITED',
              'meetAllowed': true,
              'meetStatus': 'CALENDAR_INVITED',
            },
          ],
        };
        final api = GoogleWorkspaceApi(
          email: 'teacher@example.com',
          client: MockClient((request) async {
            Object data;
            if (request.url.path.endsWith('bootstrap')) {
              data = {'token': 'local'};
            } else if (request.url.path.endsWith('status')) {
              data = {'configured': true, 'connected': true};
            } else if (request.url.path.endsWith('/start')) {
              starts++;
              requests.add(jsonDecode(request.body)['requestId'] as String);
              data = course();
            } else {
              data = {
                'courses': [course()],
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
          MaterialApp(
            home: GoogleWorkspaceScreen(
              api: api,
              launchLesson: (course) async {
                launched = course['meetingUrl'] as String;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Chuẩn bị phòng Calendar'), findsNothing);
        expect(find.text('Đồng bộ'), findsNothing);
        await tester.tap(find.text('Bắt đầu dạy'));
        await tester.pump();
        if (pending) {
          expect(find.text('Đang chuẩn bị phòng…'), findsOneWidget);
          expect(launched, isNull);
          await tester.pump(const Duration(seconds: 2));
        }
        await tester.pumpAndSettle();
        expect(launched, 'https://meet.google.com/new-room-aaa');
        expect(requests.toSet().length, 1);
        expect(starts, pending ? 2 : 1);
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
  }
  testWidgets(
    'failed start retries same operation without another preparation dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      var launched = false;
      final course = <String, dynamic>{
        'id': 'retry-class',
        'title': 'Lớp thử lại',
        'students': [],
        'warnings': [],
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          Object data;
          if (request.url.path.endsWith('bootstrap')) {
            data = {'token': 'local'};
          } else if (request.url.path.endsWith('status')) {
            data = {'configured': true, 'connected': true};
          } else if (request.url.path.endsWith('/start')) {
            requests.add(jsonDecode(request.body)['requestId'] as String);
            if (requests.length == 1) {
              return http.Response(
                '{"code":"GOOGLE_NETWORK","message":"Mạng tạm lỗi"}',
                503,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            data = {
              ...course,
              'calendarStatus': 'READY',
              'meetingUrl': 'https://meet.google.com/new-room-aaa',
            };
          } else {
            data = {
              'courses': [course],
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
        MaterialApp(
          home: GoogleWorkspaceScreen(
            api: api,
            launchLesson: (_) async {
              launched = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bắt đầu dạy'));
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(launched, isFalse);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(launched, isTrue);
      expect(requests.length, 2);
      expect(requests.toSet().length, 1);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  testWidgets(
    'pending Classroom student can have verified Meet access and teacher can revoke or restore it',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var allowed = true, changes = 0;
      Map<String, dynamic> course() => {
        'id': 'class-a',
        'title': 'Lớp kiểm tra',
        'meetingUrl': 'https://meet.google.com/abc-defg-hij',
        'warnings': [],
        'students': [
          {
            'email': 'pending@example.com',
            'classroomStatus': 'INVITED',
            'meetAllowed': allowed,
            'meetStatus': allowed ? 'GRANTED' : 'NOT_GRANTED',
          },
        ],
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          Object data;
          if (request.url.path.endsWith('bootstrap')) {
            data = {'token': 'local'};
          } else if (request.url.path.endsWith('status')) {
            data = {'configured': true, 'connected': true};
          } else if (request.url.path.endsWith('/access')) {
            expect(request.method, 'POST');
            final body = jsonDecode(request.body) as Map;
            expect(body['email'], 'pending@example.com');
            allowed = body['allowed'] as bool;
            changes++;
            data = course();
          } else {
            data = {
              'courses': [course()],
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
      await tester.scrollUntilVisible(find.text('Gỡ quyền Meet'), 200);
      expect(find.text('Chờ chấp nhận'), findsOneWidget);
      expect(find.text('Đã lưu membership'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Gỡ quyền Meet')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ quyền Meet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(changes, 0);
      await Scrollable.ensureVisible(
        tester.element(find.text('Gỡ quyền Meet')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ quyền Meet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gỡ quyền'));
      await tester.pumpAndSettle();
      expect(changes, 1);
      expect(find.text('Chưa cấp quyền'), findsOneWidget);
      await Scrollable.ensureVisible(
        tester.element(find.text('Cấp quyền Meet')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cấp quyền Meet'));
      await tester.pumpAndSettle();
      expect(changes, 2);
      expect(find.text('Đã lưu membership'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );
  test(
    'provider error keeps recovery code without treating network as revoked consent',
    () async {
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          return http.Response(
            '{"code":"GOOGLE_NETWORK","message":"Mạng tạm lỗi"}',
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await expectLater(
        api.call('courses'),
        throwsA(
          isA<GoogleWorkspaceFailure>()
              .having((e) => e.code, 'code', 'GOOGLE_NETWORK')
              .having((e) => e.needsConsent, 'needsConsent', false)
              .having((e) => e.temporary, 'temporary', true),
        ),
      );
      api.close();
    },
  );
  for (final state in ['REAUTH_REQUIRED', 'TEMPORARY_ERROR']) {
    testWidgets(
      '$state presents correct recovery without opening OAuth for retry',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var checks = 0, connects = 0;
        final api = GoogleWorkspaceApi(
          email: 'teacher@example.com',
          client: MockClient((request) async {
            if (request.url.path.endsWith('bootstrap')) {
              return http.Response('{"token":"local"}', 200);
            }
            if (request.url.path.endsWith('connect')) connects++;
            if (request.url.path.endsWith('status')) checks++;
            return http.Response(
              jsonEncode({
                'configured': true,
                'connected': false,
                'state': state,
                'message': 'Kiểm tra kết nối',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        );
        await tester.pumpWidget(
          MaterialApp(home: GoogleWorkspaceScreen(api: api)),
        );
        await tester.pumpAndSettle();
        if (state == 'TEMPORARY_ERROR') {
          expect(find.widgetWithText(FilledButton, 'Thử lại'), findsOneWidget);
          expect(find.text('Cấp quyền lại'), findsNothing);
          await tester.tap(find.widgetWithText(FilledButton, 'Thử lại'));
          await tester.pumpAndSettle();
          expect(checks, 2);
          expect(connects, 0);
        } else {
          expect(
            find.widgetWithText(FilledButton, 'Cấp quyền lại'),
            findsOneWidget,
          );
          expect(find.text('Google cần cấp quyền lại'), findsOneWidget);
        }
        await tester.pumpWidget(const SizedBox());
        api.close();
      },
    );
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

  testWidgets(
    'completing a created course reflects its sync response without duplicate sync',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <String>[];
      final createResponse = <String, dynamic>{
        'id': 'draft-class',
        'courseId': 'google-course-1',
        'title': 'Toán 12A',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          requests.add('${request.method} ${request.url.path}');
          Object data;
          if (request.url.path.endsWith('bootstrap')) {
            data = {'token': 'local'};
          } else if (request.url.path.endsWith('status')) {
            data = {'configured': true, 'connected': true};
          } else if (request.method == 'POST' &&
              request.url.path.endsWith('/courses')) {
            data = createResponse;
          } else if (request.url.path.endsWith('/sync')) {
            data = {
              ...createResponse,
              'classroomState': 'ACTIVE',
              'syncedAt': '2026-10-17T10:00:00Z',
            };
          } else {
            data = {
              'courses': [
                {
                  'id': 'draft-class',
                  'title': 'Toán 12A',
                  'courseId': null,
                  'classroomState': null,
                  'students': <Map<String, dynamic>>[],
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
      await tester.tap(find.text('Hoàn tất tạo lớp'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);
      expect(requests.where((r) => r.contains('/sync')), isEmpty);
      expect(
        requests
            .where((r) => r == 'POST /api/integrations/google/courses')
            .length,
        1,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(requests.where((r) => r.endsWith('/sync')).length, 1);
      expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  for (final state in [
    'PROVISIONED',
    'ACTIVE',
    'DECLINED',
    'ARCHIVED',
    'SUSPENDED',
  ]) {
    testWidgets('$state course shows the matching Classroom sync status', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final course = <String, dynamic>{
        'id': 'state-class',
        'title': 'Toán 12A',
        'courseId': 'google-course-1',
        'classroomState': state,
        'classroomWarnings': state == 'ACTIVE'
            ? <String>[]
            : <String>['Google Classroom state: $state'],
        'students': <Map<String, dynamic>>[],
        'syncedAt': state == 'ACTIVE' ? '2026-10-17T10:00:00Z' : null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          Object data;
          if (request.url.path.endsWith('bootstrap')) {
            data = {'token': 'local'};
          } else if (request.url.path.endsWith('status')) {
            data = {'configured': true, 'connected': true};
          } else {
            data = {
              'courses': [course],
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

      if (state == 'PROVISIONED') {
        expect(
          find.textContaining('Mở Classroom để chấp nhận'),
          findsOneWidget,
        );
        expect(find.textContaining('Đã đồng bộ thành viên'), findsNothing);
      } else if (state == 'ACTIVE') {
        expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
      } else {
        expect(
          find.textContaining('Kiểm tra lớp trong Classroom'),
          findsOneWidget,
        );
        expect(find.textContaining('Mở Classroom để chấp nhận'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
      api.close();
    });
  }

  testWidgets(
    'ACTIVE with warnings reports partial sync rather than clean roster success',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final course = <String, dynamic>{
        'id': 'partial-class',
        'title': 'Toán 12A',
        'courseId': 'google-course-1',
        'classroomState': 'ACTIVE',
        'classroomWarnings': ['One student could not be invited'],
        'students': <Map<String, dynamic>>[],
        'syncedAt': '2026-10-17T10:00:00Z',
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          Object data;
          if (request.url.path.endsWith('bootstrap')) {
            data = {'token': 'local'};
          } else if (request.url.path.endsWith('status')) {
            data = {'configured': true, 'connected': true};
          } else {
            data = {
              'courses': [course],
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
      expect(find.textContaining('còn cảnh báo đồng bộ'), findsOneWidget);
      expect(
        find.textContaining('One student could not be invited'),
        findsOneWidget,
      );
      expect(find.textContaining('Đã đồng bộ thành viên'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets('syncedAt alone does not claim a clean ACTIVE roster sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final course = <String, dynamic>{
      'id': 'no-state-class',
      'title': 'Toán 12A',
      'courseId': 'google-course-1',
      'classroomWarnings': <String>[],
      'students': <Map<String, dynamic>>[],
      'syncedAt': '2026-10-17T10:00:00Z',
    };
    final api = GoogleWorkspaceApi(
      email: 'teacher@example.com',
      client: MockClient((request) async {
        Object data;
        if (request.url.path.endsWith('bootstrap')) {
          data = {'token': 'local'};
        } else if (request.url.path.endsWith('status')) {
          data = {'configured': true, 'connected': true};
        } else {
          data = {
            'courses': [course],
          };
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã đồng bộ thành viên'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('ACTIVE without syncedAt does not claim a clean roster sync', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final course = <String, dynamic>{
      'id': 'active-unsynced-class',
      'title': 'Toán 12A',
      'courseId': 'google-course-1',
      'classroomState': 'ACTIVE',
      'classroomWarnings': <String>[],
      'students': <Map<String, dynamic>>[],
      'syncedAt': null,
    };
    final api = GoogleWorkspaceApi(
      email: 'teacher@example.com',
      client: MockClient((request) async {
        Object data;
        if (request.url.path.endsWith('bootstrap')) {
          data = {'token': 'local'};
        } else if (request.url.path.endsWith('status')) {
          data = {'configured': true, 'connected': true};
        } else {
          data = {
            'courses': [course],
          };
        }
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Đã đồng bộ thành viên'), findsNothing);
    expect(
      find.textContaining('chưa xác nhận đồng bộ thành viên'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets('resume does not sync when no course is pending', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var syncRequests = 0;
    final course = <String, dynamic>{
      'id': 'already-active',
      'title': 'Active class',
      'classroomState': 'ACTIVE',
      'classroomWarnings': <String>[],
      'syncedAt': '2026-10-17T10:00:00Z',
      'students': <Map<String, dynamic>>[],
    };
    final api = GoogleWorkspaceApi(
      email: 'teacher@example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) {
          return http.Response('{"token":"local"}', 200);
        }
        if (request.url.path.endsWith('status')) {
          return http.Response('{"configured":true,"connected":true}', 200);
        }
        if (request.url.path.endsWith('/sync')) syncRequests++;
        return http.Response(
          jsonEncode({
            'courses': [course],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(syncRequests, 0);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
    'resume syncs a loaded PROVISIONED course and applies ACTIVE response',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      var syncCompleted = false;
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final activeCourse = <String, dynamic>{
        ...pendingCourse,
        'classroomState': 'ACTIVE',
        'classroomWarnings': <String>[],
        'syncedAt': '2026-10-17T10:00:00Z',
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            syncCompleted = true;
            return http.Response(
              jsonEncode(activeCourse),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(syncRequests, 1);
      expect(syncCompleted, isTrue);
      expect(
        find.textContaining('Đã đồng bộ thành viên từ Classroom'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets('automatic Classroom sync shows progress in the course card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final syncResponse = Completer<http.Response>();
    final pendingCourse = <String, dynamic>{
      'id': 'pending-progress-class',
      'title': 'Pending progress class',
      'courseId': 'google-classroom-id',
      'classroomState': 'PROVISIONED',
      'classroomWarnings': <String>[],
      'students': <Map<String, dynamic>>[],
      'syncedAt': null,
    };
    final api = GoogleWorkspaceApi(
      email: 'teacher@example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) {
          return http.Response('{"token":"local"}', 200);
        }
        if (request.url.path.endsWith('status')) {
          return http.Response('{"configured":true,"connected":true}', 200);
        }
        if (request.url.path.endsWith('/sync')) return syncResponse.future;
        return http.Response(
          jsonEncode({
            'courses': [pendingCourse],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.textContaining('Đang đồng bộ Classroom'), findsOneWidget);
    expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);

    syncResponse.complete(
      http.Response(
        jsonEncode({
          ...pendingCourse,
          'classroomState': 'ACTIVE',
          'syncedAt': '2026-10-17T10:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Đang đồng bộ Classroom'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
    'sync failure is shown in card and manual retry uses the same result handler',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final pendingCourse = <String, dynamic>{
        'id': 'pending-error-class',
        'title': 'Pending error class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            if (syncRequests == 1) {
              return http.Response(
                '{"message":"Temporary Classroom error"}',
                502,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            if (syncRequests == 3) {
              return http.Response(
                '{"message":"Temporary active Classroom error"}',
                502,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              jsonEncode({
                ...pendingCourse,
                'classroomState': 'ACTIVE',
                'syncedAt': '2026-10-17T10:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Không thể đồng bộ Classroom'),
        findsOneWidget,
      );
      expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);
      expect(find.textContaining('Đang đồng bộ Classroom'), findsNothing);
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isTrue,
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(syncRequests, 2);
      expect(find.textContaining('Temporary Classroom error'), findsNothing);
      expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng bộ'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Temporary active Classroom error'),
        findsOneWidget,
      );
      expect(find.textContaining('Bấm nút Đồng bộ để thử lại'), findsOneWidget);
      expect(find.textContaining('khi bạn quay lại ứng dụng'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets(
    'duplicate resumes coalesce and manual sync stays disabled while syncing',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final syncResponse = Completer<http.Response>();
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            return syncResponse.future;
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .enabled,
        isFalse,
      );
      expect(syncRequests, 1);

      syncResponse.complete(
        http.Response(
          jsonEncode({
            ...pendingCourse,
            'classroomState': 'ACTIVE',
            'syncedAt': '2026-10-17T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets(
    'selecting a PROVISIONED course makes it eligible for resume sync',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final activeCourse = <String, dynamic>{
        'id': 'active-class',
        'title': 'Active class',
        'classroomState': 'ACTIVE',
        'classroomWarnings': <String>[],
        'syncedAt': '2026-10-17T10:00:00Z',
        'students': <Map<String, dynamic>>[],
      };
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'syncedAt': null,
        'students': <Map<String, dynamic>>[],
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            return http.Response(
              jsonEncode({
                ...pendingCourse,
                'classroomState': 'ACTIVE',
                'syncedAt': '2026-10-17T10:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({
              'courses': [activeCourse, pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pending class'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(syncRequests, 1);
      expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets(
    'a still PROVISIONED response remains eligible for the next resume',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            return http.Response(
              jsonEncode(
                syncRequests == 1
                    ? pendingCourse
                    : {
                        ...pendingCourse,
                        'classroomState': 'ACTIVE',
                        'syncedAt': '2026-10-17T10:00:00Z',
                      },
              ),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(syncRequests, 1);
      expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(syncRequests, 2);
      expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets('resume during a reload retries after the reload completes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var courseLoads = 0;
    var syncRequests = 0;
    final reloadResponse = Completer<http.Response>();
    final pendingCourse = <String, dynamic>{
      'id': 'pending-class',
      'title': 'Pending class',
      'courseId': 'google-classroom-id',
      'classroomState': 'PROVISIONED',
      'classroomWarnings': <String>[],
      'students': <Map<String, dynamic>>[],
      'syncedAt': null,
    };
    final api = GoogleWorkspaceApi(
      email: 'teacher@example.com',
      client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) {
          return http.Response('{"token":"local"}', 200);
        }
        if (request.url.path.endsWith('status')) {
          return http.Response('{"configured":true,"connected":true}', 200);
        }
        if (request.url.path.endsWith('/sync')) {
          syncRequests++;
          return http.Response(
            jsonEncode({
              ...pendingCourse,
              'classroomState': 'ACTIVE',
              'syncedAt': '2026-10-17T10:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        courseLoads++;
        if (courseLoads > 1) return reloadResponse.future;
        return http.Response(
          jsonEncode({
            'courses': [pendingCourse],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(MaterialApp(home: GoogleWorkspaceScreen(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Tải lại'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(syncRequests, 0);

    reloadResponse.complete(
      http.Response(
        jsonEncode({
          'courses': [pendingCourse],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();
    expect(syncRequests, 1);
    expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    api.close();
  });

  testWidgets(
    'sync error stays distinct from pending and a later resume retries',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            if (syncRequests == 1) {
              return http.Response(
                '{"message":"Temporary Classroom error"}',
                502,
                headers: {'content-type': 'application/json; charset=utf-8'},
              );
            }
            return http.Response(
              jsonEncode({
                ...pendingCourse,
                'classroomState': 'ACTIVE',
                'syncedAt': '2026-10-17T10:00:00Z',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(syncRequests, 1);
      expect(find.textContaining('Temporary Classroom error'), findsOneWidget);
      expect(find.textContaining('Mở Classroom để chấp nhận'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(syncRequests, 2);
      expect(find.textContaining('Temporary Classroom error'), findsNothing);
      expect(find.textContaining('Đã đồng bộ thành viên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      api.close();
    },
  );

  testWidgets(
    'dispose removes resume observer and ignores a late sync response',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var syncRequests = 0;
      final syncResponse = Completer<http.Response>();
      final pendingCourse = <String, dynamic>{
        'id': 'pending-class',
        'title': 'Pending class',
        'courseId': 'google-classroom-id',
        'classroomState': 'PROVISIONED',
        'classroomWarnings': <String>[],
        'students': <Map<String, dynamic>>[],
        'syncedAt': null,
      };
      final api = GoogleWorkspaceApi(
        email: 'teacher@example.com',
        client: MockClient((request) async {
          if (request.url.path.endsWith('bootstrap')) {
            return http.Response('{"token":"local"}', 200);
          }
          if (request.url.path.endsWith('status')) {
            return http.Response('{"configured":true,"connected":true}', 200);
          }
          if (request.url.path.endsWith('/sync')) {
            syncRequests++;
            return syncResponse.future;
          }
          return http.Response(
            jsonEncode({
              'courses': [pendingCourse],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(home: GoogleWorkspaceScreen(api: api)),
      );
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(syncRequests, 1);

      await tester.pumpWidget(const SizedBox());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(syncRequests, 1);
      syncResponse.complete(
        http.Response(
          jsonEncode({...pendingCourse, 'classroomState': 'ACTIVE'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      api.close();
    },
  );

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
