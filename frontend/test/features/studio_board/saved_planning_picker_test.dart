import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/saved_planning_picker.dart';

void main() {
  test(
    'opening saved lesson uses only clone endpoint and restores its committed content',
    () async {
      final requests = <String>[];
      final service = LocalService(
        client: MockClient((request) async {
          requests.add(request.url.path);
          if (request.url.path == '/api/bootstrap')
            return http.Response('{"token":"test"}', 200);
          expect(request.method, 'POST');
          expect(request.url.path, '/api/plannings/saved/clone-to-classroom');
          return http.Response(
            '{"success":true,"content":{"title":"Saved","pages":[[]],"pageNotes":["PRIVATE"]}}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);
      final content = await service.openPlanningInClassroom('saved');
      expect(content?['pageNotes'], ['PRIVATE']);
      expect(
        requests.any(
          (path) => path.contains('classrooms') || path.contains('meet'),
        ),
        isFalse,
      );
    },
  );
  testWidgets('finds saved lesson by subject and returns its identity', (
    tester,
  ) async {
    final plan = PlanningMeta(
      id: 'saved',
      title: 'Đạo hàm',
      subject: 'Toán',
      createdAt: 1,
      updatedAt: 2,
    );
    PlanningMeta? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showDialog<PlanningMeta>(
                  context: context,
                  builder: (_) => SavedPlanningPicker(load: () async => [plan]),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'toán');
    await tester.pump();
    await tester.tap(find.text('Đạo hàm'));
    await tester.pumpAndSettle();
    expect(selected?.id, 'saved');
  });

  testWidgets(
    'distinguishes connection failure from empty library and retries',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SavedPlanningPicker(
            load: () async {
              if (attempts++ == 0) throw StateError('offline');
              return [];
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.textContaining('Chưa có bài đã lưu'), findsNothing);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chưa có bài đã lưu'), findsOneWidget);
    },
  );

  test(
    'replacing live lesson clears old content and restores private notes without changing audio preferences',
    () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.endpoint = 'existing-endpoint';
      studio.notes = 'OLD';
      studio.question = 'OLD';
      studio.addPage();
      studio.openLiveLesson({
        'title': 'New',
        'pages': [[], []],
        'pageIds': ['a', 'b'],
        'pageTitles': ['A', 'B'],
        'pageNotes': ['PRIVATE-A', 'PRIVATE-B'],
        'teacherPreparation': {
          'revision': 2,
          'teacherCues': [],
          'sections': [],
        },
      });
      expect(studio.title, 'New');
      expect(studio.pageNotes, ['PRIVATE-A', 'PRIVATE-B']);
      expect(studio.notes, '');
      expect(studio.question, '');
      expect(studio.hasLiveTeacherContext, isTrue);
      expect(studio.endpoint, 'existing-endpoint');
      expect(studio.dirty, isFalse);
      studio.openLiveLesson({
        'title': 'Blank',
        'pages': [[]],
      });
      expect(studio.pageNotes, ['']);
      expect(studio.preparationDocument, isNull);
      expect(studio.pages.length, 1);
    },
  );
}
