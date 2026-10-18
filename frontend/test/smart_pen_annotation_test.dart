import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/widgets/stroke_canvas.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

const _pageSize = Size(600, 800);

void main() {
  group('Smart Pen oval geometry and persistence', () {
    test('generates stable hand-drawn points around the answer label', () {
      final selection = _selection(
        page: 3,
        label: 'B',
        group: 'q-12',
        bounds: const Rect.fromLTWH(120, 240, 18, 20),
      );

      final first = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: _pageSize,
        color: const Color(0xfff0f3ed),
        width: 3.5,
        seed: 914,
      );
      final second = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: _pageSize,
        color: const Color(0xfff0f3ed),
        width: 3.5,
        seed: 914,
      );

      expect(first.points, isNotEmpty);
      expect(first.points, second.points);
      expect(first.pageNumber, 3);
      expect(first.label, 'B');
      expect(first.groupId, 'q-12');
      expect(
        first.points.every(
          (point) =>
              point.dx >= 0 && point.dx <= 1 && point.dy >= 0 && point.dy <= 1,
        ),
        isTrue,
      );
      expect(first.points.length, greaterThanOrEqualTo(12));

      final center = first.normalizedLabelBounds.center;
      final normalizedRadii = first.points.map((point) {
        final dx =
            (point.dx - center.dx) / (first.normalizedLabelBounds.width / 2);
        final dy =
            (point.dy - center.dy) / (first.normalizedLabelBounds.height / 2);
        return math.sqrt(dx * dx + dy * dy);
      }).toList();
      expect(
        normalizedRadii.reduce((a, b) => a > b ? a : b) -
            normalizedRadii.reduce((a, b) => a < b ? a : b),
        greaterThan(0.01),
      );
    });

    test(
      'round-trips oval metadata and geometry through model and BoardStroke JSON',
      () {
        final oval = SmartPenOvalAnnotation.fromSelection(
          selection: _selection(page: 2, label: 'A', group: 'q-4'),
          pageSize: _pageSize,
          color: const Color(0xffdf5577),
          width: 4,
          seed: 5,
        );

        final decoded = SmartPenOvalAnnotation.fromJson(oval.toJson());
        final decodedStroke = BoardStroke.fromJson(
          oval.toBoardStroke().toJson(),
        );

        expect(decoded.toJson(), oval.toJson());
        expect(decodedStroke.isSmartPenOval, isTrue);
        expect(decodedStroke.smartPenGroupId, 'q-4');
        expect(decodedStroke.smartPenLabel, 'A');
        expect(decodedStroke.points, oval.points);
        expect(decodedStroke.color, const Color(0xffdf5577));
      },
    );

    test(
      'preserves legacy freehand BoardStroke JSON without Smart Pen fields',
      () {
        final legacyJson = <String, dynamic>{
          'color': const Color(0xff336699).toARGB32(),
          'width': 2.5,
          'isEraser': false,
          'points': [
            [0.1, 0.2],
            [0.3, 0.4],
          ],
        };

        final decoded = BoardStroke.fromJson(legacyJson);

        expect(decoded.color, const Color(0xff336699));
        expect(decoded.width, 2.5);
        expect(decoded.points, [
          const Offset(0.1, 0.2),
          const Offset(0.3, 0.4),
        ]);
        expect(decoded.isSmartPenOval, isFalse);
        expect(decoded.smartPenGroupId, isNull);
        expect(decoded.smartPenLabel, isNull);
        expect(decoded.toJson().containsKey('smartPenGroupId'), isFalse);
      },
    );

    test('persists PDF Smart Pen and legacy annotations in lesson JSON', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final oval = SmartPenOvalAnnotation.fromSelection(
        selection: _selection(page: 3, label: 'C', group: 'q-save'),
        pageSize: _pageSize,
        color: const Color(0xffed6a5a),
        width: 3.5,
        seed: 87,
      ).toBoardStroke();
      final freehand = BoardStroke(const Color(0xff336699), 2, const [
        Offset(0.1, 0.2),
        Offset(0.3, 0.4),
      ]);
      studio.pdfAnnotations[3] = [oval, freehand];

      final saved = studio.exportLessonJson();
      final restored = StudioState()..restoreFromJson(saved);
      addTearDown(restored.dispose);

      expect(restored.pdfAnnotations[3], hasLength(2));
      expect(restored.pdfAnnotations[3]!.first.isSmartPenOval, isTrue);
      expect(restored.pdfAnnotations[3]!.first.smartPenGroupId, 'q-save');
      expect(restored.pdfAnnotations[3]!.last.points, freehand.points);
    });
  });

  group('Smart Pen PDF answer selection history', () {
    test('adds an oval and undo/redo each apply as a single action', () {
      final studio = StudioState()
        ..ink = const Color(0xffed6a5a)
        ..strokeWidth = 3.5;
      addTearDown(studio.dispose);
      final selection = _selection(page: 1, label: 'C', group: 'q-7');

      studio.toggleSmartPenAnswer(selection, _pageSize);
      expect(_ovals(studio, 1), hasLength(1));
      expect(_ovals(studio, 1).single.smartPenLabel, 'C');

      studio.undo();
      expect(_ovals(studio, 1), isEmpty);
      studio.redo();
      expect(_ovals(studio, 1), hasLength(1));
      expect(_ovals(studio, 1).single.smartPenLabel, 'C');
    });

    test('tapping the same answer toggles off and the removal is undoable', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final selection = _selection(page: 1, label: 'A', group: 'q-2');

      studio.toggleSmartPenAnswer(selection, _pageSize);
      studio.toggleSmartPenAnswer(selection, _pageSize);
      expect(_ovals(studio, 1), isEmpty);

      studio.undo();
      expect(_ovals(studio, 1), hasLength(1));
      expect(_ovals(studio, 1).single.smartPenLabel, 'A');
      studio.redo();
      expect(_ovals(studio, 1), isEmpty);
    });

    test(
      'replaces the answer in the same group atomically with undo and redo',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final answerA = _selection(page: 2, label: 'A', group: 'q-9');
        final answerB = _selection(page: 2, label: 'B', group: 'q-9');

        studio.toggleSmartPenAnswer(answerA, _pageSize);
        studio.toggleSmartPenAnswer(answerB, _pageSize);
        expect(_ovals(studio, 2), hasLength(1));
        expect(_ovals(studio, 2).single.smartPenLabel, 'B');

        studio.undo();
        expect(_ovals(studio, 2), hasLength(1));
        expect(_ovals(studio, 2).single.smartPenLabel, 'A');
        studio.redo();
        expect(_ovals(studio, 2), hasLength(1));
        expect(_ovals(studio, 2).single.smartPenLabel, 'B');
      },
    );

    test('keeps different groups and pages independent', () {
      final studio = StudioState();
      addTearDown(studio.dispose);

      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-left'),
        _pageSize,
      );
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-right'),
        _pageSize,
      );
      studio.toggleSmartPenAnswer(
        _selection(page: 2, label: 'C', group: 'q-left'),
        _pageSize,
      );
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'D', group: 'q-left'),
        _pageSize,
      );

      expect(_ovals(studio, 1), hasLength(2));
      expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), [
        'B',
        'D',
      ]);
      expect(_ovals(studio, 2), hasLength(1));
      expect(_ovals(studio, 2).single.smartPenLabel, 'C');
    });

    test('one PDF selection undo leaves prior board handwriting untouched', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.addStroke(
        BoardStroke(const Color(0xff123456), 2, [const Offset(0.2, 0.3)]),
      );
      studio.toggleSmartPenAnswer(
        _selection(page: 4, label: 'D', group: 'q-30'),
        _pageSize,
      );

      studio.undo();

      expect(_ovals(studio, 4), isEmpty);
      expect(studio.strokes, hasLength(1));
      expect(studio.strokes.single.points, [const Offset(0.2, 0.3)]);
    });

    test('shared undo and redo follow the latest PDF or board action', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-order'),
        _pageSize,
      );
      final boardStroke = BoardStroke(const Color(0xff123456), 2, const [
        Offset(0.2, 0.3),
      ]);
      studio.addStroke(boardStroke);

      studio.undo();

      expect(studio.strokes, isEmpty);
      expect(_ovals(studio, 1), hasLength(1));
      studio.redo();
      expect(studio.strokes, hasLength(1));
      expect(_ovals(studio, 1), hasLength(1));
    });

    test('clearing a PDF page invalidates its Smart Pen history', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-clear'),
        _pageSize,
      );
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-clear'),
        _pageSize,
      );
      studio.setPdfPage(1);

      studio.clearPdfPage();
      studio.undo();

      expect(_ovals(studio, 1), isEmpty);
      expect(studio.canRedo, isFalse);
    });

    test('new PDF ink invalidates answer redo from any page in the document', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-redo-branch'),
        _pageSize,
      );
      studio.undo();
      expect(studio.canRedo, isTrue);

      studio.setPdfPage(2);
      studio.addStroke(
        BoardStroke(const Color(0xff123456), 2, const [Offset(0.1, 0.2)]),
        target: studio.pdfAnnotations.putIfAbsent(2, () => <BoardStroke>[]),
      );
      studio.redo();

      expect(_ovals(studio, 1), isEmpty);
      expect(studio.canRedo, isFalse);
    });

    test('new PDF ink invalidates the current board redo branch', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.addStroke(
        BoardStroke(const Color(0xff123456), 2, const [Offset(0.1, 0.2)]),
      );
      studio.undo();
      expect(studio.canRedo, isTrue);

      studio.addStroke(
        BoardStroke(const Color(0xff654321), 2, const [Offset(0.3, 0.4)]),
        target: studio.pdfAnnotations.putIfAbsent(1, () => <BoardStroke>[]),
      );
      studio.redo();

      expect(studio.strokes, isEmpty);
      expect(studio.canRedo, isFalse);
    });

    test('replacing the PDF invalidates undo and redo from its previous bytes', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-old-pdf'),
        _pageSize,
      );
      studio.undo();
      expect(studio.canRedo, isTrue);

      // Reuse the same path/name to exercise ImportedDocument ID reuse.
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([4, 5, 6]));
      studio.undo();
      studio.redo();

      expect(_ovals(studio, 1), isEmpty);
      expect(studio.canUndo, isFalse);
      expect(studio.canRedo, isFalse);
    });
  });

  testWidgets('renders the oval reveal to its final persisted geometry', (
    tester,
  ) async {
    final studio = StudioState();
    addTearDown(studio.dispose);
    final oval = SmartPenOvalAnnotation.fromSelection(
      selection: _selection(page: 1, label: 'A', group: 'q-animation'),
      pageSize: _pageSize,
      color: const Color(0xffed6a5a),
      width: 3.5,
      seed: 77,
    ).toBoardStroke();
    final annotations = <BoardStroke>[oval];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StrokeCanvas(
            studio: studio,
            targetStrokes: annotations,
            interactive: false,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<SmartPenOvalPainter>()
        .single;
    expect(painter.progress, 1);
    expect(oval.points, annotations.single.points);
  });

  test('exports Smart Pen ovals and existing freehand PDF ink', () async {
    final source = sf.PdfDocument();
    source.pages.add();
    final sourceBytes = source.saveSync();
    source.dispose();

    final studio = StudioState()..pdfBytes = Uint8List.fromList(sourceBytes);
    addTearDown(studio.dispose);
    final oval = SmartPenOvalAnnotation.fromSelection(
      selection: _selection(page: 1, label: 'D', group: 'q-export'),
      pageSize: _pageSize,
      color: const Color(0xffed6a5a),
      width: 3.5,
      seed: 81,
    ).toBoardStroke();
    studio.pdfAnnotations[1] = [
      oval,
      BoardStroke(const Color(0xff336699), 2, const [
        Offset(0.1, 0.2),
        Offset(0.3, 0.4),
      ]),
    ];

    final exported = await PdfAnnotationExporter.exportHighlightedPdfBytes(
      studio,
    );

    expect(exported, isNotNull);
    expect(exported!.length, greaterThan(sourceBytes.length));
    final exportedDocument = sf.PdfDocument(inputBytes: exported);
    expect(exportedDocument.pages.count, 1);
    exportedDocument.dispose();
  });

  test('maps displayed normalized points back for PDF page rotation', () {
    const displayed = Offset(0.2, 0.35);
    expect(
      PdfAnnotationExporter.displayedNormalizedToPdfNormalized(
        displayed,
        sf.PdfPageRotateAngle.rotateAngle0,
      ),
      displayed,
    );
    expect(
      PdfAnnotationExporter.displayedNormalizedToPdfNormalized(
        displayed,
        sf.PdfPageRotateAngle.rotateAngle90,
      ),
      const Offset(0.35, 0.8),
    );
    expect(
      PdfAnnotationExporter.displayedNormalizedToPdfNormalized(
        displayed,
        sf.PdfPageRotateAngle.rotateAngle180,
      ),
      const Offset(0.8, 0.65),
    );
    expect(
      PdfAnnotationExporter.displayedNormalizedToPdfNormalized(
        displayed,
        sf.PdfPageRotateAngle.rotateAngle270,
      ),
      const Offset(0.65, 0.2),
    );
  });

  test('exports ink while preserving a rotated source page', () async {
    final source = sf.PdfDocument();
    source.pageSettings.rotate = sf.PdfPageRotateAngle.rotateAngle90;
    source.pages.add();
    final sourceBytes = source.saveSync();
    source.dispose();

    final studio = StudioState()..pdfBytes = Uint8List.fromList(sourceBytes);
    addTearDown(studio.dispose);
    final oval = SmartPenOvalAnnotation.fromSelection(
      selection: _selection(page: 1, label: 'A', group: 'q-rotated'),
      pageSize: const Size(792, 612),
      color: const Color(0xffed6a5a),
      width: 3,
      seed: 19,
    ).toBoardStroke();
    studio.pdfAnnotations[1] = [oval];

    final exported = await PdfAnnotationExporter.exportHighlightedPdfBytes(
      studio,
    );
    expect(exported, isNotNull);
    final exportedDocument = sf.PdfDocument(inputBytes: exported!);
    expect(
      exportedDocument.pages[0].rotation,
      sf.PdfPageRotateAngle.rotateAngle90,
    );
    exportedDocument.dispose();
  });
}

SmartPenAnswerSelection _selection({
  required int page,
  required String label,
  required String group,
  Rect bounds = const Rect.fromLTWH(120, 240, 18, 20),
}) => SmartPenAnswerSelection(
  pageNumber: page,
  label: label,
  bounds: bounds,
  groupId: group,
);

List<BoardStroke> _ovals(StudioState studio, int page) =>
    (studio.pdfAnnotations[page] ?? const <BoardStroke>[])
        .where((stroke) => stroke.isSmartPenOval)
        .toList();
