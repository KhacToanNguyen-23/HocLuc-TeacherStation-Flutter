import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/smart_chalk_annotation.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/smart_chalk_overlay.dart';

void main() {
  group('Phase 02: Smart Chalk S-V-O Annotation Model & Renderer Tests', () {
    test('SmartChalkAnnotation serialization & deserialization round-trip', () {
      final annotation = SmartChalkAnnotation(
        id: 'svo-12345',
        source: 'chalkboard',
        pageIndex: 0,
        rawText: 'I go to school.',
        normalizedBounds: const Rect.fromLTWH(0.2, 0.3, 0.4, 0.1),
        tokens: [
          ChalkWordToken(
            word: 'I',
            role: 'subject',
            color: const Color(0xff89b4fa),
            relativeRect: const Rect.fromLTWH(0.0, 0.0, 0.1, 1.0),
          ),
          ChalkWordToken(
            word: 'go',
            role: 'verb',
            color: const Color(0xfff38ba8),
            relativeRect: const Rect.fromLTWH(0.15, 0.0, 0.15, 1.0),
          ),
          ChalkWordToken(
            word: 'to',
            role: null,
            color: Colors.transparent,
            relativeRect: const Rect.fromLTWH(0.35, 0.0, 0.1, 1.0),
          ),
          ChalkWordToken(
            word: 'school',
            role: 'object',
            color: const Color(0xfffab387),
            relativeRect: const Rect.fromLTWH(0.5, 0.0, 0.3, 1.0),
          ),
        ],
        isVisible: true,
        normalizedOffset: const Offset(0.02, 0.01),
      );

      final json = annotation.toJson();
      final restored = SmartChalkAnnotation.fromJson(json);

      expect(restored.id, equals('svo-12345'));
      expect(restored.source, equals('chalkboard'));
      expect(restored.pageIndex, equals(0));
      expect(restored.rawText, equals('I go to school.'));
      expect(restored.normalizedBounds.left, closeTo(0.2, 0.001));
      expect(restored.tokens.length, equals(4));
      expect(restored.tokens[0].word, equals('I'));
      expect(restored.tokens[0].role, equals('subject'));
      expect(
        restored.tokens[0].color.toARGB32(),
        equals(const Color(0xff89b4fa).toARGB32()),
      );
      expect(restored.tokens[1].role, equals('verb'));
      expect(
        restored.tokens[1].color.toARGB32(),
        equals(const Color(0xfff38ba8).toARGB32()),
      );
      expect(restored.tokens[3].role, equals('object'));
      expect(
        restored.tokens[3].color.toARGB32(),
        equals(const Color(0xfffab387).toARGB32()),
      );
      expect(restored.isVisible, isTrue);
      expect(restored.normalizedOffset.dx, closeTo(0.02, 0.001));
    });

    test(
      'ChalkWordToken assigns distinct colors for Det, Prep, and Conj roles',
      () {
        final tDet = ChalkWordToken(
          word: 'a',
          role: 'det',
          relativeRect: Rect.zero,
        );
        final tPrep = ChalkWordToken(
          word: 'to',
          role: 'prep',
          relativeRect: Rect.zero,
        );
        final tConj = ChalkWordToken(
          word: 'and',
          role: 'conj',
          relativeRect: Rect.zero,
        );

        expect(
          tDet.color.toARGB32(),
          equals(const Color(0xff94e2d5).toARGB32()),
        );
        expect(
          tPrep.color.toARGB32(),
          equals(const Color(0xfff9e2af).toARGB32()),
        );
        expect(
          tConj.color.toARGB32(),
          equals(const Color(0xffeba0ac).toARGB32()),
        );
      },
    );

    test(
      'StudioState manages pageChalkAnnotations and lesson export/restore',
      () {
        final studio = StudioState();

        final annotation = SmartChalkAnnotation(
          id: 'svo-1',
          source: 'chalkboard',
          pageIndex: 0,
          rawText: 'She plays the piano.',
          normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.5, 0.1),
          tokens: [
            ChalkWordToken(
              word: 'She',
              role: 'subject',
              color: const Color(0xff89b4fa),
              relativeRect: const Rect.fromLTWH(0.0, 0.0, 0.2, 1.0),
            ),
            ChalkWordToken(
              word: 'plays',
              role: 'verb',
              color: const Color(0xfff38ba8),
              relativeRect: const Rect.fromLTWH(0.25, 0.0, 0.25, 1.0),
            ),
            ChalkWordToken(
              word: 'piano',
              role: 'object',
              color: const Color(0xfffab387),
              relativeRect: const Rect.fromLTWH(0.6, 0.0, 0.3, 1.0),
            ),
          ],
        );

        studio.addChalkAnnotation(annotation);
        expect(studio.currentChalkAnnotations.length, equals(1));
        expect(studio.currentChalkAnnotations.first.id, equals('svo-1'));

        // Update offset
        studio.updateChalkAnnotationOffset('svo-1', const Offset(0.05, 0.05));
        expect(
          studio.currentChalkAnnotations.first.normalizedOffset.dx,
          closeTo(0.05, 0.001),
        );

        // Export lesson JSON
        final exported = studio.exportLessonJson();
        expect(exported.containsKey('smartChalkAnnotations'), isTrue);

        // Restore in a new StudioState instance
        final studio2 = StudioState();
        studio2.restoreFromJson(exported);
        expect(studio2.currentChalkAnnotations.length, equals(1));
        expect(
          studio2.currentChalkAnnotations.first.rawText,
          equals('She plays the piano.'),
        );
        expect(studio2.currentChalkAnnotations.first.tokens.length, equals(3));

        // Remove annotation
        studio.removeChalkAnnotation('svo-1');
        expect(studio.currentChalkAnnotations.isEmpty, isTrue);
      },
    );

    testWidgets(
      'SmartChalkOverlay renders S-V-O labels and respects visibility toggle',
      (tester) async {
        final studio = StudioState();
        final annotation = SmartChalkAnnotation(
          id: 'svo-test',
          source: 'chalkboard',
          pageIndex: 0,
          rawText: 'I go to school.',
          normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.6, 0.1),
          tokens: [
            ChalkWordToken(
              word: 'I',
              role: 'subject',
              color: const Color(0xff89b4fa),
              relativeRect: const Rect.fromLTWH(0.0, 0.0, 0.15, 1.0),
            ),
            ChalkWordToken(
              word: 'go',
              role: 'verb',
              color: const Color(0xfff38ba8),
              relativeRect: const Rect.fromLTWH(0.2, 0.0, 0.2, 1.0),
            ),
            ChalkWordToken(
              word: 'school',
              role: 'object',
              color: const Color(0xfffab387),
              relativeRect: const Rect.fromLTWH(0.5, 0.0, 0.4, 1.0),
            ),
          ],
        );
        studio.addChalkAnnotation(annotation);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: Stack(children: [SmartChalkOverlay(studio: studio)]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check role labels are rendered
        expect(find.text('S'), findsOneWidget);
        expect(find.text('V'), findsOneWidget);
        expect(find.text('O'), findsOneWidget);

        // Toggle visibility off via studio
        studio.toggleChalkAnnotationsVisibility();
        await tester.pumpAndSettle();

        // Labels should not be visible when chalkAnnotationsVisible is false
        expect(find.text('S'), findsNothing);
        expect(find.text('V'), findsNothing);
        expect(find.text('O'), findsNothing);
      },
    );

    test(
      'StudioState.erase() removes SmartChalkAnnotation directly hit by eraser',
      () {
        final studio = StudioState();
        final annotation = SmartChalkAnnotation(
          id: 'svo-target',
          source: 'chalkboard',
          pageIndex: 0,
          rawText: 'We study English.',
          normalizedBounds: const Rect.fromLTWH(0.2, 0.4, 0.3, 0.08),
          tokens: [
            ChalkWordToken(
              word: 'We',
              role: 'subject',
              relativeRect: const Rect.fromLTWH(0, 0, 0.3, 1),
            ),
          ],
        );
        studio.addChalkAnnotation(annotation);
        expect(studio.currentChalkAnnotations.length, equals(1));

        // Erase at point far away (0.0, 0.0) -> should NOT erase
        studio.erase(const Offset(0.05, 0.05));
        expect(studio.currentChalkAnnotations.length, equals(1));

        // Erase directly on the chalk underline (0.25, 0.46)
        studio.erase(const Offset(0.25, 0.46));
        expect(studio.currentChalkAnnotations.isEmpty, isTrue);
      },
    );

    test(
      'StudioState.erase() auto-cleans orphan chalkboard annotations when strokes are erased',
      () {
        final studio = StudioState();
        // Add stroke representing handwriting for 'He walks'
        final stroke = BoardStroke(Colors.white, 3.0, [
          const Offset(0.21, 0.31),
          const Offset(0.22, 0.32),
        ]);
        studio.addStroke(stroke);

        final annotation = SmartChalkAnnotation(
          id: 'svo-orphan',
          source: 'chalkboard',
          pageIndex: 0,
          rawText: 'He walks.',
          normalizedBounds: const Rect.fromLTWH(0.20, 0.30, 0.20, 0.06),
          tokens: [
            ChalkWordToken(
              word: 'He',
              role: 'subject',
              relativeRect: const Rect.fromLTWH(0, 0, 0.4, 1),
            ),
          ],
        );
        studio.addChalkAnnotation(annotation);
        expect(studio.currentChalkAnnotations.length, equals(1));
        expect(studio.strokes.length, equals(1));

        // Erase the stroke
        studio.erase(const Offset(0.21, 0.31));
        expect(studio.strokes.isEmpty, isTrue);
        // The orphan annotation must be cleaned automatically because the handwriting is gone
        expect(studio.currentChalkAnnotations.isEmpty, isTrue);
      },
    );

    test(
      'StudioState.clearPage() removes both strokes and chalk annotations',
      () {
        final studio = StudioState();
        final stroke = BoardStroke(Colors.white, 3.0, [const Offset(0.1, 0.1)]);
        studio.addStroke(stroke);

        final annotation = SmartChalkAnnotation(
          id: 'svo-clear',
          source: 'chalkboard',
          pageIndex: 0,
          rawText: 'Clear test',
          normalizedBounds: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05),
          tokens: [],
        );
        studio.addChalkAnnotation(annotation);

        expect(studio.strokes.length, equals(1));
        expect(studio.currentChalkAnnotations.length, equals(1));

        studio.clearPage();

        expect(studio.strokes.isEmpty, isTrue);
        expect(studio.currentChalkAnnotations.isEmpty, isTrue);
      },
    );
  });
}
