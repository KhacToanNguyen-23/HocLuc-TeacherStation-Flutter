import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/dgnl_service.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/presentation/pdf_dgnl_passage_overlay.dart';
import 'package:teaching_companion/features/studio_board/presentation/subject_tool_palette.dart';

void main() {
  group('In-Document Passage Highlight & Scan Button Tests', () {
    test('1. DgnlService produces highlights for Question 36-40', () async {
      const passage =
          'At home, I used to suffer enough from passive smoking, because two of my brothers were heavy smokers. '
          'They would light up their cigarettes in any room, and soon the air would be thick with smoke. '
          'I was often having headaches and coughing, and I had to put up with the smell.';

      final analysis = await DgnlService.analyze(passage);

      expect(analysis.highlights.isNotEmpty, isTrue);
      expect(analysis.totalWords, greaterThan(30));

      final categories = analysis.highlights.map((h) => h['category']).toSet();
      expect(
        categories.contains('grammar') || categories.contains('collocation'),
        isTrue,
      );

      // Verify that 'inconvenient' is classified as CEFR B2 (EVP Cambridge standard)
      final incAnalysis = await DgnlService.analyze(
        'It would certainly be a bit inconvenient for them.',
      );
      final incSpan = incAnalysis.highlights.firstWhere(
        (h) => h['text']?.toString().toLowerCase() == 'inconvenient',
      );
      expect(incSpan['level'], 'B2');
    });

    testWidgets(
      '2. SubjectToolPalette displays quick scan button and triggers snipping',
      (tester) async {
        final studio = StudioState();

        // Mock an active English plugin
        final manifest = PluginManifest.fromJson({
          'id': 'com.hocluc.plugin.english',
          'name': 'Trợ giảng Tiếng Anh',
          'version': '1.0.0',
          'main': 'ui/index.html',
          'contributes': {
            'tools': [
              {
                'id': 'snip_passage',
                'label': 'Quét đoạn văn',
                'icon': 'crop_free',
                'action': 'snip_region',
                'target': 'dgnl',
                'key': 'quick_snip_dgnl_button',
              },
            ],
          },
        });
        final plugin = InstalledPlugin(
          manifest: manifest,
        );
        studio.openPlugin(plugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find quick snip button
        final snipBtn = find.byKey(const Key('quick_snip_dgnl_button'));
        expect(snipBtn, findsOneWidget);
        expect(find.text('Quét đoạn văn'), findsOneWidget);

        // Tap snip button
        await tester.tap(snipBtn);
        await tester.pumpAndSettle();

        // Studio should now be in snipping mode
        expect(studio.isSnippingActive, isTrue);
        expect(studio.snipTarget, 'dgnl');
      },
    );

    testWidgets(
      '3. PdfDgnlPassageOverlay renders highlight spans and Lecturer Card',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1024);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final studio = StudioState();

        final spans = [
          PdfDgnlHighlightSpan(
            text: 'used to suffer',
            category: 'grammar',
            level: 'B2',
            type: 'Cấu trúc Thói quen quá khứ (Used to + V)',
            note:
                'Diễn tả thói quen hoặc trạng thái từng xảy ra trong quá khứ nhưng không còn nữa.',
            normalizedRects: const [Rect.fromLTWH(0.1, 0.2, 0.2, 0.04)],
          ),
          PdfDgnlHighlightSpan(
            text: 'passive smoking',
            category: 'collocation',
            level: 'B2',
            type: 'Collocation Học thuật',
            note: 'Hút thuốc lá thụ động (hít phải khói thuốc của người khác).',
            normalizedRects: const [Rect.fromLTWH(0.35, 0.2, 0.22, 0.04)],
          ),
        ];

        final passage = PdfDgnlPassage(
          id: 'test-passage-1',
          pageNumber: 4,
          rawText: 'At home, I used to suffer enough from passive smoking...',
          normalizedBounds: const Rect.fromLTWH(0.08, 0.18, 0.84, 0.45),
          spans: spans,
          metrics: {
            'total_words': 65,
            'content_words': 38,
            'lexical_density': 58.5,
            'evaluation': 'Đoạn văn đạt chuẩn phân hóa đề thi ĐGNL.',
          },
          clozeQuestions: const [],
        );

        studio.addPdfDgnlPassage(passage);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  PdfDgnlPassageOverlay(
                    studio: studio,
                    pageNumber: 4,
                    pageRect: const Rect.fromLTWH(0, 0, 800, 1000),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check legend bar chips
        expect(find.textContaining('Bóc tách Đa tầng'), findsOneWidget);
        expect(find.textContaining('Tất cả (2)'), findsOneWidget);
        expect(find.textContaining('Ngữ pháp (1)'), findsOneWidget);
        expect(find.textContaining('Collocation (1)'), findsOneWidget);

        // Check Lecturer Card initial state (1 / 2)
        expect(
          find.textContaining('Cấu trúc Thói quen quá khứ'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Diễn tả thói quen hoặc trạng thái'),
          findsOneWidget,
        );
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('Tiếp theo'), findsOneWidget);

        // Tap Next button in Lecturer Card -> moves to 2 / 2
        await tester.tap(find.text('Tiếp theo'));
        await tester.pumpAndSettle();

        // Card now switches to the next span (Collocation)
        expect(find.textContaining('Collocation Học thuật'), findsOneWidget);
        expect(find.textContaining('Hút thuốc lá thụ động'), findsOneWidget);
        expect(find.text('2 / 2'), findsOneWidget);
      },
    );

    testWidgets(
      '3b. PdfDgnlPassageOverlay toolbar stays strictly within narrow page bounds without overflowing',
      (tester) async {
        tester.view.physicalSize = const Size(600, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final studio = StudioState();
        final passage = PdfDgnlPassage(
          id: 'test-narrow-p',
          pageNumber: 1,
          rawText: 'Some passage text for testing',
          normalizedBounds: const Rect.fromLTWH(0.2, 0.2, 0.6, 0.3),
          spans: const [
            PdfDgnlHighlightSpan(
              text: 'test',
              category: 'grammar',
              level: 'B2',
              type: 'Test Grammar',
              note: 'Test note',
              normalizedRects: [Rect.fromLTWH(0.2, 0.2, 0.1, 0.05)],
            ),
          ],
          metrics: const {},
          clozeQuestions: const [],
        );
        studio.addPdfDgnlPassage(passage);

        const narrowWidth = 480.0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  PdfDgnlPassageOverlay(
                    studio: studio,
                    pageNumber: 1,
                    pageRect: const Rect.fromLTWH(0, 0, narrowWidth, 700),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ensure no Flutter overflow exceptions occurred
        expect(tester.takeException(), isNull);

        // Verify the toolbar is clamped and constrained within narrowWidth
        final constrainedBoxes = tester.widgetList<ConstrainedBox>(
          find.byType(ConstrainedBox),
        );
        final toolbarBox = constrainedBoxes.firstWhere(
          (b) =>
              b.constraints.maxWidth <= narrowWidth &&
              b.constraints.maxWidth > 0,
        );
        expect(toolbarBox.constraints.maxWidth, lessThanOrEqualTo(narrowWidth));
      },
    );

    test('4. Test Syncfusion PDF Highlight Annotation export', () {
      final doc = sf.PdfDocument();
      final page = doc.pages.add();
      final pageSize = page.size;

      final annotation = sf.PdfTextMarkupAnnotation(
        Rect.fromLTWH(
          0.1 * pageSize.width,
          0.2 * pageSize.height,
          0.3 * pageSize.width,
          24,
        ),
        'used to suffer',
        sf.PdfColor(137, 180, 250), // Cyan/blue
        author: 'Trợ giảng Tiếng Anh',
        subject: 'Ngữ pháp',
        textMarkupAnnotationType: sf.PdfTextMarkupAnnotationType.highlight,
      );
      page.annotations.add(annotation);

      final bytes = doc.saveSync();
      doc.dispose();

      expect(bytes.isNotEmpty, isTrue);

      final loadedDoc = sf.PdfDocument(inputBytes: bytes);
      expect(loadedDoc.pages.count, 1);
      expect(loadedDoc.pages[0].annotations.count, 1);
      final readAnnotation =
          loadedDoc.pages[0].annotations[0] as sf.PdfTextMarkupAnnotation;
      expect(
        readAnnotation.textMarkupAnnotationType,
        sf.PdfTextMarkupAnnotationType.highlight,
      );
      expect(readAnnotation.text, 'used to suffer');
      expect(readAnnotation.author, 'Trợ giảng Tiếng Anh');
      loadedDoc.dispose();
    });

    test('5. Check FilePicker saveFile', () {
      final f = FilePicker.saveFile;
      expect(f, isNotNull);
    });

    test(
      '6. Check applyHighlightDirectlyToPdf and updatePdfBytesInPlace',
      () async {
        final studio = StudioState();
        final doc = sf.PdfDocument();
        doc.pages.add();
        final initialBytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        studio.pdfBytes = initialBytes;
        studio.pdfFilePath = 'test_sample.pdf';
        studio.addPdfDgnlPassage(
          PdfDgnlPassage(
            id: 'test-p1',
            pageNumber: 1,
            rawText: 'used to suffer',
            normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
            spans: const [
              PdfDgnlHighlightSpan(
                text: 'used to suffer',
                category: 'grammar',
                level: 'B2',
                type: 'Cấu trúc Used to',
                note: 'Thói quen quá khứ',
                normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.3, 0.05)],
              ),
            ],
            metrics: const {},
            clozeQuestions: const [],
          ),
        );

        // Apply highlight directly
        final applied = await PdfAnnotationExporter.applyHighlightDirectlyToPdf(
          _MockBuildContext(),
          studio,
          showFeedback: false,
        );
        expect(applied, isTrue);

        // Verify permanent strokes in pdfAnnotations
        expect(studio.pdfAnnotations[1], isNotNull);
        expect(studio.pdfAnnotations[1]!.isNotEmpty, isTrue);
        expect(
          studio.pdfAnnotations[1]!.first.rect,
          const Rect.fromLTWH(0.1, 0.2, 0.3, 0.05),
        );

        // When closing the extension or dismissing the passage:
        studio.closePlugin();
        studio.removePdfDgnlPassage('test-p1');

        // The highlight strokes on the PDF STILL REMAIN!
        expect(studio.pdfAnnotations[1]!.isNotEmpty, isTrue);
        expect(
          studio.pdfAnnotations[1]!.first.rect,
          const Rect.fromLTWH(0.1, 0.2, 0.3, 0.05),
        );
      },
    );

    test('7. BoardStroke isHollow serialization and deserialization', () {
      final stroke = BoardStroke(
        const Color(0xff89b4fa),
        1.5,
        const [Offset(0.1, 0.2), Offset(0.3, 0.25)],
        rect: const Rect.fromLTWH(0.1, 0.2, 0.2, 0.05),
        isHollow: true,
      );

      final json = stroke.toJson();
      expect(json['isHollow'], isTrue);

      final reconstructed = BoardStroke.fromJson(json);
      expect(reconstructed.isHollow, isTrue);
      expect(reconstructed.rect, const Rect.fromLTWH(0.1, 0.2, 0.2, 0.05));
      expect(reconstructed.width, 1.5);
    });

    test(
      '8. Nested Span Conflict Resolution: grammar & nested vocab get isHollow=true in direct highlight',
      () async {
        final studio = StudioState();
        final doc = sf.PdfDocument();
        doc.pages.add();
        final initialBytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        studio.pdfBytes = initialBytes;
        studio.pdfFilePath = 'test_sample.pdf';

        // Passage with nested structures:
        // Grammar: "used to suffer"
        // Collocation: "passive smoking"
        // Vocab: "smoking" (nested inside collocation "passive smoking")
        final grammarSpan = const PdfDgnlHighlightSpan(
          text: 'used to suffer',
          category: 'grammar',
          level: 'B2',
          type: 'Cấu trúc Used to',
          note: 'Thói quen quá khứ',
          normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.2, 0.04)],
        );

        final collocSpan = const PdfDgnlHighlightSpan(
          text: 'passive smoking',
          category: 'collocation',
          level: 'B2',
          type: 'Collocation Học thuật',
          note: 'Hút thuốc lá thụ động',
          normalizedRects: [Rect.fromLTWH(0.35, 0.2, 0.22, 0.04)],
        );

        final nestedVocabSpan = const PdfDgnlHighlightSpan(
          text: 'smoking',
          category: 'vocabulary',
          level: 'B2',
          type: 'Từ vựng B2',
          note: 'Hành động hút thuốc',
          normalizedRects: [Rect.fromLTWH(0.45, 0.2, 0.12, 0.04)],
        );

        studio.addPdfDgnlPassage(
          PdfDgnlPassage(
            id: 'test-nested-p1',
            pageNumber: 1,
            rawText: 'used to suffer from passive smoking',
            normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
            spans: [grammarSpan, collocSpan, nestedVocabSpan],
            metrics: const {},
            clozeQuestions: const [],
          ),
        );

        final applied = await PdfAnnotationExporter.applyHighlightDirectlyToPdf(
          _MockBuildContext(),
          studio,
          showFeedback: false,
        );
        expect(applied, isTrue);

        final strokes = studio.pdfAnnotations[1]!;
        expect(strokes.length, 3);

        // Grammar stroke: MUST be hollow outline to avoid darkening background
        final grammarStroke = strokes.firstWhere(
          (s) => s.rect == grammarSpan.normalizedRects.first,
        );
        expect(grammarStroke.isHollow, isTrue);
        expect(grammarStroke.width, 1.5);

        // Collocation stroke: MUST be filled pastel capsule (isHollow == false)
        final collocStroke = strokes.firstWhere(
          (s) => s.rect == collocSpan.normalizedRects.first,
        );
        expect(collocStroke.isHollow, isFalse);
        expect(collocStroke.width, 20.0);

        // Nested Vocab stroke: MUST be hollow outline (isHollow == true) to avoid double-layer background mud
        final vocabStroke = strokes.firstWhere(
          (s) => s.rect == nestedVocabSpan.normalizedRects.first,
        );
        expect(vocabStroke.isHollow, isTrue);
        expect(vocabStroke.width, 1.2);
      },
    );

    test(
      '9. Visual Channel Separation in exportHighlightedPdfBytes creates valid PDF with discrete channels',
      () async {
        final studio = StudioState();
        final doc = sf.PdfDocument();
        doc.pages.add();
        final initialBytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        studio.pdfBytes = initialBytes;

        final passage = PdfDgnlPassage(
          id: 'test-p9',
          pageNumber: 1,
          rawText: 'used to suffer from passive smoking',
          normalizedBounds: const Rect.fromLTWH(0, 0, 1, 1),
          spans: const [
            PdfDgnlHighlightSpan(
              text: 'used to suffer',
              category: 'grammar',
              level: 'B2',
              type: 'Used to',
              note: 'Thói quen',
              normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.2, 0.04)],
            ),
            PdfDgnlHighlightSpan(
              text: 'passive smoking',
              category: 'collocation',
              level: 'B2',
              type: 'Collocation',
              note: 'Hút thuốc thụ động',
              normalizedRects: [Rect.fromLTWH(0.35, 0.2, 0.22, 0.04)],
            ),
            PdfDgnlHighlightSpan(
              text: 'smoking',
              category: 'vocabulary',
              level: 'B2',
              type: 'Vocab',
              note: 'Hút thuốc',
              normalizedRects: [Rect.fromLTWH(0.45, 0.2, 0.12, 0.04)],
            ),
          ],
          metrics: const {},
          clozeQuestions: const [],
        );

        studio.addPdfDgnlPassage(passage);

        final exportedBytes =
            await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
        expect(exportedBytes, isNotNull);
        expect(exportedBytes!.length, greaterThan(initialBytes.length));

        // Load exported PDF with Syncfusion to inspect annotations
        final loadedDoc = sf.PdfDocument(inputBytes: exportedBytes);
        expect(loadedDoc.pages.count, 1);
        final page = loadedDoc.pages[0];

        // Collocation produces standard TextMarkup highlight annotation
        // While grammar and nested vocab are rendered via graphics pen paths directly in the content stream
        expect(page.annotations.count, 1);
        final markup = page.annotations[0] as sf.PdfTextMarkupAnnotation;
        expect(markup.text, 'passive smoking');

        loadedDoc.dispose();
      },
    );
  });
}

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

