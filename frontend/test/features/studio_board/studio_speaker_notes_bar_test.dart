import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_speaker_notes_bar.dart';

void main() {
  group('StudioSpeakerNotesBar & Per-Page Notes', () {
    testWidgets(
      'renders speaker notes bar, expands/collapses and syncs notes across pages',
      (tester) async {
        final studio = StudioState();
        // Setup 2 pages
        studio.addPage();
        studio.setPage(0);
        studio.setPageNote(0, 'Nhắc bài trang 1: Giới thiệu định luật Ohm');
        studio.setPageNote(1, 'Nhắc bài trang 2: Cho ví dụ thực tế mạch điện');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StudioSpeakerNotesBar(studio: studio)),
          ),
        );

        // Initially collapsed on page 1
        expect(find.textContaining('Ghi chú Trang 1/2'), findsOneWidget);
        expect(find.textContaining('Giới thiệu định luật Ohm'), findsOneWidget);

        // Tap header to expand
        await tester.tap(find.textContaining('Ghi chú Trang 1/2'));
        await tester.pumpAndSettle();

        // Should show the privacy badge and TextField
        expect(find.text('Chỉ giáo viên thấy'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Edit note on page 1
        await tester.enterText(
          find.byType(TextField),
          'Đã cập nhật ghi chú trang 1',
        );
        await tester.pumpAndSettle();
        expect(studio.pageNotes[0], 'Đã cập nhật ghi chú trang 1');

        // Switch to page 2
        studio.setPage(1);
        await tester.pumpAndSettle();

        expect(find.textContaining('Ghi chú Trang 2/2'), findsOneWidget);
        expect(
          find.text('Nhắc bài trang 2: Cho ví dụ thực tế mạch điện'),
          findsOneWidget,
        );

        // Edit note on page 2
        await tester.enterText(
          find.byType(TextField),
          'Lưu ý hỏi học sinh công thức',
        );
        await tester.pumpAndSettle();
        expect(studio.pageNotes[1], 'Lưu ý hỏi học sinh công thức');

        // Switch back to page 1
        studio.setPage(0);
        await tester.pumpAndSettle();
        expect(find.text('Đã cập nhật ghi chú trang 1'), findsOneWidget);
      },
    );

    testWidgets(
      'close button calls setSpeakerNotesOpen(false)',
      (tester) async {
        final studio = StudioState()..setSpeakerNotesOpen(true);
        expect(studio.showSpeakerNotes, isTrue);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StudioSpeakerNotesBar(studio: studio)),
          ),
        );

        await tester.tap(find.byKey(const Key('btn_close_speaker_notes')));
        await tester.pump();

        expect(studio.showSpeakerNotes, isFalse);
      },
    );

    test(
      'StudioState serializes and deserializes pageNotes with backwards compatibility',
      () {
        final state = StudioState();
        state.addPage();
        state.setPageNote(0, 'Note 1');
        state.setPageNote(1, 'Note 2');

        state.title = 'Test Lesson';
        final json = state.exportLessonJson();
        expect(json['pageNotes'], ['Note 1', 'Note 2']);

        // Restore to new state
        final restored = StudioState();
        restored.restoreFromJson(json);
        expect(restored.pages.length, 2);
        expect(restored.pageNotes, ['Note 1', 'Note 2']);

        // Backward compatibility with legacy json (without pageNotes)
        final legacyJson = {
          'version': 1,
          'title': 'Legacy Lesson',
          'pages': [[], []],
        };
        final legacyRestored = StudioState();
        legacyRestored.restoreFromJson(legacyJson);
        expect(legacyRestored.pages.length, 2);
        expect(legacyRestored.pageNotes.length, 2);
        expect(legacyRestored.pageNotes[0], '');
        expect(legacyRestored.pageNotes[1], '');
      },
    );
  });
}

