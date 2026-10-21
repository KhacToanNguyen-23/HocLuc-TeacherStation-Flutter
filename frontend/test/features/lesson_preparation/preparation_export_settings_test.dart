import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_export_settings_sheet.dart';

class ExportApi extends PreparationApi {
  Map? job;
  int saves = 0;
  @override
  Future<dynamic> put(String path, Object body) async {
    saves++;
    return {'revision': 1};
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    job = body as Map;
    return {'id': 'export-job'};
  }

  @override
  Future<dynamic> get(String path) async => path == 'jobs/export-job'
      ? {
          'status': 'succeeded',
          'result': {
            'artifacts': [
              {'id': 'pdf', 'audience': job?['audience']},
            ],
          },
        }
      : path == 'capabilities'
      ? <String, dynamic>{}
      : path.endsWith('/jobs')
      ? {'jobs': []}
      : {'title': 'Lesson', 'revision': 0};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'exports teacher preview with private audience and saved mapping',
    (tester) async {
      final api = ExportApi();
      final c = PreparationController(
        planId: 'plan',
        api: api,
        title: 'Lesson',
        subject: 'Science',
      );
      await c.load();
      Map? preview;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationExportSettingsSheet(
              controller: c,
              onPreview: (a) async {
                preview = a;
              },
            ),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Trường'),
        'My school',
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      await tester.ensureVisible(find.text('Xem PDF giáo viên'));
      await tester.tap(find.text('Xem PDF giáo viên'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(api.job?['audience'], 'teacher');
      expect(preview?['audience'], 'teacher');
      expect(c.document.data['exportTemplate']['school'], 'My school');
      expect(api.saves, 1);
      c.dispose();
    },
  );
}
