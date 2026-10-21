import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/lesson_preparation/services/preparation_api.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/screens/preparation_workspace_screen.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_transcription_dialog.dart';

class _RangeApi extends PreparationApi {
  Map? posted;
  @override
  Future<dynamic> get(String path) async {
    if (path == 'capabilities') return {};
    if (path.endsWith('/jobs')) return {'jobs': []};
    return {
      'revision': 0,
      'title': 'Range lesson',
      'sections': [],
      'scenes': [],
      'sources': [
        {
          'id': 'source-1',
          'name': 'lesson.wav',
          'mimeType': 'audio/wav',
          'size': 1000,
        },
      ],
    };
  }

  @override
  Future<dynamic> post(String path, [Object? body]) async {
    posted = body as Map;
    return {};
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('range rejects negative, reversed, missing and nonfinite endpoints', () {
    expect(validPreparationRange(0, 3), isTrue);
    for (final pair in <(double?, double?)>[
      (-1, 3),
      (5, 3),
      (3, 3),
      (null, 3),
      (0, null),
      (double.nan, 3),
      (0, double.infinity),
    ]) {
      expect(validPreparationRange(pair.$1, pair.$2), isFalse);
    }
  });
  testWidgets(
    'source range dialog rejects invalid input then submits exact selected seconds',
    (tester) async {
      final api = _RangeApi();
      await tester.pumpWidget(
        MaterialApp(
          home: PreparationWorkspaceScreen(
            planningId: 'range',
            title: 'Range lesson',
            subject: '',
            api: api,
            onOpenBoard: () async {},
            onTeach: () async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Thêm nội dung'));
      await tester.tap(find.text('Thêm nội dung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tài liệu, hình ảnh hoặc bản ghi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Chép lời bản ghi tiếng Việt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toàn bộ nguồn'));
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Bắt đầu (giây)'),
        '20',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kết thúc (giây)'),
        '10',
      );
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Chép lời');
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      expect(api.posted, isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Kết thúc (giây)'),
        '45.5',
      );
      await tester.pump();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(api.posted!['kind'], 'transcribe');
      expect(api.posted!['sourceId'], 'source-1');
      expect(api.posted!['start'], 20);
      expect(api.posted!['end'], 45.5);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('whole-source transcription leaves range keys absent', (
    tester,
  ) async {
    final api = _RangeApi();
    await tester.pumpWidget(
      MaterialApp(
        home: PreparationWorkspaceScreen(
          planningId: 'range',
          title: 'Range lesson',
          subject: '',
          api: api,
          onOpenBoard: () async {},
          onTeach: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thêm nội dung'));
    await tester.tap(find.text('Thêm nội dung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tài liệu, hình ảnh hoặc bản ghi'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chép lời bản ghi tiếng Việt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Chép lời'));
    await tester.pumpAndSettle();
    expect(api.posted!['kind'], 'transcribe');
    expect(api.posted!.containsKey('start'), isFalse);
    expect(api.posted!.containsKey('end'), isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
