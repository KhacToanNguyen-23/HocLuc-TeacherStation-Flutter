import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/board_sticker.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/canvas_drawing_controller.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/pdf_smart_pen_controller.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/audio_sync_controller.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/studio_plugin_bridge_controller.dart';

void main() {
  group('CanvasDrawingController Tests', () {
    late CanvasDrawingController controller;

    setUp(() {
      controller = CanvasDrawingController();
    });

    test('Initializes with default first page and pen tool', () {
      expect(controller.page, 0);
      expect(controller.tool, 'pen');
      expect(controller.pages.isNotEmpty, isTrue);
      expect(controller.currentStrokes, isEmpty);
      expect(controller.canUndo, isFalse);
    });

    test('Adding strokes updates undo stack and current page', () {
      final stroke = BoardStroke(
        const Color(0xffffffff),
        3.5,
        const [Offset(10, 10), Offset(20, 20)],
      );
      controller.addStroke(stroke);
      expect(controller.currentStrokes.length, 1);
      expect(controller.canUndo, isTrue);

      controller.undo();
      expect(controller.currentStrokes.length, 0);
      expect(controller.canRedo, isTrue);

      controller.redo();
      expect(controller.currentStrokes.length, 1);
    });

    test('Managing stickers works correctly', () {
      final sticker = BoardSticker(
        id: 'stk-1',
        type: 'test_sticker',
        normalizedRect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.2),
        rawText: 'hello',
        tokens: [
          {'text': 'hello'},
        ],
      );
      controller.addSticker(sticker);
      expect(controller.currentStickers.length, 1);
      expect(controller.currentStickers.first.id, 'stk-1');

      controller.removeSticker('stk-1');
      expect(controller.currentStickers, isEmpty);
    });
  });

  group('PdfSmartPenController Tests', () {
    late PdfSmartPenController controller;

    setUp(() {
      controller = PdfSmartPenController();
    });

    test('Initializes with default empty PDF state', () {
      expect(controller.pdfPage, 1);
      expect(controller.pdfTotalPages, 1);
      expect(controller.importedDocs, isEmpty);
      expect(controller.activeDoc, isNull);
    });

    test('Changing PDF page bounds works correctly', () {
      controller.setPdfTotalPages(5);
      expect(controller.pdfTotalPages, 5);

      controller.setPdfPage(3);
      expect(controller.pdfPage, 3);

      controller.nextPdfPage();
      expect(controller.pdfPage, 4);

      controller.prevPdfPage();
      expect(controller.pdfPage, 3);
    });

    test('Adding and removing annotations per page', () {
      final stroke = BoardStroke(
        const Color(0xffff0000),
        2.0,
        const [Offset(5, 5)],
      );
      controller.addPdfAnnotation(1, stroke);
      expect(controller.pdfAnnotationsForPage(1).length, 1);
      expect(controller.pdfAnnotationsForPage(2), isEmpty);
    });
  });

  group('AudioSyncController Tests', () {
    late AudioSyncController controller;

    setUp(() {
      controller = AudioSyncController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initializes with default audio runtime', () {
      expect(controller.language, 'Tiếng Việt');
      expect(controller.isMicActive, isNotNull);
    });

    test('Toggling mic updates active state', () {
      controller.setMicActive(true);
      expect(controller.isMicActive, isTrue);
    });
  });

  group('StudioPluginBridgeController Tests', () {
    late StudioPluginBridgeController controller;

    setUp(() {
      controller = StudioPluginBridgeController();
    });

    test('Initializes with closed plugin state', () {
      expect(controller.activePlugin, isNull);
      expect(controller.showPluginDrawer, isFalse);
      expect(controller.pluginFloating, isFalse);
    });

    test('Updating floating window position and size', () {
      controller.setPluginFloatingPosition(const Offset(120, 240));
      expect(controller.pluginFloatingPosition, const Offset(120, 240));

      controller.togglePluginFloating();
      expect(controller.pluginFloating, isTrue);

      controller.closeFloatingPlugin();
      expect(controller.pluginFloating, isFalse);
    });
  });
}
