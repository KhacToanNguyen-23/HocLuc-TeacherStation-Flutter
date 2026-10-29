import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/board_sticker_card.dart';
import 'package:teaching_companion/features/studio_board/presentation/board_sticker_floating_bar.dart';

void main() {
  group('Học Lực Math Studio BoardSticker & Canva Transform Controls Tests', () {
    test('BoardSticker model serialization and rotation deserialization', () {
      final sticker = BoardSticker(
        id: 'sticker-1',
        type: 'english_quick_input_card',
        normalizedRect: const Rect.fromLTWH(0.1, 0.2, 0.4, 0.15),
        rawText: 'The teacher explained the lesson',
        rotation: 0.25,
        tokens: [
          {'text': 'The', 'role': 'OTHER', 'pos': 'DET', 'dep': 'det'},
          {'text': 'teacher', 'role': 'SUBJECT', 'pos': 'NOUN', 'dep': 'nsubj'},
          {'text': 'explained', 'role': 'VERB', 'pos': 'VERB', 'dep': 'ROOT'},
          {'text': 'the', 'role': 'OTHER', 'pos': 'DET', 'dep': 'det'},
          {'text': 'lesson', 'role': 'OBJECT', 'pos': 'NOUN', 'dep': 'dobj'},
        ],
      );

      final json = sticker.toJson();
      expect(json['id'], 'sticker-1');
      expect(json['type'], 'english_quick_input_card');
      expect(json['rect'], [0.1, 0.2, 0.4, 0.15]);
      expect(json['rawText'], 'The teacher explained the lesson');
      expect(json['rotation'], 0.25);
      expect(json['tokens'], [
        {'text': 'The'},
        {'text': 'teacher'},
        {'text': 'explained'},
        {'text': 'the'},
        {'text': 'lesson'},
      ]);

      final restored = BoardSticker.fromJson(json);
      expect(restored.id, sticker.id);
      expect(restored.type, sticker.type);
      expect(restored.normalizedRect.left, closeTo(0.1, 0.001));
      expect(restored.normalizedRect.top, closeTo(0.2, 0.001));
      expect(restored.normalizedRect.width, closeTo(0.4, 0.001));
      expect(restored.normalizedRect.height, closeTo(0.15, 0.001));
      expect(restored.rotation, closeTo(0.25, 0.001));
      expect(restored.tokens.length, 5);
    });

    test(
      'StudioState manages stickers and Canva selection state correctly',
      () {
        final studio = StudioState()..loading = false;
        expect(studio.currentStickers, isEmpty);
        expect(studio.selectedStickerId, isNull);

        final sticker1 = BoardSticker(
          id: 's1',
          type: 'english_quick_input_card',
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
        expect(studio.selectedStickerId, 's1'); // auto-selected on add

        // Test deselect and select
        studio.selectSticker(null);
        expect(studio.selectedStickerId, isNull);

        studio.selectSticker('s1');
        expect(studio.selectedStickerId, 's1');

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
        expect(studio.selectedStickerId, isNull);

        studio.dispose();
      },
    );

    testWidgets(
      'BoardStickerCard renders unclassified text tokens and triggers delete',
      (tester) async {
        final sticker = BoardSticker(
          id: 's-widget',
          type: 'english_quick_input_card',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.4, 0.2),
          rawText: 'He runs',
          tokens: [
            {'text': 'He', 'role': 'SUBJECT'},
            {'text': 'runs', 'role': 'VERB'},
          ],
        );

        bool deleted = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardStickerCard(
                sticker: sticker,
                isSelected: true,
                onDelete: () => deleted = true,
                onUpdateRect: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('He'), findsOneWidget);
        expect(find.text('runs'), findsOneWidget);
        expect(find.text('S'), findsNothing);
        expect(find.text('V'), findsNothing);

        // Tap close / delete button
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(deleted, isTrue);
      },
    );

    testWidgets(
      'BoardStickerCard renders title badge and SVG content in selected mode',
      (tester) async {
        final sticker = BoardSticker(
          id: 's-svg-card',
          type: 'generic_card',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.4, 0.3),
          rawText: 'Bảng biến thiên hàm số',
          title: 'Bảng biến thiên: y = x³ - 3x + 1',
          svgContent:
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"><text x="10" y="25">SVG BBT</text></svg>',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardStickerCard(
                sticker: sticker,
                isSelected: true,
                onDelete: () {},
                onUpdateRect: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Bảng biến thiên: y = x³ - 3x + 1'), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
      },
    );

    testWidgets(
      'BoardStickerFloatingBar renders action items and triggers callbacks',
      (tester) async {
        final sticker = BoardSticker(
          id: 's-canva',
          type: 'math_studio',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.4),
          rawText: 'y = 1.5 + sin(x)',
          title: 'Đồ thị: y = 1.5 + sin(x)',
          svgContent:
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"><text x="10" y="25">y = 1.5 + sin(x)</text></svg>',
        );

        bool deleted = false;
        bool duplicated = false;
        bool edited = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: BoardStickerFloatingBar(
                  sticker: sticker,
                  onDelete: () => deleted = true,
                  onEdit: () => edited = true,
                  onDuplicate: () => duplicated = true,
                ),
              ),
            ),
          ),
        );

        // Expect compact 3-button Floating Action Bar items
        expect(find.text('Sửa'), findsOneWidget);
        expect(find.text('Nhân bản'), findsOneWidget);
        expect(find.text('Xóa'), findsOneWidget);
        expect(find.text('Phát quay'), findsNothing);
        expect(find.text('Sách GK'), findsNothing);

        // Tap 'Sửa'
        await tester.tap(find.text('Sửa'));
        await tester.pump();
        expect(edited, isTrue);

        // Tap 'Nhân bản'
        await tester.tap(find.text('Nhân bản'));
        await tester.pump();
        expect(duplicated, isTrue);

        // Tap 'Xóa'
        await tester.tap(find.text('Xóa'));
        await tester.pump();
        expect(deleted, isTrue);
      },
    );

    testWidgets(
      'BoardStickerCard renders purely transparent content when deselected',
      (tester) async {
        final sticker = BoardSticker(
          id: 's-deselected',
          type: 'math_studio',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.4),
          rawText: 'y = x^3 - 3x',
          svgContent:
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 50"><text x="10" y="25">y = x³ - 3x</text></svg>',
        );

        bool selected = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardStickerCard(
                sticker: sticker,
                isSelected: false,
                onSelect: () => selected = true,
                onDelete: () {},
                onUpdateRect: (_) {},
              ),
            ),
          ),
        );

        // In Deselected mode: Floating Action Bar and handles must NOT be rendered
        expect(find.text('Phát quay'), findsNothing);
        expect(find.text('Nhân bản'), findsNothing);
        expect(find.byType(SvgPicture), findsOneWidget);

        // Tap sticker to select
        await tester.tap(find.byType(BoardStickerCard));
        await tester.pump();
        expect(selected, isTrue);
      },
    );

    testWidgets(
      'BoardStickerCard falls back gracefully to imageBase64 when svgContent is malformed',
      (tester) async {
        // 1x1 transparent PNG base64
        const samplePng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
        final sticker = BoardSticker(
          id: 's-fallback',
          type: 'math_studio',
          normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.5, 0.4),
          rawText: 'f(x) = x^3 - 3x',
          // Malformed SVG with broken quote
          svgContent: '<svg><text font-family=""Broken">Test</text></svg>',
          imageBase64: 'data:image/png;base64,$samplePng',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BoardStickerCard(
                sticker: sticker,
                isSelected: true,
                onDelete: () {},
                onUpdateRect: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        // Since SVG failed, Image should be present via errorBuilder fallback
        expect(find.byType(Image), findsOneWidget);
      },
    );
  });

  test('legacy sticker parser metadata and grammar issues are discarded', () {
    final restored = BoardSticker.fromJson({
      'id': 'legacy-role-sticker',
      'type': 'generic_card',
      'rect': [0, 0, 1, 1],
      'rawText': 'The teacher reads.',
      'tokens': [
        {
          'text': 'teacher',
          'role': 'SUBJECT',
          'pos': 'NOUN',
          'dep': 'nsubj',
        },
        {'text': 'reads', 'role': 'VERB', 'pos': 'VERB', 'dep': 'ROOT'},
      ],
      'issues': ['S-V-O sentence is correct'],
    });

    expect(restored.tokens, [
      {'text': 'teacher'},
      {'text': 'reads'},
    ]);
    expect(restored.toJson().containsKey('issues'), isFalse);
  });
}
