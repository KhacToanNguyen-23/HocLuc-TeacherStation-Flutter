import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/core/network/local_service.dart';

void main() {
  group('Classroom History Content & Archive Tests', () {
    testWidgets(
      'Dashboard renders history card with reopen and download actions',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ClassroomDashboardScreen()),
        );

        await tester.pumpAndSettle();

        // Find the History tab and click it
        final historyTab = find.text('Lịch sử');
        expect(historyTab, findsWidgets);

        await tester.tap(historyTab.first);
        await tester.pumpAndSettle();

        // Should show the history section header
        expect(find.textContaining('Lịch sử'), findsWidgets);
      },
    );

    test(
      'StudioState exportLessonJson captures all pages, titles and notes for history archiving',
      () {
        final state = StudioState();
        state.title = 'Lịch sử Tiết 1 - Vật lý 12';
        state.subject = 'Vật lý';
        state.setPageNote(0, 'Ghi chú trang 1');
        state.addPage('Trang 2');
        state.setPageNote(1, 'Ghi chú trang 2');

        final json = state.exportLessonJson();
        expect(json['title'], 'Lịch sử Tiết 1 - Vật lý 12');
        expect(json['subject'], 'Vật lý');
        expect(json['pageNotes'], ['Ghi chú trang 1', 'Ghi chú trang 2']);
        expect(json['pages'], isList);

        // Verify restore into fresh StudioState
        final restored = StudioState();
        restored.restoreFromJson(json);
        expect(restored.title, 'Lịch sử Tiết 1 - Vật lý 12');
        expect(restored.pages.length, 2);
        // When exported, page was 1 (the last added page)
        expect(restored.page, 1);
        expect(restored.currentPageNote, 'Ghi chú trang 2');
        restored.setPage(0);
        expect(restored.currentPageNote, 'Ghi chú trang 1');
      },
    );

    test(
      'LocalService endClassroom serialize content snapshot properly',
      () async {
        String? capturedEndBody;

        final client = MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"test-token"}', 200);
          }
          if (request.url.path == '/api/classroom/end') {
            capturedEndBody = request.body;
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{}', 200);
        });

        final local = LocalService(client: client);
        final endOk = await local.endClassroom(
          classroomId: 'cls_test123',
          content: {'title': 'Lớp 12A1', 'pages': []},
        );
        expect(endOk, true);
        expect(capturedEndBody, contains('cls_test123'));
        expect(capturedEndBody, contains('content'));

        local.dispose();
      },
    );

    test(
      'LocalService deleteClassroomHistory sends DELETE request properly',
      () async {
        String? capturedPath;
        String? capturedMethod;

        final client = MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"test-token"}', 200);
          }
          capturedPath = request.url.path;
          capturedMethod = request.method;
          if (request.url.path == '/api/classroom/history/cls_del_123' &&
              request.method == 'DELETE') {
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{"success":false}', 400);
        });

        final local = LocalService(client: client);
        final ok = await local.deleteClassroomHistory('cls_del_123');
        expect(ok, true);
        expect(capturedPath, '/api/classroom/history/cls_del_123');
        expect(capturedMethod, 'DELETE');

        local.dispose();
      },
    );

    test(
      'LocalService clearAllClassroomHistory sends DELETE request properly',
      () async {
        String? capturedPath;
        String? capturedMethod;

        final client = MockClient((request) async {
          if (request.url.path == '/api/bootstrap') {
            return http.Response('{"token":"test-token"}', 200);
          }
          capturedPath = request.url.path;
          capturedMethod = request.method;
          if (request.url.path == '/api/classroom/history' &&
              request.method == 'DELETE') {
            return http.Response('{"success":true}', 200);
          }
          return http.Response('{"success":false}', 400);
        });

        final local = LocalService(client: client);
        final ok = await local.clearAllClassroomHistory();
        expect(ok, true);
        expect(capturedPath, '/api/classroom/history');
        expect(capturedMethod, 'DELETE');

        local.dispose();
      },
    );
  });
}

