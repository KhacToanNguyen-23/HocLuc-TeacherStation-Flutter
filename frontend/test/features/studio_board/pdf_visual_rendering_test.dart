import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';

void main() {
  test('Visual PDF Rendering Verification: Text Readability and Adaptive Opacity', () async {
    // 1. Create a PDF document with standard black text
    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);
    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0)); // Pure black text

    const testText =
        'B. It is possible, however, to get the goodness of grapefruit juice without the bitter taste. '
        'I found that out by participating in a test conducted at the Linguagen Corporation. '
        'Sets of two miniature white paper cups, labeled 304 and 305, were placed before five people. '
        'There was the sour taste of citrus but none of the bitterness of naringin.';

    sf.PdfTextElement(
      text: testText,
      font: font,
      brush: brush,
    ).draw(
      page: page,
      bounds: const Rect.fromLTWH(50, 50, 450, 300),
    );

    final rawBytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();

    // 2. Set up StudioState with sample passage highlights including the 4 key cases
    final studio = StudioState()..loading = false;
    studio.pedagogicalPolicy = PedagogicalHighlightPolicy.allVocabulary;
    studio.pdfBytes = rawBytes;

    const spans = [
      // Case 1: bitterness (B2) with an exact duplicate span
      PdfDgnlHighlightSpan(
        text: 'bitterness',
        category: 'vocabulary',
        level: 'B2',
        type: 'B2',
        note: 'Vantage word',
        normalizedRects: [Rect.fromLTWH(0.5, 0.4, 0.15, 0.03)],
      ),
      PdfDgnlHighlightSpan(
        text: 'bitterness',
        category: 'vocabulary',
        level: 'B2',
        type: 'B2',
        note: 'Accidental duplicate span',
        normalizedRects: [Rect.fromLTWH(0.5, 0.4, 0.15, 0.03)],
      ),

      // Case 2: that out by participating (Grammar) + participating (Vocab inside grammar)
      PdfDgnlHighlightSpan(
        text: 'by participating',
        category: 'grammar',
        level: 'B2',
        type: 'Prep + V-ing',
        note: 'Gerund phrase',
        normalizedRects: [Rect.fromLTWH(0.25, 0.2, 0.22, 0.03)],
      ),
      PdfDgnlHighlightSpan(
        text: 'participating',
        category: 'vocabulary',
        level: 'B2',
        type: 'B2',
        note: 'Core vocabulary',
        normalizedRects: [Rect.fromLTWH(0.28, 0.2, 0.19, 0.03)],
      ),

      // Case 3: were placed (Grammar) + were (A1) + placed (A2)
      PdfDgnlHighlightSpan(
        text: 'were placed',
        category: 'grammar',
        level: 'B2',
        type: 'Passive Voice',
        note: 'Passive structure',
        normalizedRects: [Rect.fromLTWH(0.4, 0.3, 0.18, 0.03)],
      ),
      PdfDgnlHighlightSpan(
        text: 'were',
        category: 'vocabulary',
        level: 'A1',
        type: 'A1',
        note: 'Be auxiliary',
        normalizedRects: [Rect.fromLTWH(0.4, 0.3, 0.07, 0.03)],
      ),
      PdfDgnlHighlightSpan(
        text: 'placed',
        category: 'vocabulary',
        level: 'A2',
        type: 'A2',
        note: 'Main participle',
        normalizedRects: [Rect.fromLTWH(0.48, 0.3, 0.10, 0.03)],
      ),

      // Collocation: paper cups + white (A1 vocab inside collocation)
      PdfDgnlHighlightSpan(
        text: 'paper cups',
        category: 'collocation',
        level: 'A2',
        type: 'Collocation',
        note: 'Noun phrase',
        normalizedRects: [Rect.fromLTWH(0.15, 0.3, 0.18, 0.03)],
      ),
      PdfDgnlHighlightSpan(
        text: 'white',
        category: 'vocabulary',
        level: 'A1',
        type: 'A1',
        note: 'Color adjective',
        normalizedRects: [Rect.fromLTWH(0.1, 0.3, 0.06, 0.03)],
      ),
    ];

    final passage = PdfDgnlPassage(
      id: 'visual-test-passage',
      pageNumber: 1,
      rawText: testText,
      normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
      spans: spans,
      metrics: const {},
      clozeQuestions: const [],
    );
    studio.addPdfDgnlPassage(passage);

    // 3. Export PDF
    final exportedBytes = await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
    expect(exportedBytes, isNotNull);
    expect(exportedBytes!.length, greaterThan(rawBytes.length));

    // 4. Save to build artifact / scratch for verification
    final outputDir = Directory('build/test_artifacts');
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }
    final outputFile = File('build/test_artifacts/highlighted_readability_verification.pdf');
    outputFile.writeAsBytesSync(exportedBytes);
    expect(outputFile.existsSync(), isTrue);
    expect(outputFile.lengthSync(), greaterThan(1000));

    // 5. Reopen exported PDF and verify annotation properties
    final verifiedDoc = sf.PdfDocument(inputBytes: exportedBytes);
    final verifiedPage = verifiedDoc.pages[0];

    // Verify deduplication: 'bitterness' duplicate was removed
    // Annotations count: bitterness (1) + participating (1) + were (1) + placed (1) + paper cups (1) + white (1) = 6
    // Grammar spans (by participating, were placed) are vector outlines, not text markup annotations
    expect(verifiedPage.annotations.count, 6);

    for (int i = 0; i < verifiedPage.annotations.count; i++) {
      final markup = verifiedPage.annotations[i] as sf.PdfTextMarkupAnnotation;
      // All annotations have subtle adaptive opacity: 0.18 <= opacity <= 0.25
      expect(markup.opacity, greaterThanOrEqualTo(0.18));
      expect(markup.opacity, lessThanOrEqualTo(0.25));
    }

    verifiedDoc.dispose();
  });
}
