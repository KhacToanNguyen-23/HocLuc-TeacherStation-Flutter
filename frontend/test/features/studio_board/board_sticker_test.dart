import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/board_sticker.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/board_sticker_card.dart';

void main() {
  group('Phase 01: BoardSticker Model & State', () {
    test('BoardSticker model serialization and deserialization', () {
      final sticker = BoardSticker(
        id: 'sticker-1',
        type: 'english_svo_card',
        normalizedRect: const Rect.fromLTWH(0.1, 0.2, 0.4, 0.15),
        rawText: 'The teacher explained the lesson',
        tokens: [
          {'text': 'The', 'role': 'OTHER', 'pos': 'DET', 'dep': 'det'},
          {'text': 'teacher', 'role': 'SUBJECT', 'pos': 'NOUN', 'dep': 'nsubj'},
          {'text': 'explained', 'role': 'VERB', 'pos': 'VERB', 'dep': 'ROOT'},
          {'text': 'the', 'role': 'OTHER', 'pos': 'DET', 'dep': 'det'},
          {'text': 'lesson', 'role': 'OBJECT', 'pos': 'NOUN', 'dep': 'dobj'},
        ],
        issues: ['⚠️ Watch verb tense agreement'],
      );

      final json = sticker.toJson();
      expect(json['id'], 'sticker-1');
      expect(json['type'], 'english_svo_card');
      expect(json['rect'], [0.1, 0.2, 0.4, 0.15]);
      expect(json['rawText'], 'The teacher explained the lesson');
      expect((json['tokens'] as List).length, 5);
      expect((json['issues'] as List).length, 1);

      final restored = BoardSticker.fromJson(json);
      expect(restored.id, sticker.id);
      expect(restored.type, sticker.type);
      expect(restored.normalizedRect.left, closeTo(0.1, 0.001));
      expect(restored.normalizedRect.top, closeTo(0.2, 0.001));
      expect(restored.normalizedRect.width, closeTo(0.4, 0.001));
      expect(restored.normalizedRect.height, closeTo(0.15, 0.001));
      expect(restored.tokens.length, 5);
      expect(restored.issues.first, '⚠️ Watch verb tense agreement');
    });

    test('StudioState manages stickers per page correctly', () {
      final studio = StudioState()..loading = false;
      expect(studio.currentStickers, isEmpty);

      final sticker1 = BoardSticker(
        id: 's1',
        type: 'english_svo_card',
        normalizedRect: const Rect.fromLTWH(0.2, 0.2, 0.3, 0.2),
        rawText: 'She sings',
        tokens: [
          {'text': 'She', 'role': 'SUBJECT'},
          {'text': 'sings', 'role': 'VERB'},
        ],
      );

      studio.addSticker(sticker1);
      expect(studio.currentStickers.length, 1);
      expect(studio.currentStickers.first.id, 's1');

      // Change page to page 1
      studio.addPage('Trang 2');
      expect(studio.page, 1);
      expect(studio.currentStickers, isEmpty);

      // Return to page 0
      studio.setPage(0);
      expect(studio.currentStickers.length, 1);
      expect(studio.currentStickers.first.id, 's1');

      // Update sticker position
      studio.updateStickerRect('s1', const Rect.fromLTWH(0.3, 0.4, 0.3, 0.2));
      expect(
        studio.currentStickers.first.normalizedRect.left,
        closeTo(0.3, 0.001),
      );

      // Remove sticker
      studio.removeSticker('s1');
      expect(studio.currentStickers, isEmpty);

      studio.dispose();
    });

    testWidgets(
      'BoardStickerCard renders tokens, role badges, and triggers delete',
      (tester) async {
        final sticker = BoardSticker(
          id: 's-widget',
          type: 'english_svo_card',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.4, 0.2),
          rawText: 'He runs',
          tokens: [
            {'text': 'He', 'role': 'SUBJECT'},
            {'text': 'runs', 'role': 'VERB'},
          ],
          issues: ['⚠️ Simple present tense'],
        );

        bool deleted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardStickerCard(
                sticker: sticker,
                onDelete: () => deleted = true,
                onUpdateRect: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('He'), findsOneWidget);
        expect(find.text('runs'), findsOneWidget);
        expect(find.text('S'), findsOneWidget);
        expect(find.text('V'), findsOneWidget);
        expect(find.textContaining('Simple present tense'), findsOneWidget);

        // Tap close button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(deleted, isTrue);
      },
    );
  });
}

