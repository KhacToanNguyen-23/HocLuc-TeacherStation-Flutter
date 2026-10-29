import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_storage_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/widgets/pdf_annotation_save_indicator.dart';
import 'package:teaching_companion/features/studio_board/services/controllers/pdf_smart_pen_controller.dart';

class _MockBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _DelayedAnnotationStorage extends PdfAnnotationStorageService {
  _DelayedAnnotationStorage(this.loads);

  final Map<String, Completer<PdfAnnotationLayerData?>> loads;

  @override
  Future<PdfAnnotationLayerData?> loadAnnotations({
    String? filePath,
    Uint8List? bytes,
    String? documentId,
  }) => loads
      .putIfAbsent(filePath!, Completer<PdfAnnotationLayerData?>.new)
      .future;
}

class _CountingAnnotationStorage extends PdfAnnotationStorageService {
  int identityComputations = 0;
  int saveCalls = 0;
  bool saveResult = true;
  Completer<void>? saveStarted;
  Completer<void>? releaseSave;
  final List<Map<int, List<BoardStroke>>> savedSnapshots = [];
  final List<String> savedDocumentIds = [];
  final List<String?> savedFilePaths = [];

  @override
  Future<String> computeDocumentId({
    String? filePath,
    Uint8List? bytes,
    String? contentSha256,
    int? contentLength,
    String? operationId,
  }) async {
    identityComputations++;
    return 'test-document-$identityComputations';
  }

  @override
  Future<PdfAnnotationLayerData?> loadAnnotations({
    String? filePath,
    Uint8List? bytes,
    String? documentId,
  }) async => null;

  @override
  Future<bool> saveAnnotations({
    required String documentId,
    String? filePath,
    required Map<int, List<BoardStroke>> annotations,
    bool highlightsVisible = true,
    String? operationId,
    int? pdfBytesLength,
  }) async {
    saveCalls++;
    savedDocumentIds.add(documentId);
    savedFilePaths.add(filePath);
    savedSnapshots.add({
      for (final entry in annotations.entries)
        entry.key: List<BoardStroke>.of(entry.value),
    });
    if (saveStarted != null && !saveStarted!.isCompleted) {
      saveStarted!.complete();
    }
    await releaseSave?.future;
    return saveResult;
  }
}

class _MeasuredAnnotationStorage extends PdfAnnotationStorageService {
  _MeasuredAnnotationStorage(Directory directory)
    : super(customStorageDirectory: directory);

  int identityComputations = 0;
  int saveCalls = 0;
  int reusedContentFingerprints = 0;

  @override
  Future<String> computeDocumentId({
    String? filePath,
    Uint8List? bytes,
    String? contentSha256,
    int? contentLength,
    String? operationId,
  }) {
    identityComputations++;
    if (contentSha256 != null) reusedContentFingerprints++;
    return super.computeDocumentId(
      filePath: filePath,
      bytes: bytes,
      contentSha256: contentSha256,
      contentLength: contentLength,
      operationId: operationId,
    );
  }

  @override
  Future<bool> saveAnnotations({
    required String documentId,
    String? filePath,
    required Map<int, List<BoardStroke>> annotations,
    bool highlightsVisible = true,
    String? operationId,
    int? pdfBytesLength,
  }) {
    saveCalls++;
    return super.saveAnnotations(
      documentId: documentId,
      filePath: filePath,
      annotations: annotations,
      highlightsVisible: highlightsVisible,
      operationId: operationId,
      pdfBytesLength: pdfBytesLength,
    );
  }
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

  group('PDF highlight batch persistence', () {
    PdfSmartPenController createController(_CountingAnnotationStorage storage) {
      final controller = PdfSmartPenController(
        storageServiceFactory: () => storage,
      );
      controller.setPdfFile('batch-test.pdf', Uint8List.fromList([1, 2, 3, 4]));
      return controller;
    }

    List<BoardStroke> createHighlights(int count, {int startAt = 0}) => [
      for (var index = startAt; index < startAt + count; index++)
        BoardStroke(
          const Color(0xff22c55e),
          20,
          [Offset(index / 1000, 0.1), Offset(index / 1000 + 0.01, 0.1)],
          id: 'highlight-$index',
          rect: Rect.fromLTWH(index / 1000, 0.1, 0.01, 0.02),
          category: 'vocabulary',
        ),
    ];

    test(
      'one batch persists once and is undone/redone as one action',
      () async {
        final storage = _CountingAnnotationStorage();
        final controller = createController(storage);
        addTearDown(controller.dispose);
        await controller.restorePersistentAnnotations();

        var notifications = 0;
        controller.addListener(() => notifications++);
        final highlights = createHighlights(48);
        final fingerprintCountBeforeBatch =
            controller.contentFingerprintComputations;
        final stopwatch = Stopwatch()..start();
        final saved = await controller.recordAnnotationsAdded({1: highlights});
        stopwatch.stop();

        expect(saved, isTrue);
        expect(controller.pdfAnnotations[1], hasLength(48));
        expect(controller.canUndoAnnotation, isTrue);
        expect(controller.isPersistingAnnotations, isFalse);
        expect(storage.saveCalls, 1);
        expect(storage.identityComputations, 1);
        expect(
          controller.contentFingerprintComputations,
          fingerprintCountBeforeBatch,
        );
        expect(notifications, 2); // batch commit and persistence completion
        debugPrint(
          'PDF highlight batch: 48 annotations, '
          '${storage.identityComputations} document-id computations, '
          '${storage.saveCalls} persistence operations, '
          '0 full-PDF hashes during batch, '
          '${stopwatch.elapsedMicroseconds / 1000} ms.',
        );

        // An accidental duplicate submission is idempotent and adds no history.
        expect(
          await controller.recordAnnotationsAdded({1: highlights}),
          isTrue,
        );
        expect(storage.saveCalls, 1);
        expect(controller.pdfAnnotations[1], hasLength(48));

        expect(controller.undoAnnotation(), isTrue);
        expect(controller.pdfAnnotations[1], isEmpty);
        await controller.flushPendingAnnotationPersistence();
        expect(controller.redoAnnotation(), isTrue);
        expect(controller.pdfAnnotations[1], hasLength(48));
        await controller.flushPendingAnnotationPersistence();
      },
    );

    test('rapid pending saves coalesce to the latest snapshot', () async {
      final storage = _CountingAnnotationStorage();
      final controller = createController(storage);
      addTearDown(controller.dispose);
      await controller.restorePersistentAnnotations();

      final writes = [
        controller.savePersistentAnnotations(),
        controller.savePersistentAnnotations(),
        controller.savePersistentAnnotations(),
      ];
      expect(await Future.wait(writes), everyElement(isTrue));
      expect(storage.saveCalls, 1);
    });

    test(
      'several rapid batches persist their combined latest state once',
      () async {
        final storage = _CountingAnnotationStorage();
        final controller = createController(storage);
        addTearDown(controller.dispose);
        await controller.restorePersistentAnnotations();

        final first = controller.recordAnnotationsAdded({
          1: createHighlights(2, startAt: 0),
        });
        final second = controller.recordAnnotationsAdded({
          1: createHighlights(2, startAt: 2),
        });
        final third = controller.recordAnnotationsAdded({
          2: createHighlights(1, startAt: 4),
        });

        expect(await Future.wait([first, second, third]), everyElement(isTrue));
        expect(storage.saveCalls, 1);
        expect(controller.pdfAnnotations[1], hasLength(4));
        expect(controller.pdfAnnotations[2], hasLength(1));
        expect(storage.savedSnapshots.single[1], hasLength(4));
        expect(storage.savedSnapshots.single[2], hasLength(1));
      },
    );

    test(
      'representative batch uses one real storage write and cached identity',
      () async {
        final representativePdf = File(
          '${tempDir.path}${Platform.pathSeparator}representative.pdf',
        );
        final representativeBytes = Uint8List(4472975)
          ..fillRange(0, 4472975, 7);
        await representativePdf.writeAsBytes(representativeBytes);

        // Reproduce the previous per-annotation persistence pattern: 48
        // annotation commits plus the exporter's final save, each recalculating
        // the content identity and writing both destinations.
        final legacyDirectory = Directory(
          '${tempDir.path}${Platform.pathSeparator}legacy',
        )..createSync();
        final legacyPdf = File(
          '${legacyDirectory.path}${Platform.pathSeparator}representative.pdf',
        );
        await legacyPdf.writeAsBytes(representativeBytes);
        final legacyStorage = PdfAnnotationStorageService(
          customStorageDirectory: legacyDirectory,
        );
        final priorDebugPrint = debugPrint;
        final legacyTimer = Stopwatch()..start();
        var legacyIdentityComputations = 0;
        var legacyWriteOperations = 0;
        debugPrint = (String? message, {int? wrapWidth}) {};
        try {
          for (var count = 1; count <= 48; count++) {
            final documentId = await legacyStorage.computeDocumentId(
              filePath: legacyPdf.path,
              bytes: representativeBytes,
            );
            legacyIdentityComputations++;
            final saved = await legacyStorage.saveAnnotations(
              documentId: documentId,
              filePath: legacyPdf.path,
              annotations: {1: createHighlights(count)},
              pdfBytesLength: representativeBytes.length,
            );
            expect(saved, isTrue);
            legacyWriteOperations++;
          }
          final finalDocumentId = await legacyStorage.computeDocumentId(
            filePath: legacyPdf.path,
            bytes: representativeBytes,
          );
          legacyIdentityComputations++;
          expect(
            await legacyStorage.saveAnnotations(
              documentId: finalDocumentId,
              filePath: legacyPdf.path,
              annotations: {1: createHighlights(48)},
              pdfBytesLength: representativeBytes.length,
            ),
            isTrue,
          );
          legacyWriteOperations++;
        } finally {
          legacyTimer.stop();
          debugPrint = priorDebugPrint;
        }

        final storage = _MeasuredAnnotationStorage(tempDir);
        final controller = PdfSmartPenController(
          storageServiceFactory: () => storage,
        );
        addTearDown(controller.dispose);
        controller.setPdfFile(representativePdf.path, representativeBytes);
        await controller.restorePersistentAnnotations();
        final fingerprintCountBeforeBatch =
            controller.contentFingerprintComputations;

        final stopwatch = Stopwatch()..start();
        final saved = await controller.recordAnnotationsAdded({
          1: createHighlights(48),
        });
        stopwatch.stop();

        expect(saved, isTrue);
        expect(storage.saveCalls, 1);
        expect(storage.identityComputations, 1);
        expect(storage.reusedContentFingerprints, 1);
        expect(
          controller.contentFingerprintComputations,
          fingerprintCountBeforeBatch,
        );
        expect(await File('${representativePdf.path}.hlann').exists(), isTrue);
        expect(
          tempDir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.json'),
          ),
          hasLength(1),
        );
        debugPrint(
          'Synthetic previous path: 48 annotations, '
          '$legacyIdentityComputations full-PDF identity computations, '
          '$legacyWriteOperations app-data+sidecar writes, '
          '${legacyTimer.elapsedMicroseconds / 1000} ms.\n'
          'Optimized path: 48 annotations, '
          '${storage.identityComputations} identity computations '
          '(${storage.reusedContentFingerprints} reused content fingerprint), '
          '${storage.saveCalls} disk write operation, '
          '0 full-PDF hashes during batch, '
          '${stopwatch.elapsedMicroseconds / 1000} ms.',
        );
      },
    );

    test('a commit during an in-flight save is persisted afterward', () async {
      final storage = _CountingAnnotationStorage()
        ..saveStarted = Completer<void>()
        ..releaseSave = Completer<void>();
      final controller = createController(storage);
      addTearDown(controller.dispose);
      await controller.restorePersistentAnnotations();

      final firstSave = controller.savePersistentAnnotations();
      await storage.saveStarted!.future;
      final secondSave = controller.recordAnnotationsAdded({
        1: createHighlights(1),
      });
      storage.releaseSave!.complete();

      expect(await firstSave, isTrue);
      expect(await secondSave, isTrue);
      expect(storage.saveCalls, 2);
      expect(storage.savedSnapshots.last[1], hasLength(1));
      expect(controller.isPersistingAnnotations, isFalse);
    });

    test(
      'a document switch keeps pending saves attached to their PDF',
      () async {
        final storage = _CountingAnnotationStorage()
          ..saveStarted = Completer<void>()
          ..releaseSave = Completer<void>();
        final controller = createController(storage);
        addTearDown(controller.dispose);
        await controller.restorePersistentAnnotations();

        final firstSave = controller.recordAnnotationsAdded({
          1: createHighlights(2),
        });
        await storage.saveStarted!.future;

        controller.setPdfFile(
          'second-batch-test.pdf',
          Uint8List.fromList([4, 5]),
        );
        await controller.restorePersistentAnnotations();
        final secondSave = controller.recordAnnotationsAdded({
          1: createHighlights(1, startAt: 3),
        });
        storage.releaseSave!.complete();

        expect(await firstSave, isTrue);
        expect(await secondSave, isTrue);
        expect(storage.savedDocumentIds, [
          'test-document-1',
          'test-document-2',
        ]);
        expect(storage.savedFilePaths, [
          'batch-test.pdf',
          'second-batch-test.pdf',
        ]);
        expect(storage.savedSnapshots[0][1], hasLength(2));
        expect(storage.savedSnapshots[1][1], hasLength(1));
      },
    );

    test(
      'document identity is cached and invalidated for new PDF bytes',
      () async {
        final storage = _CountingAnnotationStorage();
        final controller = createController(storage);
        addTearDown(controller.dispose);
        await controller.restorePersistentAnnotations();
        expect(storage.identityComputations, 1);

        await controller.savePersistentAnnotations();
        await controller.savePersistentAnnotations();
        expect(storage.identityComputations, 1);

        controller.updatePdfBytesInPlace(Uint8List.fromList([4, 3, 2, 1]));
        await controller.savePersistentAnnotations();
        expect(storage.identityComputations, 2);
      },
    );

    test('failed saves remain in memory and can be retried', () async {
      final storage = _CountingAnnotationStorage()..saveResult = false;
      final controller = createController(storage);
      addTearDown(controller.dispose);
      await controller.restorePersistentAnnotations();

      expect(
        await controller.recordAnnotationsAdded({1: createHighlights(2)}),
        isFalse,
      );
      expect(controller.pdfAnnotations[1], hasLength(2));
      expect(controller.annotationPersistenceError, isNotNull);
      expect(controller.isPersistingAnnotations, isFalse);

      storage.saveResult = true;
      expect(await controller.retryAnnotationPersistence(), isTrue);
      expect(controller.annotationPersistenceError, isNull);
      expect(controller.pdfAnnotations[1], hasLength(2));
      expect(controller.isPersistingAnnotations, isFalse);
    });
  });

  testWidgets(
    'PDF save indicator is not queued and an older save cannot clear a newer one',
    (tester) async {
      PdfAnnotationSaveIndicatorToken? firstOperation;
      PdfAnnotationSaveIndicatorToken? secondOperation;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        duration: Duration(days: 1),
                        content: Text('Unrelated notification'),
                      ),
                    ),
                    child: const Text('Show unrelated'),
                  ),
                  ElevatedButton(
                    onPressed: () => firstOperation =
                        PdfAnnotationSaveIndicator.show(context, 'save-old'),
                    child: const Text('Show old save'),
                  ),
                  ElevatedButton(
                    onPressed: () => secondOperation =
                        PdfAnnotationSaveIndicator.show(context, 'save-new'),
                    child: const Text('Show new save'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        PdfAnnotationSaveIndicator.hide(firstOperation),
                    child: const Text('Complete old save'),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        PdfAnnotationSaveIndicator.hide(secondOperation),
                    child: const Text('Complete new save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show unrelated'));
      await tester.pump();
      await tester.tap(find.text('Show old save'));
      await tester.pump();
      expect(find.text('Đang lưu các điểm highlight…'), findsOneWidget);

      await tester.tap(find.text('Show new save'));
      await tester.pump();
      await tester.tap(find.text('Complete old save'));
      await tester.pump();
      expect(find.text('Đang lưu các điểm highlight…'), findsOneWidget);
      expect(find.text('Unrelated notification'), findsOneWidget);

      await tester.tap(find.text('Complete new save'));
      await tester.pump();
      expect(find.text('Đang lưu các điểm highlight…'), findsNothing);
      expect(find.text('Unrelated notification'), findsOneWidget);
    },
  );

  group('A. Non-Destructive Protection & Source PDF Integrity', () {
    test(
      'undo and redo follow the order of PDF highlights and board strokes',
      () async {
        final studio = StudioState()..loading = false;
        addTearDown(studio.dispose);
        studio.setPdfFile('history-order.pdf', Uint8List.fromList([8, 4, 2]));

        final highlight = BoardStroke(
          const Color(0xff22c55e),
          20,
          const [Offset(0.1, 0.1), Offset(0.3, 0.1)],
          rect: const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05),
          category: 'vocabulary',
        );
        studio.pdf.recordAnnotationAdded(1, highlight);
        studio.startStroke(const Offset(0.4, 0.4));
        final boardStroke = studio.strokes.single;

        studio.undo();
        expect(studio.strokes, isEmpty);
        expect(studio.pdfAnnotations[1], contains(highlight));

        studio.redo();
        expect(studio.strokes, contains(boardStroke));
        studio.undo();
        studio.undo();
        expect(studio.pdfAnnotations[1], isEmpty);

        studio.redo();
        expect(studio.pdfAnnotations[1], contains(highlight));
        studio.redo();
        expect(studio.strokes, contains(boardStroke));
        await studio.pdf.flushPendingAnnotationPersistence();
      },
    );

    test(
      'late annotation restore is discarded after switching documents',
      () async {
        final loads = <String, Completer<PdfAnnotationLayerData?>>{};
        final controller = PdfSmartPenController(
          storageServiceFactory: () => _DelayedAnnotationStorage(loads),
        );
        addTearDown(controller.dispose);
        controller.setPdfFile('document-a.pdf', Uint8List.fromList([1, 1, 1]));
        await Future<void>.delayed(Duration.zero);
        controller.setPdfFile('document-b.pdf', Uint8List.fromList([2, 2, 2]));

        final staleStroke = BoardStroke(const Color(0xffef4444), 4, const [
          Offset(0.2, 0.2),
          Offset(0.3, 0.3),
        ]);
        loads['document-a.pdf']!.complete(
          PdfAnnotationLayerData(
            documentId: 'document-a',
            annotations: {
              1: [staleStroke],
            },
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(controller.pdfAnnotations, isEmpty);

        loads['document-b.pdf']!.complete(null);
        await Future<void>.delayed(Duration.zero);
        expect(controller.pdfAnnotations, isEmpty);
      },
    );

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
      'cached content fingerprint preserves the existing document ID',
      () async {
        final bytes = Uint8List.fromList([3, 6, 9, 12]);
        final fingerprint = sha256.convert(bytes).toString();
        final directId = await storageService.computeDocumentId(
          filePath: 'C:/docs/cached.pdf',
          bytes: bytes,
        );
        final cachedId = await storageService.computeDocumentId(
          filePath: 'C:/docs/cached.pdf',
          bytes: bytes,
          contentSha256: fingerprint,
          contentLength: bytes.length,
        );

        expect(cachedId, directId);
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
