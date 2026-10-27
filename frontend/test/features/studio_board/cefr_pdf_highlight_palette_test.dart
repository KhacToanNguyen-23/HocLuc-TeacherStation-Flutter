import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('DgnlHighlightPalette Palette Unit Tests', () {
    test('verifies exact color constants for all 8 categories and unknown', () {
      expect(DgnlHighlightPalette.grammar, const Color(0xFF89B4FA));
      expect(DgnlHighlightPalette.collocation, const Color(0xFF86EFAC));
      expect(DgnlHighlightPalette.a1, const Color(0xFF22C55E));
      expect(DgnlHighlightPalette.a2, const Color(0xFF14B8A6));
      expect(DgnlHighlightPalette.b1, const Color(0xFF3B82F6));
      expect(DgnlHighlightPalette.b2, const Color(0xFFF59E0B));
      expect(DgnlHighlightPalette.c1, const Color(0xFFF97316));
      expect(DgnlHighlightPalette.c2, const Color(0xFFA855F7));
      expect(DgnlHighlightPalette.unknown, const Color(0xFF94A3B8));
    });

    test(
      'resolveColor handles all categories, levels, and case variations',
      () {
        // Grammar category
        expect(
          DgnlHighlightPalette.resolveColor(category: 'grammar'),
          const Color(0xFF89B4FA),
        );
        expect(
          DgnlHighlightPalette.resolveColor(category: 'GRAMMAR'),
          const Color(0xFF89B4FA),
        );

        // Collocation category
        expect(
          DgnlHighlightPalette.resolveColor(category: 'collocation'),
          const Color(0xFF86EFAC),
        );
        expect(
          DgnlHighlightPalette.resolveColor(category: 'Collocation'),
          const Color(0xFF86EFAC),
        );

        // CEFR Levels
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'A1',
          ),
          const Color(0xFF22C55E),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'a1',
          ),
          const Color(0xFF22C55E),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'A2',
          ),
          const Color(0xFF14B8A6),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'B1',
          ),
          const Color(0xFF3B82F6),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'B2',
          ),
          const Color(0xFFF59E0B),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'C1',
          ),
          const Color(0xFFF97316),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'C2',
          ),
          const Color(0xFFA855F7),
        );

        // Unknown level / null
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'Unknown',
          ),
          const Color(0xFF94A3B8),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: null,
          ),
          const Color(0xFF94A3B8),
        );
        expect(
          DgnlHighlightPalette.resolveColor(
            category: 'vocabulary',
            level: 'XYZ',
          ),
          const Color(0xFF94A3B8),
        );
      },
    );

    test(
      'toRgb extracts correct 0..255 RGB integers for Syncfusion conversion',
      () {
        final grammarRgb = DgnlHighlightPalette.toRgb(
          DgnlHighlightPalette.grammar,
        );
        expect(grammarRgb.r, 137);
        expect(grammarRgb.g, 180);
        expect(grammarRgb.b, 250);

        final a1Rgb = DgnlHighlightPalette.toRgb(DgnlHighlightPalette.a1);
        expect(a1Rgb.r, 34);
        expect(a1Rgb.g, 197);
        expect(a1Rgb.b, 94);

        final b2Rgb = DgnlHighlightPalette.toRgb(DgnlHighlightPalette.b2);
        expect(b2Rgb.r, 245);
        expect(b2Rgb.g, 158);
        expect(b2Rgb.b, 11);
      },
    );

    test(
      'resolveOverlayColors produces consistent accent and background states',
      () {
        const spanA1 = PdfDgnlHighlightSpan(
          text: 'water',
          category: 'vocabulary',
          level: 'A1',
          type: 'A1',
          note: 'Note',
          normalizedRects: [Rect.fromLTWH(0, 0, 1, 1)],
        );

        final inactiveColors = DgnlHighlightPalette.resolveOverlayColors(
          span: spanA1,
          isCurrentActive: false,
          isNestedVocab: false,
        );
        expect(inactiveColors.accent, const Color(0xFF22C55E));
        expect(inactiveColors.background.a, closeTo(0.18, 0.005));

        final activeColors = DgnlHighlightPalette.resolveOverlayColors(
          span: spanA1,
          isCurrentActive: true,
          isNestedVocab: false,
        );
        expect(activeColors.accent, const Color(0xFF22C55E));
        expect(activeColors.background.a, closeTo(0.33, 0.005));

        const spanGrammar = PdfDgnlHighlightSpan(
          text: 'were placed',
          category: 'grammar',
          level: 'B2',
          type: 'Passive',
          note: 'Note',
          normalizedRects: [Rect.fromLTWH(0, 0, 1, 1)],
        );
        final grammarColors = DgnlHighlightPalette.resolveOverlayColors(
          span: spanGrammar,
          isCurrentActive: false,
          isNestedVocab: false,
        );
        expect(grammarColors.accent, const Color(0xFF89B4FA));
        expect(grammarColors.background, Colors.transparent);
      },
    );
  });

  group('PDF Annotation & Export Full Palette Multi-Color Verification', () {
    late StudioState studio;
    late Uint8List dummyPdfBytes;

    setUp(() {
      studio = StudioState()..loading = false;
      studio.pedagogicalPolicy = PedagogicalHighlightPolicy.allVocabulary;
      final doc = sf.PdfDocument();
      doc.pages.add();
      dummyPdfBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();
      studio.pdfBytes = dummyPdfBytes;
      studio.pdfFilePath = '${Directory.systemTemp.path}${Platform.pathSeparator}test_lecture.pdf';
    });

    test(
      'both applyHighlightDirectlyToPdf and exportHighlightedPdfBytes preserve all 8 categories and unknown',
      () async {
        // Document containing all 8 distinct categories + unknown level
        const spans = [
          PdfDgnlHighlightSpan(
            text: 'were placed',
            category: 'grammar',
            level: 'B2',
            type: 'Passive',
            note: 'Grammar point',
            normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.15, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'bitter taste',
            category: 'collocation',
            level: 'B2',
            type: 'Collocation',
            note: 'Academic collocation',
            normalizedRects: [Rect.fromLTWH(0.3, 0.1, 0.15, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'water',
            category: 'vocabulary',
            level: 'A1',
            type: 'Vocab A1',
            note: 'Basic word',
            normalizedRects: [Rect.fromLTWH(0.5, 0.1, 0.08, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'palate',
            category: 'vocabulary',
            level: 'A2',
            type: 'Vocab A2',
            note: 'Waystage word',
            normalizedRects: [Rect.fromLTWH(0.6, 0.1, 0.08, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'sour',
            category: 'vocabulary',
            level: 'B1',
            type: 'Vocab B1',
            note: 'Threshold word',
            normalizedRects: [Rect.fromLTWH(0.7, 0.1, 0.08, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'compound',
            category: 'vocabulary',
            level: 'B2',
            type: 'Vocab B2',
            note: 'Vantage word',
            normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.1, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'naringin',
            category: 'vocabulary',
            level: 'C1',
            type: 'Vocab C1',
            note: 'Proficient word',
            normalizedRects: [Rect.fromLTWH(0.25, 0.2, 0.1, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'adenosine',
            category: 'vocabulary',
            level: 'C2',
            type: 'Vocab C2',
            note: 'Mastery word',
            normalizedRects: [Rect.fromLTWH(0.4, 0.2, 0.1, 0.03)],
          ),
          PdfDgnlHighlightSpan(
            text: 'monophosphate',
            category: 'vocabulary',
            level: 'Unknown',
            type: 'Vocab Unknown',
            note: 'Unclassified word',
            normalizedRects: [Rect.fromLTWH(0.55, 0.2, 0.15, 0.03)],
          ),
        ];

        final passage = PdfDgnlPassage(
          id: 'passage-all-categories',
          pageNumber: 1,
          rawText:
              'were placed bitter taste water palate sour compound naringin adenosine monophosphate',
          normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
          spans: spans,
          metrics: const {},
          clozeQuestions: const [],
        );

        studio.addPdfDgnlPassage(passage);

        // --- PATH 1: applyHighlightDirectlyToPdf (In-place canvas strokes) ---
        final applyResult =
            await PdfAnnotationExporter.applyHighlightDirectlyToPdf(
              _MockBuildContext(),
              studio,
              showFeedback: false,
            );
        expect(applyResult, isTrue);

        final pageStrokes = studio.pdfAnnotations[1];
        expect(pageStrokes, isNotNull);
        expect(pageStrokes!.length, 9);

        // Verify each stroke in studio.pdfAnnotations matches its designated palette color exactly
        expect(pageStrokes[0].color, const Color(0xFF89B4FA)); // Grammar
        expect(pageStrokes[0].isHollow, isTrue);

        expect(pageStrokes[1].color, const Color(0xFF86EFAC)); // Collocation
        expect(pageStrokes[1].isHollow, isFalse);

        expect(pageStrokes[2].color, const Color(0xFF22C55E)); // A1
        expect(pageStrokes[2].isHollow, isFalse);

        expect(pageStrokes[3].color, const Color(0xFF14B8A6)); // A2
        expect(pageStrokes[3].isHollow, isFalse);

        expect(pageStrokes[4].color, const Color(0xFF3B82F6)); // B1
        expect(pageStrokes[4].isHollow, isFalse);

        expect(pageStrokes[5].color, const Color(0xFFF59E0B)); // B2
        expect(pageStrokes[5].isHollow, isFalse);

        expect(pageStrokes[6].color, const Color(0xFFF97316)); // C1
        expect(pageStrokes[6].isHollow, isFalse);

        expect(pageStrokes[7].color, const Color(0xFFA855F7)); // C2
        expect(pageStrokes[7].isHollow, isFalse);

        expect(pageStrokes[8].color, const Color(0xFF94A3B8)); // Unknown
        expect(pageStrokes[8].isHollow, isFalse);

        // Collect all distinct colors
        final distinctColors = pageStrokes.map((s) => s.color.toARGB32()).toSet();
        expect(
          distinctColors.length,
          9,
          reason: 'All 9 spans must have distinct colors!',
        );

        // Non-destructive verification: studio.pdfBytes is preserved unmodified
        expect(studio.pdfBytes, isNotNull);
        expect(studio.pdfBytes!.length, equals(dummyPdfBytes.length));

        // When exporting, exportHighlightedPdfBytes produces the flattened PDF with 8 annotations
        final exportedDirectBytes =
            await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
        expect(exportedDirectBytes, isNotNull);
        expect(exportedDirectBytes!.length, greaterThan(dummyPdfBytes.length));

        final exportedDirectDoc = sf.PdfDocument(inputBytes: exportedDirectBytes);
        expect(exportedDirectDoc.pages.count, 1);
        expect(exportedDirectDoc.pages[0].annotations.count, 8);
        exportedDirectDoc.dispose();

        // --- PATH 2: exportHighlightedPdfBytes on clean document (Syncfusion PDF Export & Re-import) ---
        final standaloneStudio = StudioState()..loading = false;
        standaloneStudio.pedagogicalPolicy =
            PedagogicalHighlightPolicy.allVocabulary;
        standaloneStudio.pdfBytes = Uint8List.fromList(dummyPdfBytes);
        standaloneStudio.addPdfDgnlPassage(passage);

        final exportedBytes =
            await PdfAnnotationExporter.exportHighlightedPdfBytes(
              standaloneStudio,
            );
        expect(exportedBytes, isNotNull);
        expect(exportedBytes!.length, greaterThan(dummyPdfBytes.length));

        // Reopen the exported PDF with Syncfusion to inspect embedded text markup annotations
        final exportedDoc = sf.PdfDocument(inputBytes: exportedBytes);
        expect(exportedDoc.pages.count, 1);
        final page = exportedDoc.pages[0];

        // 8 text markup annotations (Grammar is drawn as vector outline path)
        expect(page.annotations.count, 8);

        final annotations = page.annotations;
        final collocationAnnotation =
            annotations[0] as sf.PdfTextMarkupAnnotation;
        expect(collocationAnnotation.text, 'bitter taste');
        expect(collocationAnnotation.color.r, 134);
        expect(collocationAnnotation.color.g, 239);
        expect(collocationAnnotation.color.b, 172); // #86EFAC

        final a1Annotation = annotations[1] as sf.PdfTextMarkupAnnotation;
        expect(a1Annotation.text, 'water');
        expect(a1Annotation.color.r, 34);
        expect(a1Annotation.color.g, 197);
        expect(a1Annotation.color.b, 94); // #22C55E

        final a2Annotation = annotations[2] as sf.PdfTextMarkupAnnotation;
        expect(a2Annotation.text, 'palate');
        expect(a2Annotation.color.r, 20);
        expect(a2Annotation.color.g, 184);
        expect(a2Annotation.color.b, 166); // #14B8A6

        final b1Annotation = annotations[3] as sf.PdfTextMarkupAnnotation;
        expect(b1Annotation.text, 'sour');
        expect(b1Annotation.color.r, 59);
        expect(b1Annotation.color.g, 130);
        expect(b1Annotation.color.b, 246); // #3B82F6

        final b2Annotation = annotations[4] as sf.PdfTextMarkupAnnotation;
        expect(b2Annotation.text, 'compound');
        expect(b2Annotation.color.r, 245);
        expect(b2Annotation.color.g, 158);
        expect(b2Annotation.color.b, 11); // #F59E0B

        final c1Annotation = annotations[5] as sf.PdfTextMarkupAnnotation;
        expect(c1Annotation.text, 'naringin');
        expect(c1Annotation.color.r, 249);
        expect(c1Annotation.color.g, 115);
        expect(c1Annotation.color.b, 22); // #F97316

        final c2Annotation = annotations[6] as sf.PdfTextMarkupAnnotation;
        expect(c2Annotation.text, 'adenosine');
        expect(c2Annotation.color.r, 168);
        expect(c2Annotation.color.g, 85);
        expect(c2Annotation.color.b, 247); // #A855F7

        final unknownAnnotation = annotations[7] as sf.PdfTextMarkupAnnotation;
        expect(unknownAnnotation.text, 'monophosphate');
        expect(unknownAnnotation.color.r, 148);
        expect(unknownAnnotation.color.g, 163);
        expect(unknownAnnotation.color.b, 184); // #94A3B8

        exportedDoc.dispose();
      },
    );
  });
}
