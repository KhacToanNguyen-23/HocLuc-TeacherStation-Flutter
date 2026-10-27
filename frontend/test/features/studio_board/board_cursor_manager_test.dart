import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/services/board_cursor_manager.dart';

void main() {
  group('BoardCursorManager Tests', () {
    setUp(() {
      BoardCursorManager.resetForTest();
    });

    test('Hotspot coordinates are defined accurately', () {
      expect(BoardCursorManager.penHotX, equals(1));
      expect(BoardCursorManager.penHotY, equals(1));
      expect(BoardCursorManager.eraserHotX, equals(13));
      expect(BoardCursorManager.eraserHotY, equals(27));
    });

    test('Returns default fallback cursors when custom assets are not loaded', () {
      expect(
        BoardCursorManager.getCursorForTool('pen'),
        equals(SystemMouseCursors.precise),
      );
      expect(
        BoardCursorManager.getCursorForTool('highlight'),
        equals(SystemMouseCursors.precise),
      );
      expect(
        BoardCursorManager.getCursorForTool('erase'),
        equals(SystemMouseCursors.grab),
      );
      expect(
        BoardCursorManager.getCursorForTool('laser'),
        equals(SystemMouseCursors.none),
      );
      expect(
        BoardCursorManager.getCursorForTool('pan'),
        equals(SystemMouseCursors.grab),
      );
      expect(
        BoardCursorManager.getCursorForTool('select'),
        equals(SystemMouseCursors.basic),
      );
    });

    test('Prioritizes capturesBoardInput over tool cursor', () {
      expect(
        BoardCursorManager.getCursorForTool(
          'pen',
          capturesBoardInput: true,
        ),
        equals(SystemMouseCursors.click),
      );
      expect(
        BoardCursorManager.getCursorForTool(
          'erase',
          capturesBoardInput: true,
        ),
        equals(SystemMouseCursors.click),
      );
    });

    test('Prioritizes spacebar pan navigation over tool cursor', () {
      expect(
        BoardCursorManager.getCursorForTool(
          'pen',
          isSpacePressed: true,
        ),
        equals(SystemMouseCursors.grab),
      );
      expect(
        BoardCursorManager.getCursorForTool(
          'erase',
          isSpacePressed: true,
        ),
        equals(SystemMouseCursors.grab),
      );
    });

    test('Returns custom cursors when available', () {
      final mockPen = SystemMouseCursors.cell;
      final mockEraser = SystemMouseCursors.alias;

      BoardCursorManager.setMockCursors(
        pen: mockPen,
        eraser: mockEraser,
      );

      expect(
        BoardCursorManager.getCursorForTool('pen'),
        equals(mockPen),
      );
      expect(
        BoardCursorManager.getCursorForTool('highlight'),
        equals(mockPen),
      );
      expect(
        BoardCursorManager.getCursorForTool('erase'),
        equals(mockEraser),
      );
    });
  });
}
