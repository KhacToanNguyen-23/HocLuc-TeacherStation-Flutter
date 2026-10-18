import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/smart_pen_answer_index.dart';
import 'package:teaching_companion/widgets/pdf_stage.dart';
import 'package:teaching_companion/widgets/stroke_canvas.dart';
import 'package:teaching_companion/widgets/studio/studio_drawing_toolbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smart Pen tap queue', () {
    test('takes matching page and generation taps in original order', () {
      final queue = SmartPenTapQueue(maxLength: 32);
      final first = _tap(4, 12, const Offset(0.1, 0.2));
      final otherPage = _tap(5, 12, const Offset(0.3, 0.4));
      final second = _tap(4, 12, const Offset(0.5, 0.6));
      final staleGeneration = _tap(4, 11, const Offset(0.7, 0.8));
      queue.enqueue(first);
      queue.enqueue(otherPage);
      queue.enqueue(second);
      queue.enqueue(staleGeneration);

      expect(queue.takeForPage(4, 12), [first, second]);
      expect(queue.takeForPage(5, 12), [otherPage]);
      expect(queue.takeForPage(4, 11), [staleGeneration]);
      expect(queue.length, 0);
    });

    test(
      'caps at 32 taps and rejects overflow without evicting queued work',
      () {
        final queue = SmartPenTapQueue(maxLength: 32);
        final accepted = List.generate(
          32,
          (i) => _tap(1, 8, Offset(i / 32, 0.5)),
        );

        for (final tap in accepted) {
          expect(queue.enqueue(tap), isTrue);
        }
        final overflow = _tap(1, 8, const Offset(1, 1));

        expect(queue.enqueue(overflow), isFalse);
        expect(queue.length, 32);
        expect(queue.takeForPage(1, 8), accepted);
        expect(queue.length, 0);
      },
    );

    test('clear discards pending taps', () {
      final queue = SmartPenTapQueue(maxLength: 32);
      queue.enqueue(_tap(2, 3, const Offset(0.2, 0.4)));

      queue.clear();

      expect(queue.length, 0);
      expect(queue.takeForPage(2, 3), isEmpty);
    });
  });

  group('Smart Pen nearby page scheduler', () {
    test(
      'keeps one build in flight and reprioritizes the newly visible page',
      () async {
        final firstPageBuild = Completer<void>();
        final startedPages = <int>[];
        var inFlight = 0;
        var maxInFlight = 0;
        final scheduler = SmartPenPageIndexScheduler(
          documentGeneration: 18,
          pageCount: 12,
          nearbyPageRadius: 2,
          buildPageIndex: (pageNumber, generation) {
            expect(generation, 18);
            startedPages.add(pageNumber);
            inFlight++;
            if (inFlight > maxInFlight) maxInFlight = inFlight;
            final build = pageNumber == 1
                ? firstPageBuild.future
                : Future<void>.delayed(Duration.zero);
            return build.whenComplete(() => inFlight--);
          },
        );

        scheduler.requestPage(1);
        await Future<void>.delayed(Duration.zero);
        scheduler.requestPage(2);
        scheduler.requestPage(3);
        scheduler.setVisiblePage(9);
        await Future<void>.delayed(Duration.zero);

        expect(startedPages, [1]);
        firstPageBuild.complete();
        await scheduler.whenIdle();

        expect(startedPages[1], 9);
        expect(startedPages, [1, 9, 8, 10, 7, 11, 2, 3]);
        expect(startedPages, containsAll([7, 8, 9, 10, 11]));
        expect(maxInFlight, 1);
        expect(inFlight, 0);
      },
    );

    test(
      'ignores out-of-range pages and loads current page before neighbors',
      () async {
        final startedPages = <int>[];
        final scheduler = SmartPenPageIndexScheduler(
          documentGeneration: 2,
          pageCount: 6,
          nearbyPageRadius: 2,
          buildPageIndex: (pageNumber, generation) async {
            startedPages.add(pageNumber);
          },
        );

        scheduler.requestPage(0);
        scheduler.requestPage(7);
        scheduler.setVisiblePage(4);
        await scheduler.whenIdle();

        expect(startedPages.first, 4);
        expect(startedPages, containsAll([2, 3, 4, 5, 6]));
        expect(startedPages, everyElement(inInclusiveRange(1, 6)));
      },
    );

    test(
      '100-page document starts with the visible page, not a full scan',
      () async {
        final visibleBuild = Completer<void>();
        final startedPages = <int>[];
        final scheduler = SmartPenPageIndexScheduler(
          documentGeneration: 31,
          pageCount: 100,
          nearbyPageRadius: 2,
          buildPageIndex: (pageNumber, generation) {
            expect(generation, 31);
            startedPages.add(pageNumber);
            return pageNumber == 50
                ? visibleBuild.future
                : Future<void>.value();
          },
        );

        scheduler.setVisiblePage(50);
        await Future<void>.delayed(Duration.zero);

        expect(startedPages, [50]);
        visibleBuild.complete();
        await scheduler.whenIdle();

        expect(startedPages, [50, 49, 51, 48, 52]);
        expect(startedPages, isNot(contains(1)));
        expect(startedPages, isNot(contains(100)));
      },
    );
  });

  group('Smart Pen toggle and drawing toolbar', () {
    test('toggle preserves current pen, color, and width settings', () {
      final studio = StudioState()
        ..tool = 'highlight'
        ..ink = const Color(0xff123456)
        ..strokeWidth = 7.25
        ..highlighterWidth = 19;
      addTearDown(studio.dispose);

      studio.setSmartSnapEnabled(true);

      expect(studio.smartSnapEnabled, isTrue);
      expect(studio.tool, 'highlight');
      expect(studio.ink, const Color(0xff123456));
      expect(studio.strokeWidth, 7.25);
      expect(studio.highlighterWidth, 19);

      studio.setSmartSnapEnabled(false);
      expect(studio.smartSnapEnabled, isFalse);
      expect(studio.tool, 'highlight');
    });

    test('save toggle is independent from Smart Snap and drawing settings', () {
      final studio = StudioState()
        ..tool = 'highlight'
        ..ink = const Color(0xff123456)
        ..strokeWidth = 7.25;
      addTearDown(studio.dispose);

      expect(studio.saveAnswerCirclesEnabled, isTrue);
      studio.setSaveAnswerCirclesEnabled(false);
      expect(studio.saveAnswerCirclesEnabled, isFalse);
      expect(studio.smartSnapEnabled, isFalse);
      expect(studio.tool, 'highlight');
      expect(studio.ink, const Color(0xff123456));
      expect(studio.strokeWidth, 7.25);

      studio.setSmartSnapEnabled(true);
      expect(studio.saveAnswerCirclesEnabled, isFalse);
      studio.setSaveAnswerCirclesEnabled(true);
      expect(studio.smartSnapEnabled, isTrue);
    });

    for (final isVertical in [false, true]) {
      testWidgets(
        'shows and toggles Smart Snap in ${isVertical ? 'vertical' : 'horizontal'} toolbar',
        (tester) async {
          final studio = StudioState();
          addTearDown(studio.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: StudioDrawingToolbar(
                  studio: studio,
                  isVertical: isVertical,
                ),
              ),
            ),
          );

          final toggle = find.byTooltip('Tự động bắt đáp án');
          expect(toggle, findsOneWidget);
          expect(studio.smartSnapEnabled, isFalse);

          await tester.tap(toggle);
          await tester.pump();

          expect(studio.smartSnapEnabled, isTrue);

          final saveToggle = find.byTooltip('Lưu khoanh đáp án');
          expect(saveToggle, findsOneWidget);
          expect(studio.saveAnswerCirclesEnabled, isTrue);
          await tester.tap(saveToggle);
          await tester.pump();
          expect(studio.saveAnswerCirclesEnabled, isFalse);
          expect(studio.smartSnapEnabled, isTrue);
        },
      );
    }
  });

  group('StrokeCanvas Smart Pen routing', () {
    testWidgets('uses Flutter tap movement slop for touch pointers', (
      tester,
    ) async {
      final studio = StudioState()..setSmartSnapEnabled(true);
      addTearDown(studio.dispose);
      final routedTaps = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: StrokeCanvas(
                studio: studio,
                smartSnapEnabled: true,
                onSmartTap: routedTaps.add,
                deferTapToOverlay: true,
              ),
            ),
          ),
        ),
      );

      // Flutter's default touch tap slop is 18 logical pixels (inclusive).
      final atBoundary = await tester.startGesture(
        const Offset(40, 20),
        kind: PointerDeviceKind.touch,
      );
      await atBoundary.moveBy(const Offset(18, 0));
      await atBoundary.up();
      await tester.pump();

      expect(routedTaps, hasLength(1));
      expect(studio.strokes, isEmpty);
    });

    testWidgets('routes touch movement beyond tap slop into the stroke path', (
      tester,
    ) async {
      final studio = StudioState()..setSmartSnapEnabled(true);
      addTearDown(studio.dispose);
      final routedTaps = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: StrokeCanvas(
                studio: studio,
                smartSnapEnabled: true,
                onSmartTap: routedTaps.add,
                deferTapToOverlay: true,
              ),
            ),
          ),
        ),
      );

      final beyondBoundary = await tester.startGesture(
        const Offset(40, 20),
        kind: PointerDeviceKind.touch,
      );
      await beyondBoundary.moveBy(const Offset(19, 0));
      await beyondBoundary.up();
      await tester.pump();

      expect(routedTaps, isEmpty);
      expect(studio.strokes, hasLength(1));
      expect(studio.strokes.single.points, hasLength(1));
    });

    testWidgets(
      'does not impose a tap duration limit beyond Flutter defaults',
      (tester) async {
        final studio = StudioState()..setSmartSnapEnabled(true);
        addTearDown(studio.dispose);
        final routedTaps = <Offset>[];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 100,
                child: StrokeCanvas(
                  studio: studio,
                  smartSnapEnabled: true,
                  onSmartTap: routedTaps.add,
                ),
              ),
            ),
          ),
        );

        final heldPointer = await tester.startGesture(
          const Offset(40, 20),
          kind: PointerDeviceKind.touch,
        );
        await tester.pump(const Duration(milliseconds: 600));
        await heldPointer.up();
        await tester.pump();

        expect(routedTaps, [const Offset(0.2, 0.2)]);
        expect(studio.strokes, isEmpty);
      },
    );

    testWidgets('routes a smart tap without committing the normal tap dot', (
      tester,
    ) async {
      final studio = StudioState()..setSmartSnapEnabled(true);
      addTearDown(studio.dispose);
      final routedTaps = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: StrokeCanvas(
                studio: studio,
                smartSnapEnabled: true,
                onSmartTap: routedTaps.add,
                deferTapToOverlay: true,
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(40, 20));
      await tester.pump();

      expect(routedTaps, [const Offset(0.2, 0.2)]);
      expect(studio.strokes, isEmpty);
    });

    testWidgets('preserves freehand drags while Smart Snap is enabled', (
      tester,
    ) async {
      final studio = StudioState()..setSmartSnapEnabled(true);
      addTearDown(studio.dispose);
      final routedTaps = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: StrokeCanvas(
                studio: studio,
                smartSnapEnabled: true,
                onSmartTap: routedTaps.add,
                deferTapToOverlay: true,
              ),
            ),
          ),
        ),
      );
      await tester.dragFrom(const Offset(20, 20), const Offset(80, 50));
      await tester.pump();

      expect(studio.strokes, hasLength(1));
      expect(studio.strokes.single.points.length, greaterThan(1));
      expect(routedTaps, isEmpty);
    });

    testWidgets('keeps the existing pen dot behavior when Smart Snap is off', (
      tester,
    ) async {
      final studio = StudioState()..setSmartSnapEnabled(false);
      addTearDown(studio.dispose);
      final routedTaps = <Offset>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 100,
              child: StrokeCanvas(
                studio: studio,
                smartSnapEnabled: false,
                onSmartTap: routedTaps.add,
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(40, 20));
      await tester.pump();

      expect(routedTaps, isEmpty);
      expect(studio.strokes, hasLength(1));
      expect(studio.strokes.single.points, [const Offset(0.2, 0.2)]);
    });
  });

  testWidgets('PdfStage routes an answer tap into a Smart Pen oval', (
    tester,
  ) async {
    await tester.runAsync(pdfrx.pdfrxInitialize);
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final studio = StudioState()
      ..setPdfFile('smart-pen-e2e.pdf', _answerFixturePdf())
      ..setSmartSnapEnabled(true);
    addTearDown(studio.dispose);
    final routedAnswers = <SmartPenAnswerCandidate>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox.expand(
            child: PdfStage(
              studio: studio,
              onSmartAnswerTap: routedAnswers.add,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(StrokeCanvas).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    expect(find.byType(StrokeCanvas), findsOneWidget);

    final canvasRect = tester.getRect(find.byType(StrokeCanvas).first);
    await tester.tapAt(canvasRect.topLeft + const Offset(45, 55));
    await tester.pump();
    for (var i = 0; i < 30 && routedAnswers.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    expect(routedAnswers, hasLength(1));
    expect(
      studio.pdfAnnotations[1]?.where((s) => s.isSmartPenOval),
      hasLength(1),
    );
    expect(studio.pdfAnnotations[1], hasLength(1));
    expect(
      studio.pdfAnnotations[1]!.every((stroke) => stroke.isSmartPenOval),
      isTrue,
    );
    if (const bool.fromEnvironment('SMART_PEN_DEBUG')) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter?.runtimeType.toString().contains(
                    'SmartPenDebugBoundsPainter',
                  ) ==
                  true,
        ),
        findsOneWidget,
        reason: 'Debug mode should mount the PDF extraction overlay painter',
      );
    } else {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is CustomPaint &&
              widget.painter?.runtimeType.toString().contains(
                    'SmartPenDebugBoundsPainter',
                  ) ==
                  true,
        ),
        findsNothing,
        reason:
            'Normal mode should not mount the PDF extraction overlay painter',
      );
    }
  });
}

SmartPenPendingTap _tap(int page, int generation, Offset point) =>
    SmartPenPendingTap(
      pageNumber: page,
      documentGeneration: generation,
      pagePoint: point,
    );

Uint8List _answerFixturePdf() {
  const stream =
      'BT /F1 12 Tf 18 TL 40 740 Td '
      '(A. First option) Tj T* '
      '(B. Second option) Tj T* '
      '(C. Third option) Tj T* '
      '(D. Fourth option) Tj ET';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [4 0 R] /Count 1 >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents 5 0 R >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(pdf.length);
    pdf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF',
  );
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}
