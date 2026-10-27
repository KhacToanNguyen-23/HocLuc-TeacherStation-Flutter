import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';

void main() {
  group('1. Centralized Palette & Adaptive Opacity Tests', () {
    test('verifies exact semantic colors for all 9 categories', () {
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

    test('verifies target adaptive opacity configuration for each annotation type', () {
      // A1–A2: 0.18
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'A1'), 0.18);
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'A2'), 0.18);

      // B1–B2: 0.22
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'B1'), 0.22);
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'B2'), 0.22);

      // C1–C2: 0.25
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'C1'), 0.25);
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'C2'), 0.25);

      // Collocation: 0.20
      expect(DgnlHighlightPalette.resolveOpacity(category: 'collocation'), 0.20);

      // Unknown / Unclassified: 0.12
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: 'Unknown'), 0.12);
      expect(DgnlHighlightPalette.resolveOpacity(category: 'vocabulary', level: null), 0.12);

      // Grammar border and fill
      expect(DgnlHighlightPalette.grammarBorderOpacity, 0.85);
      expect(DgnlHighlightPalette.grammarFillOpacity, 0.06);
    });

    test('resolveRenderingStyle encapsulates geometry-independent styling', () {
      const vocabSpan = PdfDgnlHighlightSpan(
        text: 'treated',
        category: 'vocabulary',
        level: 'B1',
        type: 'B1',
        note: 'Note',
        normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.2, 0.03)],
      );

      final styleStandalone = DgnlHighlightPalette.resolveRenderingStyle(
        span: vocabSpan,
        isNestedInCollocation: false,
      );
      expect(styleStandalone.color, const Color(0xFF3B82F6));
      expect(styleStandalone.fillOpacity, 0.22);
      expect(styleStandalone.isHollow, isFalse);

      final styleNestedInColloc = DgnlHighlightPalette.resolveRenderingStyle(
        span: vocabSpan,
        isNestedInCollocation: true,
      );
      expect(styleNestedInColloc.color, const Color(0xFF3B82F6));
      expect(styleNestedInColloc.fillOpacity, 0.0); // 0% fill to prevent muddy double brush
      expect(styleNestedInColloc.isHollow, isTrue);
      expect(styleNestedInColloc.borderOpacity, 0.85);

      const grammarSpan = PdfDgnlHighlightSpan(
        text: 'were placed',
        category: 'grammar',
        level: 'B2',
        type: 'Passive',
        note: 'Note',
        normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.2, 0.03)],
      );
      final styleGrammar = DgnlHighlightPalette.resolveRenderingStyle(
        span: grammarSpan,
        isNestedInCollocation: false,
      );
      expect(styleGrammar.color, const Color(0xFF89B4FA));
      expect(styleGrammar.isDashed, isTrue);
      expect(styleGrammar.isHollow, isTrue);
      expect(styleGrammar.borderOpacity, 0.85);
    });
  });

  group('2. Deduplication & Overlap Policy Tests', () {
    test('deduplicates exact duplicate annotations before rendering', () {
      final spans = [
        const PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'First occurrence duplicate 1',
          normalizedRects: [Rect.fromLTWH(0.5, 0.6, 0.15, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'First occurrence duplicate 2',
          normalizedRects: [Rect.fromLTWH(0.5, 0.6, 0.15, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'Second occurrence at different rect',
          normalizedRects: [Rect.fromLTWH(0.5, 0.8, 0.15, 0.03)],
        ),
      ];

      final deduped = PdfAnnotationExporter.deduplicateSpansForRendering(spans);
      expect(deduped.length, 2);
      expect(deduped[0].normalizedRects[0].top, 0.6);
      expect(deduped[1].normalizedRects[0].top, 0.8);
    });

    test('resolves bitter and bitterness overlap on the same text range by keeping the more specific word', () {
      final spans = [
        const PdfDgnlHighlightSpan(
          text: 'bitter',
          category: 'vocabulary',
          level: 'B1',
          type: 'B1',
          note: 'Shorter stem match',
          normalizedRects: [Rect.fromLTWH(0.5, 0.6, 0.09, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'Full word match',
          normalizedRects: [Rect.fromLTWH(0.5, 0.6, 0.15, 0.03)],
        ),
      ];

      final deduped = PdfAnnotationExporter.deduplicateSpansForRendering(spans);
      expect(deduped.length, 1);
      expect(deduped.single.text, 'bitterness');
      expect(deduped.single.level, 'B2');
    });

    test('preserves both grammar outline and nested vocabulary within the same range', () {
      final spans = [
        const PdfDgnlHighlightSpan(
          text: 'were placed',
          category: 'grammar',
          level: 'B2',
          type: 'Passive',
          note: 'Passive voice',
          normalizedRects: [Rect.fromLTWH(0.2, 0.3, 0.25, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'were',
          category: 'vocabulary',
          level: 'A1',
          type: 'A1',
          note: 'Be verb',
          normalizedRects: [Rect.fromLTWH(0.2, 0.3, 0.10, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'placed',
          category: 'vocabulary',
          level: 'A2',
          type: 'A2',
          note: 'Action verb',
          normalizedRects: [Rect.fromLTWH(0.31, 0.3, 0.14, 0.03)],
        ),
      ];

      final deduped = PdfAnnotationExporter.deduplicateSpansForRendering(spans);
      expect(deduped.length, 3);
      expect(deduped.where((s) => s.category == 'grammar').length, 1);
      expect(deduped.where((s) => s.category == 'vocabulary').length, 2);
    });

    test('preserves both collocation fill and nested vocabulary outline without double fill', () {
      final spans = [
        const PdfDgnlHighlightSpan(
          text: 'bitter taste',
          category: 'collocation',
          level: 'B2',
          type: 'Collocation',
          note: 'Academic collocation',
          normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.22, 0.03)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'bitter',
          category: 'vocabulary',
          level: 'B1',
          type: 'B1',
          note: 'Adj',
          normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.10, 0.03)],
        ),
      ];

      final deduped = PdfAnnotationExporter.deduplicateSpansForRendering(spans);
      expect(deduped.length, 2);

      final collocStyle = DgnlHighlightPalette.resolveRenderingStyle(
        span: deduped[0],
        isNestedInCollocation: false,
      );
      expect(collocStyle.fillOpacity, 0.20);
      expect(collocStyle.isHollow, isFalse);

      final vocabNestedStyle = DgnlHighlightPalette.resolveRenderingStyle(
        span: deduped[1],
        isNestedInCollocation: true,
      );
      expect(vocabNestedStyle.fillOpacity, 0.0);
      expect(vocabNestedStyle.isHollow, isTrue);
      expect(vocabNestedStyle.borderOpacity, 0.85);
    });
  });

  group('3. BoardStroke Persistence & Serialization Tests', () {
    test('BoardStroke preserves category, level, opacity, and isHollow across json serialization', () {
      final stroke = BoardStroke(
        const Color(0xFFF59E0B),
        20.0,
        [const Offset(0.1, 0.2), const Offset(0.3, 0.4)],
        rect: const Rect.fromLTWH(0.1, 0.2, 0.2, 0.03),
        isHollow: false,
        category: 'vocabulary',
        level: 'B2',
        opacity: 0.22,
      );

      final json = stroke.toJson();
      expect(json['category'], 'vocabulary');
      expect(json['level'], 'B2');
      expect(json['opacity'], 0.22);
      expect(json['isHollow'], isNull); // isHollow only in json if true

      final restored = BoardStroke.fromJson(json);
      expect(restored.color, const Color(0xFFF59E0B));
      expect(restored.category, 'vocabulary');
      expect(restored.level, 'B2');
      expect(restored.opacity, 0.22);
      expect(restored.isHollow, isFalse);
    });

    test('BoardStroke preserves hollow grammar border across json serialization', () {
      final grammarStroke = BoardStroke(
        const Color(0xFF89B4FA),
        1.5,
        [const Offset(0.2, 0.3), const Offset(0.4, 0.35)],
        rect: const Rect.fromLTWH(0.2, 0.3, 0.2, 0.05),
        isHollow: true,
        category: 'grammar',
        level: 'B2',
        opacity: 0.85,
      );

      final json = grammarStroke.toJson();
      expect(json['isHollow'], isTrue);
      expect(json['opacity'], 0.85);

      final restored = BoardStroke.fromJson(json);
      expect(restored.isHollow, isTrue);
      expect(restored.opacity, 0.85);
    });
  });

  group('4. Exported PDF Readability & Annotation Transparency Verification', () {
    test('exported PDF annotations have explicit translucent opacity and do not exceed 0.25', () async {
      final studio = StudioState()..loading = false;
      final doc = sf.PdfDocument();
      doc.pages.add();
      final baseBytes = Uint8List.fromList(doc.saveSync());
      doc.dispose();
      studio.pdfBytes = baseBytes;

      const spans = [
        PdfDgnlHighlightSpan(
          text: 'were placed',
          category: 'grammar',
          level: 'B2',
          type: 'Passive',
          note: 'Grammar',
          normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.2, 0.03)],
        ),
        PdfDgnlHighlightSpan(
          text: 'bitter taste',
          category: 'collocation',
          level: 'B2',
          type: 'Collocation',
          note: 'Collocation',
          normalizedRects: [Rect.fromLTWH(0.35, 0.1, 0.2, 0.03)],
        ),
        PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'Vocab',
          normalizedRects: [Rect.fromLTWH(0.6, 0.1, 0.15, 0.03)],
        ),
        // Duplicate bitterness at same location
        PdfDgnlHighlightSpan(
          text: 'bitterness',
          category: 'vocabulary',
          level: 'B2',
          type: 'B2',
          note: 'Vocab duplicate',
          normalizedRects: [Rect.fromLTWH(0.6, 0.1, 0.15, 0.03)],
        ),
      ];

      final passage = PdfDgnlPassage(
        id: 'test-passage',
        pageNumber: 1,
        rawText: 'were placed bitter taste bitterness',
        normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
        spans: spans,
        metrics: const {},
        clozeQuestions: const [],
      );
      studio.addPdfDgnlPassage(passage);

      final exportedBytes = await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
      expect(exportedBytes, isNotNull);

      final exportedDoc = sf.PdfDocument(inputBytes: exportedBytes!);
      final page = exportedDoc.pages[0];

      // Exact duplicate bitterness was removed -> exactly 2 text markup annotations (Collocation + 1 Bitterness)
      // Grammar is rendered as vector outline pen path in graphics
      expect(page.annotations.count, 2);

      for (int i = 0; i < page.annotations.count; i++) {
        final markup = page.annotations[i] as sf.PdfTextMarkupAnnotation;
        // Verify annotation opacity is explicit and <= 0.25 (not the dark 1.0 default)
        expect(markup.opacity, lessThanOrEqualTo(0.25));
        expect(markup.opacity, greaterThanOrEqualTo(0.12));
      }

      exportedDoc.dispose();
    });
  });
}
