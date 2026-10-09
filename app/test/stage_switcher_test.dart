import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/stage_container.dart';
import 'package:teaching_companion/widgets/pdf_stage.dart';
import 'package:teaching_companion/widgets/stroke_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 04: 16:9 Ergonomic Stage & Viewport Switcher', () {
    test('StudioViewportMode transitions work correctly', () {
      final studio = StudioState();
      expect(studio.viewportMode, StudioViewportMode.fullBoard);

      studio.setViewportMode(StudioViewportMode.split);
      expect(studio.viewportMode, StudioViewportMode.split);

      studio.setViewportMode(StudioViewportMode.fullPdf);
      expect(studio.viewportMode, StudioViewportMode.fullPdf);

      studio.setViewportMode(StudioViewportMode.fullBoard);
      expect(studio.viewportMode, StudioViewportMode.fullBoard);
      studio.dispose();
    });

    testWidgets('StageContainer renders split view with PDF and Board', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioState()..setViewportMode(StudioViewportMode.split);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StageContainer(studio: studio)),
        ),
      );
      await tester.pump();

      expect(find.byType(PdfStage), findsOneWidget);
      expect(find.byType(StrokeCanvas), findsOneWidget);
      studio.dispose();
    });

    testWidgets('StageContainer renders Full Board mode', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioState()
        ..setViewportMode(StudioViewportMode.fullBoard);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StageContainer(studio: studio)),
        ),
      );
      await tester.pump();

      expect(find.byType(PdfStage), findsNothing);
      expect(find.byType(StrokeCanvas), findsOneWidget);
      studio.dispose();
    });

    testWidgets('ViewportModeSwitcher buttons switch modes on click', (
      tester,
    ) async {
      final studio = StudioState()..setViewportMode(StudioViewportMode.split);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ViewportModeSwitcher(studio: studio)),
        ),
      );
      await tester.pump();

      // Tap F1 button
      await tester.tap(find.text('Bảng (F1)'));
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.fullBoard);

      // Tap F2 button
      await tester.tap(find.text('PDF (F2)'));
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.fullPdf);

      // Tap F3 button
      await tester.tap(find.text('Chia đôi (F3)'));
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.split);
      studio.dispose();
    });

    testWidgets('Keyboard shortcuts F1, F2, F3 trigger mode switches', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioState()..setViewportMode(StudioViewportMode.split);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StageContainer(studio: studio)),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.fullBoard);

      await tester.sendKeyEvent(LogicalKeyboardKey.f2);
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.fullPdf);

      await tester.sendKeyEvent(LogicalKeyboardKey.f3);
      await tester.pump();
      expect(studio.viewportMode, StudioViewportMode.split);
      studio.dispose();
    });
  });
}
