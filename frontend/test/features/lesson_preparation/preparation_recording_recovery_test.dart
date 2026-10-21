import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_controller.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_recording_control.dart';

class RecoveryApi extends PreparationApi {
  final pending = <Map<String, dynamic>>[
    {'id': 'previous', 'status': 'recoverable', 'kind': 'microphone'},
  ];
  final posts = <String>[];
  bool fail = false;
  @override
  Future<dynamic> get(String path) async {
    if (path.endsWith('/recordings')) return List.of(pending);
    return {
      'revision': 0,
      'sources': [
        {'id': 'saved-source'},
      ],
    };
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    posts.add(path);
    if (fail) throw StateError('Recovery failed; original retained');
    pending.clear();
    return {};
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets(
    'reopened recording can be recovered in app and refreshes sources',
    (tester) async {
      final api = RecoveryApi();
      final c = PreparationController(
        planId: 'plan',
        api: api,
        title: 'Lesson',
        subject: '',
      );
      await c.refreshRecordings();
      int recorded = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PreparationRecordingControl(
              controller: c,
              onRecorded: () => recorded++,
            ),
          ),
        ),
      );
      expect(find.text('Khôi phục và lưu bản ghi trước'), findsOneWidget);
      await tester.tap(find.text('Khôi phục và lưu bản ghi trước'));
      await tester.pumpAndSettle();
      expect(api.posts, ['recordings/previous/stop']);
      expect(c.activeRecording, isNull);
      expect(c.document.rows('sources').single['id'], 'saved-source');
      expect(recorded, 1);
      c.dispose();
    },
  );
  testWidgets('failed recovery keeps the pending capture available for retry', (
    tester,
  ) async {
    final api = RecoveryApi()..fail = true;
    final c = PreparationController(
      planId: 'plan',
      api: api,
      title: 'Lesson',
      subject: '',
    );
    await c.refreshRecordings();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PreparationRecordingControl(controller: c, onRecorded: () {}),
        ),
      ),
    );
    await tester.tap(find.text('Khôi phục và lưu bản ghi trước'));
    await tester.pumpAndSettle();
    expect(c.activeRecording?['id'], 'previous');
    expect(find.textContaining('Recovery failed'), findsOneWidget);
    expect(find.text('Bỏ bản ghi chưa lưu'), findsOneWidget);
    c.dispose();
  });
}
