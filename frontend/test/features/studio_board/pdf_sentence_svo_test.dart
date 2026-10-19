import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/smart_chalk_overlay.dart';

void main() {
  group('Phase 04: PDF Sentence Touch Detection & S-V-O Overlay Tests', () {
    test(
      'StudioState manages pdfChalkAnnotations per page and serialization',
      () {
        final studio = StudioState();

        final success = studio.analyzePdfSentenceAt(
          1,
          const Offset(0.2, 0.4),
          sampleText: 'The teacher explains the grammar.',
        );

        expect(success, isTrue);
        final page1List = studio.getPdfChalkAnnotations(1);
        expect(page1List.length, equals(1));
        expect(page1List.first.source, equals('pdf'));
        expect(page1List.first.pageIndex, equals(1));
        expect(
          page1List.first.rawText,
          equals('The teacher explains the grammar.'),
        );

        // Check roles
        final roles = page1List.first.tokens
            .map((t) => t.role)
            .whereType<String>()
            .toList();
        expect(roles, contains('subject'));
        expect(roles, contains('verb'));
        expect(roles, contains('object'));

        // Page 2 must be empty
        expect(studio.getPdfChalkAnnotations(2).isEmpty, isTrue);

        // Export lesson JSON
        final exported = studio.exportLessonJson();
        expect(exported.containsKey('pdfChalkAnnotations'), isTrue);

        // Restore in new studio instance
        final studio2 = StudioState();
        studio2.restoreFromJson(exported);
        final restoredList = studio2.getPdfChalkAnnotations(1);
        expect(restoredList.length, equals(1));
        expect(
          restoredList.first.rawText,
          equals('The teacher explains the grammar.'),
        );

        // Remove
        studio.removePdfChalkAnnotation(1, page1List.first.id);
        expect(studio.getPdfChalkAnnotations(1).isEmpty, isTrue);
      },
    );

    testWidgets(
      'SmartChalkOverlay renders PDF page annotations and respects eye toggle',
      (tester) async {
        final studio = StudioState();
        studio.analyzePdfSentenceAt(
          1,
          const Offset(0.1, 0.3),
          sampleText: 'Students learn English.',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 1000,
                child: Stack(
                  children: [
                    SmartChalkOverlay(
                      studio: studio,
                      targetAnnotations: studio.getPdfChalkAnnotations(1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // S, V, O labels rendered for PDF annotation
        expect(find.text('S'), findsOneWidget);
        expect(find.text('V'), findsOneWidget);
        expect(find.text('O'), findsOneWidget);

        // Toggle eye off
        studio.toggleChalkAnnotationsVisibility();
        await tester.pumpAndSettle();

        expect(find.text('S'), findsNothing);
        expect(find.text('V'), findsNothing);
        expect(find.text('O'), findsNothing);
      },
    );
  });
}

