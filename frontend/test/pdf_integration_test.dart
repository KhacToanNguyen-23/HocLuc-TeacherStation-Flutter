import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/floating_pdf_window.dart';
import 'package:teaching_companion/widgets/stage_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('StudioState per-page PDF annotations isolation', () {
    final state = StudioState();
    state.setPdfFile('test.pdf', Uint8List(0));
    state.setPdfTotalPages(5);

    expect(state.pdfPage, equals(1));
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Annotate on page 1
    state.startStroke(const Offset(0.2, 0.2), target: state.currentPdfStrokes);
    state.extendStroke(const Offset(0.3, 0.3), target: state.currentPdfStrokes);
    expect(state.currentPdfStrokes.length, equals(1));
    expect(state.currentPdfStrokes.first.points.length, equals(2));

    // Switch to page 2 (clean slate)
    state.setPdfPage(2);
    expect(state.pdfPage, equals(2));
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Annotate on page 2
    state.startStroke(const Offset(0.5, 0.5), target: state.currentPdfStrokes);
    expect(state.currentPdfStrokes.length, equals(1));

    // Return to page 1 (retains annotations)
    state.setPdfPage(1);
    expect(state.currentPdfStrokes.length, equals(1));
    expect(
      state.currentPdfStrokes.first.points.first,
      equals(const Offset(0.2, 0.2)),
    );

    // Clear annotations for page 1
    state.clearPdfPage();
    expect(state.currentPdfStrokes.isEmpty, isTrue);

    // Page 2 still has its annotation
    state.setPdfPage(2);
    expect(state.currentPdfStrokes.length, equals(1));
  });

  group('Phase 04: FloatingPdfWindow Integration', () {
    testWidgets(
      'renders FloatingPdfWindow in split mode and closes to fullBoard',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final state = StudioState();
        state.addImportedDoc(
          'Giai-tich-12.pdf',
          '/docs/Giai-tich-12.pdf',
          Uint8List(0),
        );
        state.setViewportMode(StudioViewportMode.split);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StageContainer(studio: state)),
          ),
        );
        await tester.pump();

        // FloatingPdfWindow should be visible with document title
        expect(find.byType(FloatingPdfWindow), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(FloatingPdfWindow),
            matching: find.text('Giai-tich-12.pdf'),
          ),
          findsAtLeastNWidgets(1),
        );

        // Close button should return stage to fullBoard without removing document from shelf
        final closeButton = find.byTooltip('Đóng tài liệu trên bảng');
        expect(closeButton, findsOneWidget);
        await tester.tap(closeButton);
        await tester.pumpAndSettle();

        expect(state.viewportMode, equals(StudioViewportMode.fullBoard));
        expect(find.byType(FloatingPdfWindow), findsNothing);
        expect(state.importedDocs.length, equals(1));
        expect(state.importedDocs.first.name, equals('Giai-tich-12.pdf'));
      },
    );

    testWidgets('toggles maximize and resize handles properly', (tester) async {
      final state = StudioState();
      state.addImportedDoc(
        'Giai-tich-12.pdf',
        '/docs/Giai-tich-12.pdf',
        Uint8List(0),
      );
      state.setViewportMode(StudioViewportMode.split);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingPdfWindow(
                  studio: state,
                  boardConstraints: const BoxConstraints(
                    maxWidth: 1200,
                    maxHeight: 800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially not maximized
      expect(state.pdfWindowMaximized, isFalse);

      // Maximize
      final maxButton = find.byTooltip('Phóng to toàn màn hình');
      expect(maxButton, findsOneWidget);
      await tester.tap(maxButton);
      await tester.pump();
      expect(state.pdfWindowMaximized, isTrue);

      // Restore
      final restoreButton = find.byTooltip('Thu nhỏ cửa sổ');
      expect(restoreButton, findsOneWidget);
      await tester.tap(restoreButton);
      await tester.pump();
      expect(state.pdfWindowMaximized, isFalse);
    });

    testWidgets('toggles Fit Page / Fit Width button on header', (
      tester,
    ) async {
      final state = StudioState();
      state.addImportedDoc(
        'Giai-tich-12.pdf',
        '/docs/Giai-tich-12.pdf',
        Uint8List(0),
      );
      state.setViewportMode(StudioViewportMode.split);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                FloatingPdfWindow(
                  studio: state,
                  boardConstraints: const BoxConstraints(
                    maxWidth: 1200,
                    maxHeight: 800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially pdfFitPage is false (Fit Width)
      expect(state.pdfFitPage, isFalse);
      final fitPageBtn = find.byTooltip('Xem toàn bộ trang (Fit Page)');
      expect(fitPageBtn, findsOneWidget);

      // Tap to toggle to Fit Page
      await tester.tap(fitPageBtn);
      await tester.pump();
      expect(state.pdfFitPage, isTrue);

      // Now tooltip changes to Fit Width
      final fitWidthBtn = find.byTooltip('Vừa chiều rộng (Fit Width)');
      expect(fitWidthBtn, findsOneWidget);

      // Tap to toggle back to Fit Width
      await tester.tap(fitWidthBtn);
      await tester.pump();
      expect(state.pdfFitPage, isFalse);
    });

    test('StudioState space pressed sync for global pan', () {
      final state = StudioState();
      expect(state.isSpacePressed, isFalse);

      state.setSpacePressed(true);
      expect(state.isSpacePressed, isTrue);

      state.setSpacePressed(false);
      expect(state.isSpacePressed, isFalse);
    });
  });
}
