import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/stroke_clusterer.dart';
import 'package:teaching_companion/features/studio_board/presentation/stroke_canvas.dart';

void main() {
  group('Phase 03: Handwriting Stroke Clustering Tests', () {
    // Helper to generate simulated handwriting strokes for words
    List<BoardStroke> createSimulatedSentenceStrokes() {
      // "I" at x ~ 0.10 - 0.14, y ~ 0.30
      final strokeI = BoardStroke(Colors.white, 3.0, [
        const Offset(0.12, 0.28),
        const Offset(0.12, 0.32),
      ]);

      // "go" at x ~ 0.18 - 0.25, y ~ 0.30
      final strokeG = BoardStroke(Colors.white, 3.0, [
        const Offset(0.19, 0.29),
        const Offset(0.21, 0.31),
        const Offset(0.20, 0.33),
      ]);
      final strokeO = BoardStroke(Colors.white, 3.0, [
        const Offset(0.23, 0.29),
        const Offset(0.24, 0.31),
        const Offset(0.23, 0.32),
      ]);

      // "to" at x ~ 0.28 - 0.33, y ~ 0.30
      final strokeT = BoardStroke(Colors.white, 3.0, [
        const Offset(0.29, 0.28),
        const Offset(0.29, 0.32),
      ]);

      // "school" at x ~ 0.37 - 0.50, y ~ 0.30
      final strokeSchool = BoardStroke(Colors.white, 3.0, [
        const Offset(0.38, 0.29),
        const Offset(0.44, 0.30),
        const Offset(0.48, 0.31),
      ]);

      return [strokeI, strokeG, strokeO, strokeT, strokeSchool];
    }

    test('StrokeClusterer groups strokes into line and tokens accurately', () {
      final strokes = createSimulatedSentenceStrokes();

      // Touch near the center of the sentence with verified text
      final annotation = StrokeClusterer.clusterAndAnalyze(
        touchPoint: const Offset(0.25, 0.30),
        strokes: strokes,
        pageIndex: 0,
        hintText: 'I go to school',
      );

      expect(annotation, isNotNull);
      expect(annotation!.normalizedBounds.left, closeTo(0.12, 0.02));
      expect(annotation.normalizedBounds.right, closeTo(0.48, 0.03));
      expect(annotation.tokens.isNotEmpty, isTrue);

      // Must have S, V, O assigned
      final roles = annotation.tokens
          .map((t) => t.role)
          .whereType<String>()
          .toList();
      expect(roles, contains('subject'));
      expect(roles, contains('verb'));
      expect(roles, contains('object'));
    });

    test('StrokeClusterer returns null when touching empty canvas area', () {
      final strokes = createSimulatedSentenceStrokes();

      // Touch far away at (0.8, 0.8) where no strokes exist
      final annotation = StrokeClusterer.clusterAndAnalyze(
        touchPoint: const Offset(0.80, 0.80),
        strokes: strokes,
        pageIndex: 0,
      );

      expect(annotation, isNull);
    });

    test(
      'StudioState analyzeHandwritingAt adds SmartChalkAnnotation to board',
      () {
        final studio = StudioState();
        final strokes = createSimulatedSentenceStrokes();
        studio.pages[studio.page].addAll(strokes);

        expect(studio.currentChalkAnnotations.isEmpty, isTrue);

        final success = studio.analyzeHandwritingAt(const Offset(0.25, 0.30));
        expect(success, isTrue);
        expect(studio.currentChalkAnnotations.length, equals(1));
        expect(studio.currentChalkAnnotations.first.tokens.isNotEmpty, isTrue);
      },
    );

    testWidgets(
      'StrokeCanvas in SVO tool mode triggers analyzeHandwritingAt without creating new pen stroke',
      (tester) async {
        final studio = StudioState();
        final strokes = createSimulatedSentenceStrokes();
        studio.pages[studio.page].addAll(strokes);
        studio.openPlugin(
          InstalledPlugin(
            manifest: PluginManifest(
              id: 'test.handwriting',
              name: 'Handwriting Test',
              contributesTools: const [
                PluginToolContribution(
                  id: 'svo',
                  label: 'S-V-O',
                  capturesBoardInput: true,
                ),
              ],
            ),
          ),
        );
        studio.setActiveSubjectTool('svo');

        final initialStrokeCount = studio.strokes.length;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: StrokeCanvas(studio: studio),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap on canvas at (200, 180) which is norm (0.25, 0.30)
        await tester.tapAt(const Offset(200, 180));
        await tester.pumpAndSettle();

        // Stroke count must NOT increase (no accidental pen drawing)
        expect(studio.strokes.length, equals(initialStrokeCount));
        // Smart chalk annotation must have been created!
        expect(studio.currentChalkAnnotations.length, equals(1));
      },
    );
  });
}

