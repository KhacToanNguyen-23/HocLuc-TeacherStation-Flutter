import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/plugin_manifest.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/plugin_manager.dart';
import 'package:teaching_companion/widgets/interactive_chalkboard.dart';
import 'package:teaching_companion/widgets/subject_tool_palette.dart';

void main() {
  group('Phase 05: In-Board S-V-O Chalk Tool Full End-to-End Test Suite', () {
    testWidgets(
      'Complete lifecycle: Dock activation -> S-V-O analysis -> PDF -> Eye toggle -> Drag & Save/Restore -> Close dock',
      (tester) async {
        final studio = StudioState();

        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // 1. Activate English assistant plugin
        final englishPlugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'com.hocluc.plugin.english',
            name: 'Trợ giảng Tiếng Anh',
            version: '1.0.0',
            author: 'Học Lực Dev Team',
            description: 'Hỗ trợ bóc tách cú pháp câu S-V-O phấn màu viết tay',
          ),
        );

        studio.openPlugin(englishPlugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 1200,
                height: 800,
                child: Stack(
                  children: [
                    InteractiveChalkboard(studio: studio),
                    SubjectToolPalette(studio: studio),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify Dock UI
        expect(find.byType(SubjectToolPalette), findsOneWidget);
        expect(find.text('Trợ giảng Tiếng Anh'), findsOneWidget);
        expect(find.text('Công cụ S-V-O'), findsOneWidget);

        // 2. Select S-V-O tool
        final svoBtn = find.byKey(const Key('svo_tool_button'));
        await tester.tap(svoBtn);
        await tester.pumpAndSettle();
        expect(studio.activeSubjectTool, equals('svo'));

        // 3. Teacher writes handwriting strokes on chalkboard
        studio.addStroke(
          BoardStroke(Colors.white, 3.0, [
            const Offset(0.20, 0.35),
            const Offset(0.25, 0.35),
          ]),
        );
        studio.addStroke(
          BoardStroke(Colors.white, 3.0, [
            const Offset(0.35, 0.35),
            const Offset(0.42, 0.35),
          ]),
        );
        studio.addStroke(
          BoardStroke(Colors.white, 3.0, [
            const Offset(0.50, 0.35),
            const Offset(0.60, 0.35),
          ]),
        );
        await tester.pumpAndSettle();

        // Tap near handwriting on board to analyze S-V-O
        final analyzed = studio.analyzeHandwritingAt(
          const Offset(0.35, 0.35),
          hintText: 'She loves English',
        );
        expect(analyzed, isTrue);
        await tester.pumpAndSettle();

        // Badges S, V, O appear on chalkboard
        expect(find.text('S'), findsOneWidget);
        expect(find.text('V'), findsOneWidget);
        expect(find.text('O'), findsOneWidget);

        // Verify annotation model
        final boardAnnotations = studio.currentChalkAnnotations;
        expect(boardAnnotations.length, equals(1));
        expect(boardAnnotations.first.source, equals('chalkboard'));
        final boardAnnId = boardAnnotations.first.id;

        // 4. Analyze sentence on PDF document (page 1)
        final pdfAnalyzed = studio.analyzePdfSentenceAt(
          1,
          const Offset(0.3, 0.6),
          sampleText: 'The teacher explains the grammar.',
        );
        expect(pdfAnalyzed, isTrue);
        final pdfAnnotations = studio.getPdfChalkAnnotations(1);
        expect(pdfAnnotations.length, equals(1));
        expect(pdfAnnotations.first.source, equals('pdf'));
        final pdfAnnId = pdfAnnotations.first.id;

        // 5. Eye toggle: hide all S-V-O annotations
        final eyeBtn = find.byIcon(Icons.visibility);
        expect(eyeBtn, findsOneWidget);
        await tester.tap(eyeBtn);
        await tester.pumpAndSettle();

        expect(studio.chalkAnnotationsVisible, isFalse);
        expect(find.text('S'), findsNothing);
        expect(find.text('V'), findsNothing);
        expect(find.text('O'), findsNothing);

        // Eye toggle: show annotations again
        final eyeOffBtn = find.byIcon(Icons.visibility_off);
        expect(eyeOffBtn, findsOneWidget);
        await tester.tap(eyeOffBtn);
        await tester.pumpAndSettle();

        expect(studio.chalkAnnotationsVisible, isTrue);
        expect(find.text('S'), findsOneWidget);

        // 6. Drag & move annotation
        const dragOffset = Offset(0.08, 0.04);
        studio.updateChalkAnnotationOffset(boardAnnId, dragOffset);
        expect(
          studio.currentChalkAnnotations.first.normalizedOffset,
          equals(dragOffset),
        );

        studio.updateChalkAnnotationOffset(pdfAnnId, const Offset(0.02, 0.01));
        expect(
          studio.getPdfChalkAnnotations(1).first.normalizedOffset,
          equals(const Offset(0.02, 0.01)),
        );

        // 7. Lesson serialization & restoration
        final exportedJson = studio.exportLessonJson();
        expect(exportedJson.containsKey('smartChalkAnnotations'), isTrue);
        expect(exportedJson.containsKey('pdfChalkAnnotations'), isTrue);

        final restoredStudio = StudioState();
        restoredStudio.restoreFromJson(exportedJson);

        expect(restoredStudio.currentChalkAnnotations.length, equals(1));
        expect(
          restoredStudio.currentChalkAnnotations.first.normalizedOffset,
          equals(dragOffset),
        );
        expect(restoredStudio.getPdfChalkAnnotations(1).length, equals(1));
        expect(
          restoredStudio.getPdfChalkAnnotations(1).first.rawText,
          equals('The teacher explains the grammar.'),
        );

        // 8. Close tool dock
        final closeBtn = find.byKey(const Key('close_palette_button'));
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('close_palette_button')), findsNothing);
        expect(find.text('Trợ giảng Tiếng Anh'), findsNothing);
        expect(studio.activeSubjectTool, isNull);
        expect(studio.activePlugin, isNull);
        // Board annotations still intact
        expect(studio.currentChalkAnnotations.length, equals(1));
      },
    );
  });
}
