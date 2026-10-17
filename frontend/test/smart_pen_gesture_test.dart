import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/smart_pen_answer_index.dart';
import 'package:teaching_companion/widgets/stroke_canvas.dart';
import 'package:teaching_companion/widgets/studio/studio_drawing_toolbar.dart';

void main() {
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

    testWidgets('does not impose a tap duration limit beyond Flutter defaults', (
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
    });

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
}

SmartPenPendingTap _tap(int page, int generation, Offset point) =>
    SmartPenPendingTap(
      pageNumber: page,
      documentGeneration: generation,
      pagePoint: point,
    );
