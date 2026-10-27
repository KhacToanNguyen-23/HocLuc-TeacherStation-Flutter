import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_storage_service.dart';

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory tempDir;
  late PdfAnnotationStorageService storageService;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pdf_annotation_test_');
    storageService = PdfAnnotationStorageService(
      customStorageDirectory: tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Uint8List createSamplePdfBytes([String text = 'Sample Page Text']) {
    final doc = sf.PdfDocument();
    final page = doc.pages.add();
    final font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12);
    final brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));
    page.graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: const Rect.fromLTWH(20, 20, 400, 30),
    );
    final bytes = Uint8List.fromList(doc.saveSync());
    doc.dispose();
    return bytes;
  }

  group('A. Non-Destructive Protection & Source PDF Integrity', () {
    test(
      'applyHighlightDirectlyToPdf does NOT overwrite the original PDF file on disk',
      () async {
        final sampleBytes = createSamplePdfBytes();
        final sampleFile = File(
          '${tempDir.path}${Platform.pathSeparator}original_document.pdf',
        );
        await sampleFile.writeAsBytes(sampleBytes);
        final originalLength = sampleFile.lengthSync();

        final studio = StudioState()..loading = false;
        studio.setPdfFile(sampleFile.path, sampleBytes);

        studio.addPdfDgnlPassage(
          PdfDgnlPassage(
            id: 'p-1',
            pageNumber: 1,
            rawText: 'bitterness of naringin',
            normalizedBounds: const Rect.fromLTWH(0.1, 0.2, 0.5, 0.1),
            spans: const [
              PdfDgnlHighlightSpan(
                text: 'bitterness',
                category: 'vocabulary',
                level: 'B2',
                type: 'Từ vựng B2',
                note: 'Vị đắng',
                normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.2, 0.04)],
              ),
            ],
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

        // Verify source file on disk is UNCHANGED
        final currentLength = sampleFile.lengthSync();
        expect(currentLength, equals(originalLength));
        final currentBytes = await sampleFile.readAsBytes();
        expect(currentBytes, equals(sampleBytes));

        // Verify annotations exist in memory
        expect(studio.pdfAnnotations[1], hasLength(1));
        expect(studio.pdfAnnotations[1]!.first.category, equals('vocabulary'));
        expect(studio.pdfAnnotations[1]!.first.level, equals('B2'));
      },
    );

    test(
      'saveHighlightedPdf rejects saving over the original source path',
      () async {
        final sampleBytes = createSamplePdfBytes();
        final sampleFile = File(
          '${tempDir.path}${Platform.pathSeparator}textbook.pdf',
        );
        await sampleFile.writeAsBytes(sampleBytes);

        final studio = StudioState()..loading = false;
        studio.setPdfFile(sampleFile.path, sampleBytes);

        // Add a stroke
        studio.pdfAnnotations
            .putIfAbsent(1, () => [])
            .add(
              BoardStroke(
                const Color(0xff3b82f6),
                20.0,
                const [Offset(0.1, 0.1), Offset(0.3, 0.14)],
                rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.04),
                category: 'vocabulary',
                level: 'B1',
              ),
            );

        // Exporting to another file works and produces a flattened copy
        final flattenedBytes =
            await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
        expect(flattenedBytes, isNotNull);
        expect(flattenedBytes!.length, isNot(equals(sampleBytes.length)));

        // Original source file on disk remains clean
        expect(await sampleFile.readAsBytes(), equals(sampleBytes));
      },
    );
  });

  group('B. Persistent Annotation Layer & Document Identity', () {
    test('save and reload annotation layers via storage service', () async {
      final docId = 'doc_test_12345';
      final annotations = <int, List<BoardStroke>>{
        1: [
          BoardStroke(
            const Color(0xff89b4fa),
            1.5,
            const [Offset(0.1, 0.1), Offset(0.3, 0.2)],
            id: 'ann_grammar_1',
            rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.1),
            isHollow: true,
            isDashed: true,
            text: 'were placed',
            category: 'grammar',
            level: 'B2',
            opacity: 0.85,
          ),
          BoardStroke(
            const Color(0xff22c55e),
            20.0,
            const [Offset(0.12, 0.12), Offset(0.25, 0.18)],
            id: 'ann_vocab_1',
            rect: const Rect.fromLTWH(0.12, 0.12, 0.13, 0.06),
            isHollow: false,
            text: 'placed',
            category: 'vocabulary',
            level: 'A1',
            opacity: 0.18,
          ),
        ],
      };

      final saved = await storageService.saveAnnotations(
        documentId: docId,
        filePath: 'C:/docs/lesson.pdf',
        annotations: annotations,
        highlightsVisible: true,
      );
      expect(saved, isTrue);

      final loaded = await storageService.loadAnnotations(documentId: docId);
      expect(loaded, isNotNull);
      expect(loaded!.documentId, equals(docId));
      expect(loaded.highlightsVisible, isTrue);
      expect(loaded.annotations[1], hasLength(2));

      final grammarStroke = loaded.annotations[1]!.first;
      expect(grammarStroke.category, equals('grammar'));
      expect(grammarStroke.isDashed, isTrue);
      expect(grammarStroke.text, equals('were placed'));
      expect(
        grammarStroke.rect,
        equals(const Rect.fromLTWH(0.1, 0.1, 0.2, 0.1)),
      );

      final vocabStroke = loaded.annotations[1]!.last;
      expect(vocabStroke.category, equals('vocabulary'));
      expect(vocabStroke.level, equals('A1'));
      expect(vocabStroke.text, equals('placed'));
    });

    test(
      'reopening document restores persistent annotations automatically',
      () async {
        final sampleBytes = createSamplePdfBytes();
        final sampleFile = File(
          '${tempDir.path}${Platform.pathSeparator}test_course.pdf',
        );
        await sampleFile.writeAsBytes(sampleBytes);

        final docId = await storageService.computeDocumentId(
          filePath: sampleFile.path,
          bytes: sampleBytes,
        );

        // Pre-save annotations in storage service
        await storageService.saveAnnotations(
          documentId: docId,
          filePath: sampleFile.path,
          annotations: {
            1: [
              BoardStroke(
                const Color(0xfff59e0b),
                20.0,
                const [Offset(0.2, 0.3), Offset(0.4, 0.35)],
                rect: const Rect.fromLTWH(0.2, 0.3, 0.2, 0.05),
                category: 'vocabulary',
                level: 'B2',
                text: 'bitterness',
                opacity: 0.22,
              ),
            ],
          },
        );

        // Simulate a fresh StudioState opening the PDF
        final studio = StudioState()..loading = false;
        studio.setPdfFile(sampleFile.path, sampleBytes);

        // Await persistent restoration
        await studio.pdf.restorePersistentAnnotations();

        expect(studio.pdfAnnotations[1], isNotNull);
        expect(studio.pdfAnnotations[1], hasLength(1));
        expect(studio.pdfAnnotations[1]!.first.text, equals('bitterness'));
        expect(studio.pdfAnnotations[1]!.first.level, equals('B2'));

        // Re-opening the same file again does not duplicate annotations
        await studio.pdf.restorePersistentAnnotations();
        expect(studio.pdfAnnotations[1], hasLength(1));
      },
    );

    test(
      'document identity prevents cross-document annotation leakage',
      () async {
        final bytesA = createSamplePdfBytes('Document Alpha');
        final bytesB = createSamplePdfBytes('Document Beta');

        final idA = await storageService.computeDocumentId(
          filePath: 'C:/docs/alpha.pdf',
          bytes: bytesA,
        );
        final idB = await storageService.computeDocumentId(
          filePath: 'C:/docs/beta.pdf',
          bytes: bytesB,
        );

        expect(idA, isNot(equals(idB)));
      },
    );

    test(
      'document identity detects same-size edits in the middle of the PDF',
      () async {
        final bytesA = Uint8List(4096)..fillRange(0, 4096, 0x41);
        final bytesB = Uint8List.fromList(bytesA)..[2048] = 0x42;

        final idA = await storageService.computeDocumentId(
          filePath: 'C:/docs/lesson.pdf',
          bytes: bytesA,
        );
        final idB = await storageService.computeDocumentId(
          filePath: 'C:/docs/lesson.pdf',
          bytes: bytesB,
        );
        final pdfFile = File(
          '${tempDir.path}${Platform.pathSeparator}lesson.pdf',
        );
        await pdfFile.writeAsBytes(bytesA);
        final fileIdA = await storageService.computeDocumentId(
          filePath: pdfFile.path,
        );
        await pdfFile.writeAsBytes(bytesB);
        final fileIdB = await storageService.computeDocumentId(
          filePath: pdfFile.path,
        );

        expect(idA, isNot(equals(idB)));
        expect(fileIdA, isNot(equals(fileIdB)));
      },
    );

    test(
      'replacing an annotation layer leaves valid JSON and no temporary file',
      () async {
        const documentId = 'doc_atomic';
        final firstSaved = await storageService.saveAnnotations(
          documentId: documentId,
          annotations: const {},
        );
        final replaced = await storageService.saveAnnotations(
          documentId: documentId,
          annotations: {
            1: [
              BoardStroke(const Color(0xff22c55e), 20, const [
                Offset(0.1, 0.1),
                Offset(0.2, 0.2),
              ], text: 'updated'),
            ],
          },
        );

        expect(firstSaved, isTrue);
        expect(replaced, isTrue);
        final loaded = await storageService.loadAnnotations(
          documentId: documentId,
        );
        expect(loaded?.annotations[1]?.single.text, 'updated');
        expect(
          tempDir.listSync().where((entry) => entry.path.endsWith('.tmp')),
          isEmpty,
        );
      },
    );

    test(
      'stale sidecar annotations are not restored after a same-size PDF edit',
      () async {
        final originalBytes = Uint8List(4096)..fillRange(0, 4096, 0x41);
        final editedBytes = Uint8List.fromList(originalBytes)..[2048] = 0x42;
        final pdfFile = File(
          '${tempDir.path}${Platform.pathSeparator}source.pdf',
        );
        await pdfFile.writeAsBytes(originalBytes);
        final originalId = await storageService.computeDocumentId(
          filePath: pdfFile.path,
          bytes: originalBytes,
        );

        final saved = await storageService.saveAnnotations(
          documentId: originalId,
          filePath: pdfFile.path,
          annotations: {
            1: [
              BoardStroke(const Color(0xff22c55e), 20, const [
                Offset(0.1, 0.1),
                Offset(0.2, 0.2),
              ], text: 'stale annotation'),
            ],
          },
        );
        expect(saved, isTrue);

        await File(
          '${tempDir.path}${Platform.pathSeparator}$originalId.json',
        ).delete();
        await pdfFile.writeAsBytes(editedBytes);

        final restored = await storageService.loadAnnotations(
          filePath: pdfFile.path,
          bytes: editedBytes,
        );
        expect(restored, isNull);
      },
    );
  });

  group('C. Eraser and Undo/Redo Support', () {
    test('eraser removes an individual vocabulary highlight using hitTest', () {
      final studio = StudioState()..loading = false;
      final targetPageStrokes = studio.pdfAnnotations.putIfAbsent(1, () => []);

      final stroke1 = BoardStroke(
        const Color(0xff22c55e),
        20.0,
        const [Offset(0.1, 0.1), Offset(0.3, 0.15)],
        rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05),
        category: 'vocabulary',
        level: 'A1',
      );
      final stroke2 = BoardStroke(
        const Color(0xff3b82f6),
        20.0,
        const [Offset(0.5, 0.5), Offset(0.7, 0.55)],
        rect: const Rect.fromLTWH(0.5, 0.5, 0.2, 0.05),
        category: 'vocabulary',
        level: 'B1',
      );

      targetPageStrokes.addAll([stroke1, stroke2]);
      expect(targetPageStrokes, hasLength(2));

      // Drag eraser across the middle of stroke1 (norm point: 0.2, 0.125)
      studio.erase(
        const Offset(0.2, 0.125),
        target: targetPageStrokes,
        pageNumber: 1,
      );

      // Only stroke1 is erased; stroke2 remains untouched
      expect(targetPageStrokes, hasLength(1));
      expect(targetPageStrokes.first.level, equals('B1'));
    });

    test(
      'overlapping annotations are erased independently (inner specific word first)',
      () {
        final studio = StudioState()..loading = false;
        final targetPageStrokes = studio.pdfAnnotations.putIfAbsent(
          1,
          () => [],
        );

        // Grammar outer box (larger area: 0.08)
        final grammarStroke = BoardStroke(
          const Color(0xff89b4fa),
          1.5,
          const [Offset(0.08, 0.08), Offset(0.48, 0.28)],
          rect: const Rect.fromLTWH(0.08, 0.08, 0.4, 0.2),
          isHollow: true,
          isDashed: true,
          category: 'grammar',
        );

        // Inner vocab highlight (smaller area: 0.01)
        final vocabStroke = BoardStroke(
          const Color(0xff22c55e),
          20.0,
          const [Offset(0.1, 0.1), Offset(0.2, 0.2)],
          rect: const Rect.fromLTWH(0.1, 0.1, 0.1, 0.1),
          category: 'vocabulary',
          level: 'A1',
        );

        targetPageStrokes.addAll([grammarStroke, vocabStroke]);
        expect(targetPageStrokes, hasLength(2));

        // Touch at (0.15, 0.15) which is inside BOTH grammar and vocab
        studio.erase(
          const Offset(0.15, 0.15),
          target: targetPageStrokes,
          pageNumber: 1,
        );

        // Deterministic policy: Inner smaller vocab is erased first
        expect(targetPageStrokes, hasLength(1));
        expect(targetPageStrokes.first.category, equals('grammar'));

        // Touch again: now grammar is erased
        studio.erase(
          const Offset(0.15, 0.15),
          target: targetPageStrokes,
          pageNumber: 1,
        );
        expect(targetPageStrokes, isEmpty);
      },
    );

    test('undo restores erased annotation and redo removes it again', () {
      final studio = StudioState()..loading = false;
      final targetPageStrokes = studio.pdfAnnotations.putIfAbsent(1, () => []);

      final stroke = BoardStroke(
        const Color(0xfff97316),
        20.0,
        const [Offset(0.2, 0.2), Offset(0.4, 0.25)],
        rect: const Rect.fromLTWH(0.2, 0.2, 0.2, 0.05),
        category: 'vocabulary',
        level: 'C1',
      );
      targetPageStrokes.add(stroke);

      // Erase
      studio.erase(
        const Offset(0.3, 0.22),
        target: targetPageStrokes,
        pageNumber: 1,
      );
      expect(targetPageStrokes, isEmpty);
      expect(studio.canUndo, isTrue);

      // Undo
      studio.undo();
      expect(targetPageStrokes, hasLength(1));
      expect(targetPageStrokes.first.level, equals('C1'));
      expect(studio.canRedo, isTrue);

      // Redo
      studio.redo();
      expect(targetPageStrokes, isEmpty);
    });

    test(
      'clearPdfHighlights removes only highlights, leaving freehand strokes untouched',
      () {
        final studio = StudioState()..loading = false;
        final targetPageStrokes = studio.pdfAnnotations.putIfAbsent(
          1,
          () => [],
        );

        final highlightStroke = BoardStroke(
          const Color(0xff22c55e),
          20.0,
          const [Offset(0.1, 0.1), Offset(0.3, 0.15)],
          rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05),
          category: 'vocabulary',
          level: 'A1',
        );

        final freehandStroke = BoardStroke(
          const Color(0xffff0000),
          3.0,
          const [Offset(0.5, 0.5), Offset(0.6, 0.6)],
          category: null, // Freehand
        );

        targetPageStrokes.addAll([highlightStroke, freehandStroke]);
        expect(targetPageStrokes, hasLength(2));

        studio.clearPdfHighlights(pageNumber: 1);

        // Highlight is removed; freehand handwriting stroke is preserved
        expect(targetPageStrokes, hasLength(1));
        expect(targetPageStrokes.first.category, isNull);
        expect(targetPageStrokes.first.color, equals(const Color(0xffff0000)));

        // Undo restores the cleared highlights
        studio.undo();
        expect(targetPageStrokes, hasLength(2));
      },
    );
  });

  group('D. Visibility Controls & Layer Toggle', () {
    test(
      'togglePdfHighlightsVisible hides highlights in pdfAnnotationsForPage without deleting them',
      () {
        final studio = StudioState()..loading = false;
        final targetPageStrokes = studio.pdfAnnotations.putIfAbsent(
          1,
          () => [],
        );

        final highlightStroke = BoardStroke(
          const Color(0xff22c55e),
          20.0,
          const [Offset(0.1, 0.1), Offset(0.3, 0.15)],
          rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05),
          category: 'vocabulary',
          level: 'A1',
        );
        final freehandStroke = BoardStroke(const Color(0xffffffff), 3.0, const [
          Offset(0.5, 0.5),
          Offset(0.6, 0.6),
        ]);

        targetPageStrokes.addAll([highlightStroke, freehandStroke]);

        // Initially both visible
        expect(studio.pdfAnnotationsForPage(1), hasLength(2));

        // Toggle off
        studio.togglePdfHighlightsVisible();
        expect(studio.pdfHighlightsVisible, isFalse);

        // Only freehand stroke is returned; highlight is hidden
        final filtered = studio.pdfAnnotationsForPage(1);
        expect(filtered, hasLength(1));
        expect(filtered.first.category, isNull);

        // But underlying data in pdfAnnotations is NOT deleted
        expect(targetPageStrokes, hasLength(2));

        // Toggle back on
        studio.togglePdfHighlightsVisible();
        expect(studio.pdfHighlightsVisible, isTrue);
        expect(studio.pdfAnnotationsForPage(1), hasLength(2));
      },
    );
  });

  group('E. Legacy Baked-in PDF Detection', () {
    test(
      'detectLegacyBakedPdf detects old documents with baked annotations',
      () {
        final sampleClean = createSamplePdfBytes(
          'Pure text without annotations',
        );
        expect(storageService.detectLegacyBakedPdf(sampleClean), isFalse);

        final doc = sf.PdfDocument();
        final page = doc.pages.add();
        final annotation = sf.PdfTextMarkupAnnotation(
          const Rect.fromLTWH(10, 10, 100, 20),
          'highlighted',
          sf.PdfColor(255, 0, 0),
          author: 'Học Lực - Trợ giảng Tiếng Anh',
          textMarkupAnnotationType: sf.PdfTextMarkupAnnotationType.highlight,
        );
        page.annotations.add(annotation);
        final legacyBytes = Uint8List.fromList(doc.saveSync());
        doc.dispose();

        expect(storageService.detectLegacyBakedPdf(legacyBytes), isTrue);
      },
    );
  });
}
