import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/stroke_canvas.dart';
import 'package:teaching_companion/features/studio_board/presentation/interactive_chalkboard.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_drawing_toolbar.dart';

void main() {
  setUpAll(() async {
    for (final name in ['Manrope', 'Literata']) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'explicit pen/highlighter metadata survives copy and JSON, including legacy strokes',
    () {
      final pen = BoardStroke(Colors.white, 10, [
        const Offset(.2, .2),
      ], isHighlighter: false);
      expect(BoardStroke.fromJson(pen.toJson()).isHighlighter, isFalse);
      expect(pen.copy().isHighlighter, isFalse);
      final marker = BoardStroke(Colors.yellow, 3, [
        const Offset(.2, .2),
      ], isHighlighter: true);
      expect(BoardStroke.fromJson(marker.toJson()).isHighlighter, isTrue);
      final legacy = pen.toJson()..remove('isHighlighter');
      expect(BoardStroke.fromJson(legacy).isHighlighter, isTrue);
    },
  );

  testWidgets(
    'one drag creates one stroke, a tap creates a dot, cancel leaves no stroke',
    (tester) async {
      final studio = StudioState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StrokeCanvas(studio: studio)),
        ),
      );
      await tester.dragFrom(const Offset(100, 100), const Offset(200, 100));
      await tester.pump();
      expect(studio.strokes, hasLength(1));
      expect(studio.strokes.single.points.length, greaterThan(1));
      await tester.tapAt(const Offset(400, 200));
      await tester.pump();
      expect(studio.strokes, hasLength(2));
      expect(studio.strokes.last.points, hasLength(1));
      final gesture = await tester.startGesture(const Offset(100, 300));
      await gesture.moveBy(const Offset(100, 0));
      await gesture.cancel();
      await tester.pump();
      expect(studio.strokes, hasLength(2));
      await tester.pumpWidget(const SizedBox());
      studio.dispose();
    },
  );

  testWidgets(
    'width settings, redo and safe clear work in both toolbar orientations',
    (tester) async {
      for (final vertical in [false, true]) {
        final studio = StudioState();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: StudioDrawingToolbar(
                  studio: studio,
                  isVertical: vertical,
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('Độ dày và xem trước nét'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10.0 px'));
        await tester.pump();
        expect(studio.strokeWidth, 10);
        await tester.tap(find.text('Xong'));
        await tester.pumpAndSettle();
        studio.startStroke(const Offset(.1, .1));
        expect(studio.strokes.single.isHighlighter, isFalse);
        await tester.pump();
        await tester.tap(find.byTooltip('Hoàn tác nét'));
        await tester.pump();
        expect(studio.strokes, isEmpty);
        await tester.tap(find.byTooltip('Làm lại nét'));
        await tester.pump();
        expect(studio.strokes, hasLength(1));
        await tester.tap(find.byTooltip('Xóa nét trang này'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hủy'));
        await tester.pumpAndSettle();
        expect(studio.strokes, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        studio.dispose();
      }
    },
  );

  testWidgets(
    'zoom changes viewport without changing drawing and resets to 100 percent',
    (tester) async {
      final studio = StudioState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: InteractiveChalkboard(studio: studio)),
        ),
      );
      await tester.tap(find.byTooltip('Phóng to bảng'));
      await tester.pump();
      expect(find.text('120%'), findsOneWidget);
      await tester.tap(find.text('120%'));
      await tester.pump();
      expect(find.text('100%'), findsOneWidget);
      expect(studio.strokes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      studio.dispose();
    },
  );

  testWidgets('hand tool pans the board without inking', (tester) async {
    final studio = StudioState()..tool = 'pan';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: InteractiveChalkboard(studio: studio)),
      ),
    );
    await tester.tap(find.byTooltip('Phóng to bảng'));
    await tester.pump();
    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    final before = controller.value.clone();
    await tester.dragFrom(const Offset(400, 300), const Offset(50, 20));
    await tester.pump();
    expect(controller.value, isNot(before));
    expect(studio.strokes, isEmpty);
    await tester.pumpWidget(const SizedBox());
    studio.dispose();
  });

  testWidgets('toolbar fits narrow layouts and captures real Flutter preview', (
    tester,
  ) async {
    for (final width in [320.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      final studio = StudioState();
      studio.startStroke(const Offset(.15, .3));
      studio.extendStroke(const Offset(.4, .45));
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              backgroundColor: const Color(0xff1b2b25),
              body: ListenableBuilder(
                listenable: studio,
                builder: (context, _) => Row(
                  children: [
                    StudioDrawingToolbar(studio: studio, isVertical: true),
                    Expanded(child: InteractiveChalkboard(studio: studio)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (width == 1440 && const bool.fromEnvironment('CAPTURE_BOARD')) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await tester.runAsync(() => boundary.toImage());
        final bytes = await tester.runAsync(
          () => image!.toByteData(format: ui.ImageByteFormat.png),
        );
        File(
          '../plans/board-tools-refinement/board-preview.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image!.dispose();
      }
      await tester.pumpWidget(const SizedBox());
      studio.dispose();
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
