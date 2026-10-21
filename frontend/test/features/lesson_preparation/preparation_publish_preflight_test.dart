import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_publish_sheet.dart';

class _PublishApi extends PreparationApi {
  int historyReads = 0;
  final publication = Completer<dynamic>();
  @override
  Future<dynamic> post(String path, [Object? body]) => publication.future;
  @override
  Future<dynamic> get(String path) async {
    if (path == 'capabilities') return <String, dynamic>{};
    if (path.endsWith('/jobs')) return {'jobs': []};
    if (path == 'courses') {
      return {
        'courses': [
          {'id': 'class-a', 'name': 'Class A'},
        ],
      };
    }
    historyReads++;
    return {
      'revision': 7,
      'title': 'Water',
      'artifacts': [
        {
          'id': 'teacher',
          'name': 'Teacher.pdf',
          'mimeType': 'application/pdf',
          'revision': 7,
          'audience': 'teacher',
          'private': true,
        },
        {
          'id': 'answer-image',
          'name': 'Solution.png',
          'mimeType': 'image/png',
          'revision': 7,
          'kind': 'question_private',
        },
        {
          'id': 'current',
          'name': 'Current.pdf',
          'mimeType': 'application/pdf',
          'revision': 7,
        },
        {
          'id': 'old',
          'name': 'Old.pdf',
          'mimeType': 'application/pdf',
          'revision': 6,
        },
        {
          'id': 'private',
          'name': 'Project.json',
          'mimeType': 'application/json',
          'revision': 7,
        },
      ],
      'publications': [
        {
          'title': 'Published',
          'status': 'published',
          'courseId': 'class-a',
          'revision': 7,
          'url': 'https://classroom.google.com/c/example/m/example',
        },
      ],
    };
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'preflight excludes project files and requires current file, course and review confirmation',
    (tester) async {
      final api = _PublishApi();
      final c = PreparationController(
        planId: 'p',
        api: api,
        title: 'Water',
        subject: '',
      );
      await c.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationPublishSheet(controller: c, onPreview: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Project.json'), findsNothing);
      expect(find.text('Teacher.pdf'), findsNothing);
      expect(find.text('Solution.png'), findsNothing);
      expect(find.byTooltip('Mở học liệu Classroom'), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Đăng lên Classroom');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      final old = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('Old.pdf'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(old.onChanged, isNull);
      await tester.ensureVisible(find.text('Current.pdf'));
      await tester.tap(find.text('Current.pdf'));
      await tester.pump();
      final dropdown = find.byType(DropdownButtonFormField<String>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Class A').last);
      await tester.pumpAndSettle();
      final confirmation = find.text(
        'Tôi đã xem và xác nhận các file được chọn phù hợp để chia sẻ cho học sinh.',
      );
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      final before = api.historyReads;
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(api.historyReads, greaterThan(before));
      api.publication.complete({'status': 'published'});
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
