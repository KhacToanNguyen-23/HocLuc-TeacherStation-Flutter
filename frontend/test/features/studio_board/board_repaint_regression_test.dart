import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/stroke_canvas.dart';

Future<List<int>> centerPixel(WidgetTester tester, GlobalKey key) async {
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (50 * image.width + 50) * 4;
    final pixel = bytes.buffer
        .asUint8List(bytes.offsetInBytes + offset, 4)
        .toList();
    image.dispose();
    return pixel;
  }))!;
}

void main() {
  for (final operation in [
    'undo',
    'clearPage',
    'clearPageStrokes',
    'controllerErase',
  ]) {
    testWidgets(
      '$operation removes painted ink on the next frame without another touch',
      (tester) async {
        final studio = StudioState();
        final boundaryKey = GlobalKey();
        studio.addStroke(
          BoardStroke(Colors.red, 20, [
            const Offset(.5, .5),
          ], isHighlighter: false),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: ListenableBuilder(
                listenable: studio,
                builder: (context, _) => RepaintBoundary(
                  key: boundaryKey,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: ColoredBox(
                      color: Colors.black,
                      child: CustomPaint(
                        painter: CommittedStrokesPainter(
                          strokes: studio.strokes,
                          revision: studio.revision,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(await centerPixel(tester, boundaryKey), [244, 67, 54, 255]);
        switch (operation) {
          case 'undo':
            studio.undo();
            break;
          case 'clearPage':
            studio.clearPage();
            break;
          case 'clearPageStrokes':
            studio.clearPageStrokes();
            break;
          case 'controllerErase':
            studio.canvas.erase(const Offset(.5, .5));
            break;
        }
        expect(studio.strokes, isEmpty);
        // Deliberately no extra tap, hover, redraw request or widget replacement.
        await tester.pump();
        expect(await centerPixel(tester, boundaryKey), [0, 0, 0, 255]);
        if (operation == 'undo') {
          studio.redo();
          await tester.pump();
          expect(await centerPixel(tester, boundaryKey), [244, 67, 54, 255]);
        }
        await tester.pumpWidget(const SizedBox());
        studio.dispose();
      },
    );
  }

  test(
    'delegated mutations publish the updated revision before listeners run',
    () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.addStroke(BoardStroke(Colors.red, 4, [const Offset(.5, .5)]));
      final before = studio.revision;
      final observed = <int>[];
      studio.addListener(() => observed.add(studio.revision));
      studio.undo();
      expect(observed, isNotEmpty);
      expect(observed.every((revision) => revision > before), isTrue);
    },
  );
}
