import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

BoardStroke ink(Color color) => BoardStroke(color, 4, [const Offset(.3, .3)]);
void main() {
  test(
    'deleting earlier page keeps active page and redo attached to its own content',
    () {
      final s = StudioState();
      addTearDown(s.dispose);
      s.renamePage(0, 'A');
      s.addPage('B');
      final b = ink(Colors.red);
      s.addStroke(b);
      s.undo();
      s.addSticker(
        BoardSticker(
          id: 'B',
          type: 'test',
          normalizedRect: const Rect.fromLTWH(.1, .1, .2, .2),
          rawText: 'B',
        ),
      );
      s.setPageNote(1, 'note B');
      s.addPage('C');
      s.addStroke(ink(Colors.blue));
      s.setPage(1);
      s.deletePage(0);
      expect(s.page, 0);
      expect(s.pageTitles[s.page], 'B');
      expect(s.currentPageNote, 'note B');
      expect(s.currentStickers.single.id, 'B');
      expect(s.canRedo, isTrue);
      s.redo();
      expect(s.strokes.single, same(b));
      s.setPage(1);
      expect(s.strokes.single.color, Colors.blue);
      expect(s.canRedo, isFalse);
    },
  );
  test('deleting the last page resets its content, notes, title and redo', () {
    final s = StudioState();
    addTearDown(s.dispose);
    s.renamePage(0, 'Old');
    s.setPageNote(0, 'Old note');
    s.addStroke(ink(Colors.red));
    s.undo();
    s.addSticker(
      BoardSticker(
        id: 'old',
        type: 'test',
        normalizedRect: const Rect.fromLTWH(.1, .1, .2, .2),
        rawText: 'old',
      ),
    );
    s.deletePage(0);
    expect(s.pages, hasLength(1));
    expect(s.page, 0);
    expect(s.strokes, isEmpty);
    expect(s.currentStickers, isEmpty);
    expect(s.currentPageNote, isEmpty);
    expect(s.pageTitles.single, 'Khám phá bài học');
    expect(s.canRedo, isFalse);
  });
  for (final operation in [
    'add',
    'delete',
    'rename',
    'note',
    'clear',
    'clearStrokes',
  ]) {
    test(
      '$operation marks a previously saved board dirty before notifying',
      () {
        final s = StudioState();
        addTearDown(s.dispose);
        s.addStroke(ink(Colors.red));
        s.dirty = false;
        final observed = <bool>[];
        s.addListener(() => observed.add(s.dirty));
        switch (operation) {
          case 'add':
            s.addPage();
            break;
          case 'delete':
            s.deletePage(0);
            break;
          case 'rename':
            s.renamePage(0, 'New');
            break;
          case 'note':
            s.setPageNote(0, 'New note');
            break;
          case 'clear':
            s.clearPage();
            break;
          case 'clearStrokes':
            s.clearPageStrokes();
            break;
        }
        expect(s.dirty, isTrue);
        expect(observed, isNotEmpty);
        expect(observed.every((v) => v), isTrue);
      },
    );
  }
}
