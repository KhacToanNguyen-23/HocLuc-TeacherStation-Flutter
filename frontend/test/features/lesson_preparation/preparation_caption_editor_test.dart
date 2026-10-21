import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/widgets/preparation_caption_editor.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    ValueChanged<Map<String, dynamic>> commit,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PreparationCaptionEditor(
              scene: {
                'id': 'scene-a',
                'narration': 'Water rises.',
                'audioDuration': 3.0,
                'captions': [
                  {
                    'id': 'cue-a',
                    'start': 0.0,
                    'end': 2.5,
                    'text': 'Water rises.',
                  },
                ],
              },
              onCommit: commit,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Phụ đề và diễn tập cảnh'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'review commits edited caption timing and narration fingerprint together',
    (tester) async {
      Map<String, dynamic>? committed;
      await open(tester, (value) => committed = value);
      await tester.enterText(find.byType(TextField).last, 'Water evaporates.');
      await tester.ensureVisible(find.text('Lưu và duyệt phụ đề'));
      await tester.tap(find.text('Lưu và duyệt phụ đề'));
      expect(committed?['captionsReviewed'], isTrue);
      expect(committed?['captionsNarration'], 'Water rises.');
      expect(
        (committed?['captions'] as List).single['text'],
        'Water evaporates.',
      );
      expect((committed?['captions'] as List).single['end'], 2.5);
    },
  );

  testWidgets('caption exceeding known audio cannot be approved', (
    tester,
  ) async {
    var calls = 0;
    await open(tester, (_) => calls++);
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.ensureVisible(find.text('Lưu và duyệt phụ đề'));
    await tester.tap(find.text('Lưu và duyệt phụ đề'));
    await tester.pump();
    expect(calls, 0);
    expect(find.textContaining('không chồng nhau'), findsOneWidget);
  });
  testWidgets(
    'bilingual requires secondary text and saves language visibility',
    (tester) async {
      Map<String, dynamic>? committed;
      await open(tester, (value) => committed = value);
      await tester.tap(find.text('Song ngữ'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu và duyệt phụ đề'));
      await tester.tap(find.text('Lưu và duyệt phụ đề'));
      await tester.pump();
      expect(committed, isNull);
      expect(find.textContaining('Điền bản dịch thứ hai'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Nước bốc lên.');
      await tester.ensureVisible(find.text('Lưu và duyệt phụ đề'));
      await tester.tap(find.text('Lưu và duyệt phụ đề'));
      expect(committed?['captionMode'], 'bilingual');
      expect(
        (committed?['captions'] as List).single['secondaryText'],
        'Nước bốc lên.',
      );
      expect(committed?['captionsVisible'], true);
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.ensureVisible(find.text('Lưu và duyệt phụ đề'));
      await tester.tap(find.text('Lưu và duyệt phụ đề'));
      expect(committed?['captionsVisible'], false);
    },
  );

  testWidgets('phone-width preview warns about long cues without truncating', (
    tester,
  ) async {
    await open(tester, (_) {});
    await tester.enterText(
      find.byType(TextField).last,
      List.filled(60, 'caption').join(' '),
    );
    await tester.pump();
    expect(find.textContaining('Cue dài hơn 4 dòng'), findsOneWidget);
    expect(find.text('Xem thử chiều rộng điện thoại'), findsOneWidget);
  });
}
