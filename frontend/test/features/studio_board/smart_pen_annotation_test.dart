import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/services/pdf_annotation_exporter.dart';
import 'package:teaching_companion/features/studio_board/presentation/stroke_canvas.dart';
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

    test('legacy lesson restore defaults answer-circle saving to enabled', () {
      final restored = StudioState()..setSaveAnswerCirclesEnabled(false);
      addTearDown(restored.dispose);
      final legacyOval = SmartPenOvalAnnotation.fromSelection(
        selection: _selection(page: 1, label: 'B', group: 'legacy-q'),
        pageSize: _pageSize,
        color: Colors.red,
        width: 3,
      ).toBoardStroke();

      restored.restoreFromJson({
        'pdfAnnotations': {
          '1': [legacyOval.toJson()],
        },
      });

      expect(restored.saveAnswerCirclesEnabled, isTrue);
      expect(_ovals(restored, 1).single.toJson(), legacyOval.toJson());
    });
  });

  group('Smart Pen PDF answer selection history', () {
    test(
      'save-answer setting defaults on and is independent from Smart Snap',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);

        expect(studio.saveAnswerCirclesEnabled, isTrue);
        expect(studio.smartSnapEnabled, isFalse);

        studio.setSmartSnapEnabled(true);
        studio.setSaveAnswerCirclesEnabled(false);
        expect(studio.smartSnapEnabled, isTrue);
        expect(studio.saveAnswerCirclesEnabled, isFalse);

        studio.setSmartSnapEnabled(false);
        studio.setSaveAnswerCirclesEnabled(true);
        expect(studio.smartSnapEnabled, isFalse);
        expect(studio.saveAnswerCirclesEnabled, isTrue);
      },
    );

    test('changing save setting alone leaves saved circles unchanged', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final saved = SmartPenOvalAnnotation.fromSelection(
        selection: _selection(page: 1, label: 'A', group: 'q-toggle-only'),
        pageSize: _pageSize,
        color: Colors.red,
        width: 3,
      ).toBoardStroke();
      studio.pdfAnnotations[1] = [saved];
      final before = studio.exportLessonJson();

      studio.setSaveAnswerCirclesEnabled(false);
      studio.setSaveAnswerCirclesEnabled(true);

      expect(studio.pdfAnnotations[1]!.single.toJson(), saved.toJson());
      expect(studio.exportLessonJson(), before);
      expect(studio.dirty, isFalse);
    });

    test('save-on selection persists and marks a clean lesson dirty', () {
      final studio = StudioState();
      addTearDown(studio.dispose);

      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-save-on'),
        _pageSize,
      );

      expect(_ovals(studio, 1), hasLength(1));
      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
      expect(studio.dirty, isTrue);
    });

    test(
      'save-off selection is session-only, undoable, and keeps clean state clean',
      () {
        final studio = StudioState()..setSaveAnswerCirclesEnabled(false);
        addTearDown(studio.dispose);
        final selection = _selection(page: 1, label: 'B', group: 'q-save-off');

        studio.toggleSmartPenAnswer(selection, _pageSize);

        expect(_ovals(studio, 1), isEmpty);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(studio.dirty, isFalse);
        expect(studio.canUndo, isTrue);
        final savedJson = studio.exportLessonJson();

        studio.undo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(studio.dirty, isFalse);
        studio.redo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(studio.exportLessonJson(), savedJson);
        expect(studio.dirty, isFalse);
      },
    );

    test('save-off edits preserve an already dirty lesson', () {
      final studio = StudioState()..setSaveAnswerCirclesEnabled(false);
      addTearDown(studio.dispose);
      studio.dirty = true;

      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-already-dirty'),
        _pageSize,
      );

      expect(studio.dirty, isTrue);
      studio.undo();
      expect(studio.dirty, isTrue);
      studio.redo();
      expect(studio.dirty, isTrue);
    });

    test('save-off then save-on keeps prior temporary circles temporary', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.setSaveAnswerCirclesEnabled(false);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-before-toggle'),
        _pageSize,
      );

      studio.setSaveAnswerCirclesEnabled(true);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-after-toggle'),
        _pageSize,
      );

      expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['B']);
      expect(
        _ovalsIn(
          studio.pdfAnnotationsForPage(1),
        ).map((stroke) => stroke.smartPenLabel).toSet(),
        {'A', 'B'},
      );
      expect(studio.dirty, isTrue);
    });

    test(
      'save-on tap toggles off the same answer created while saving was off',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final selection = _selection(
          page: 1,
          label: 'A',
          group: 'q-mode-switch-same',
        );
        studio.setSaveAnswerCirclesEnabled(false);
        studio.toggleSmartPenAnswer(selection, _pageSize);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(_ovals(studio, 1), isEmpty);

        studio.setSaveAnswerCirclesEnabled(true);
        studio.toggleSmartPenAnswer(selection, _pageSize);

        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(_ovals(studio, 1), isEmpty);
        expect(studio.pdfAnnotations, isEmpty);
        expect(studio.dirty, isFalse);
        studio.undo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(_ovals(studio, 1), isEmpty);
        studio.redo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
      },
    );

    test(
      'save-on replacement of a temporary answer persists only the new label',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final answerA = _selection(
          page: 1,
          label: 'A',
          group: 'q-mode-switch-replace',
        );
        final answerB = _selection(
          page: 1,
          label: 'B',
          group: 'q-mode-switch-replace',
        );
        studio.setSaveAnswerCirclesEnabled(false);
        studio.toggleSmartPenAnswer(answerA, _pageSize);
        studio.setSaveAnswerCirclesEnabled(true);

        studio.toggleSmartPenAnswer(answerB, _pageSize);

        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['B']);
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(1),
          ).map((stroke) => stroke.smartPenLabel),
          ['B'],
        );
        expect(
          studio.pdfAnnotations[1]?.map((stroke) => stroke.smartPenLabel),
          ['B'],
        );
        studio.undo();
        expect(_ovals(studio, 1), isEmpty);
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(1),
          ).map((stroke) => stroke.smartPenLabel),
          ['A'],
        );
        studio.redo();
        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['B']);
        expect(_ovals(studio, 1), hasLength(1));
      },
    );

    test('save-on can reselect a saved label hidden by a temporary answer', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      const groupId = 'q-mode-switch-reselect-saved';
      studio.pdfAnnotations[1] = [
        SmartPenOvalAnnotation.fromSelection(
          selection: _selection(page: 1, label: 'A', group: groupId),
          pageSize: _pageSize,
          color: Colors.red,
          width: 3,
        ).toBoardStroke(),
      ];

      studio.setSaveAnswerCirclesEnabled(false);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'D', group: groupId),
        _pageSize,
      );
      expect(
        _ovalsIn(
          studio.pdfAnnotationsForPage(1),
        ).map((stroke) => stroke.smartPenLabel),
        ['D'],
      );

      studio.setSaveAnswerCirclesEnabled(true);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: groupId),
        _pageSize,
      );

      expect(
        _ovalsIn(
          studio.pdfAnnotationsForPage(1),
        ).map((stroke) => stroke.smartPenLabel),
        ['A'],
      );
      expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['A']);
      studio.undo();
      expect(
        _ovalsIn(
          studio.pdfAnnotationsForPage(1),
        ).map((stroke) => stroke.smartPenLabel),
        ['D'],
      );
      expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['A']);
    });

    test(
      'undo and redo atomically restore saved and temporary group state',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final a = _selection(page: 1, label: 'A', group: 'q-cross-lane');
        final b = _selection(page: 1, label: 'B', group: 'q-cross-lane');
        final c = _selection(page: 1, label: 'C', group: 'q-cross-lane');

        studio.toggleSmartPenAnswer(a, _pageSize);
        studio.setSaveAnswerCirclesEnabled(false);
        studio.toggleSmartPenAnswer(b, _pageSize);
        studio.setSaveAnswerCirclesEnabled(true);
        studio.toggleSmartPenAnswer(c, _pageSize);

        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['C']);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).map((s) => s.smartPenLabel),
          ['C'],
        );

        studio.undo();
        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['A']);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).map((s) => s.smartPenLabel),
          ['B'],
        );

        studio.redo();
        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['C']);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).map((s) => s.smartPenLabel),
          ['C'],
        );
      },
    );

    test(
      'save-off tap suppresses and restores saved answer without persistence changes',
      () {
        final studio = StudioState()..setSaveAnswerCirclesEnabled(false);
        addTearDown(studio.dispose);
        final saved = SmartPenOvalAnnotation.fromSelection(
          selection: _selection(
            page: 1,
            label: 'A',
            group: 'q-suppress-toggle',
          ),
          pageSize: _pageSize,
          color: Colors.red,
          width: 3,
        ).toBoardStroke();
        studio.pdfAnnotations[1] = [saved];
        final savedJson = studio.exportLessonJson();
        final selection = _selection(
          page: 1,
          label: 'A',
          group: 'q-suppress-toggle',
        );

        studio.toggleSmartPenAnswer(selection, _pageSize);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(studio.pdfAnnotations[1]!.single.toJson(), saved.toJson());
        studio.undo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        studio.redo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        studio.toggleSmartPenAnswer(selection, _pageSize);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(studio.exportLessonJson(), savedJson);
        expect(studio.pdfAnnotations[1]!.single.toJson(), saved.toJson());
      },
    );

    test('adds an oval and undo/redo each apply as a single action', () {
      final studio = StudioState()
        ..ink = Colors.blue
        ..strokeWidth = 3.5;
      addTearDown(studio.dispose);
      final selection = _selection(page: 1, label: 'C', group: 'q-7');

      studio.toggleSmartPenAnswer(selection, _pageSize);
      expect(_ovals(studio, 1), hasLength(1));
      expect(_ovals(studio, 1).single.smartPenLabel, 'C');
      expect(_ovals(studio, 1).single.color, Colors.red);

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

    test(
      'replaces and toggles an answer across pages as single undoable actions',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final pageOneA = _selection(page: 1, label: 'A', group: 'q-linked');
        final pageOneD = _selection(page: 1, label: 'D', group: 'q-linked');
        final pageTwoD = _selection(page: 2, label: 'D', group: 'q-linked');

        studio.toggleSmartPenAnswer(pageOneA, _pageSize, affectedPages: [1, 2]);
        studio.toggleSmartPenAnswer(pageTwoD, _pageSize, affectedPages: [1, 2]);

        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);

        studio.undo();
        expect(_ovals(studio, 1).map((stroke) => stroke.smartPenLabel), ['A']);
        expect(_ovals(studio, 2), isEmpty);

        studio.redo();
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);

        studio.toggleSmartPenAnswer(pageOneD, _pageSize, affectedPages: [1, 2]);
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2), isEmpty);
        studio.undo();
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);
        studio.redo();
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2), isEmpty);
      },
    );

    test(
      'cross-page replacement restores temporary answer lanes atomically',
      () {
        final studio = StudioState()..setSaveAnswerCirclesEnabled(false);
        addTearDown(studio.dispose);
        final pageOneA = _selection(
          page: 1,
          label: 'A',
          group: 'q-temp-linked',
        );
        final pageTwoD = _selection(
          page: 2,
          label: 'D',
          group: 'q-temp-linked',
        );

        studio.toggleSmartPenAnswer(pageOneA, _pageSize, affectedPages: [1, 2]);
        studio.toggleSmartPenAnswer(pageTwoD, _pageSize, affectedPages: [1, 2]);

        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2), isEmpty);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(2),
          ).map((stroke) => stroke.smartPenLabel),
          ['D'],
        );

        studio.undo();
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(1),
          ).map((stroke) => stroke.smartPenLabel),
          ['A'],
        );
        expect(_ovalsIn(studio.pdfAnnotationsForPage(2)), isEmpty);

        studio.redo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(2),
          ).map((stroke) => stroke.smartPenLabel),
          ['D'],
        );
      },
    );

    test(
      'migrates a pre-index answer to the canonical group without duplicating it',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        const provisionalId = 'partial-g7-p1-0';
        const canonicalId = 'answer-g7-p1-1-p2-2';
        final original = _selection(page: 1, label: 'A', group: provisionalId);
        studio.toggleSmartPenAnswer(original, _pageSize);

        studio.migrateSmartPenAnswerGroup(
          provisionalId,
          canonicalId,
          affectedPages: [1, 2],
        );
        final migrated = _ovals(studio, 1).single;
        expect(migrated.smartPenGroupId, canonicalId);
        expect(studio.smartPenAnswerSelection?.groupId, canonicalId);
        expect(_ovals(studio, 2), isEmpty);

        studio.toggleSmartPenAnswer(
          _selection(page: 2, label: 'D', group: canonicalId),
          _pageSize,
          affectedPages: [1, 2],
        );
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);

        studio.undo();
        expect(_ovals(studio, 1), hasLength(1));
        expect(_ovals(studio, 1).single.smartPenLabel, 'A');
        expect(_ovals(studio, 2), isEmpty);
        studio.redo();
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);
      },
    );

    test(
      'keeps the latest pre-index answer when separate page groups link',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        const firstProvisional = 'partial-g7-p1-0';
        const secondProvisional = 'partial-g7-p2-0';
        const canonicalId = 'answer-g7-p1-1-p2-2';
        studio.toggleSmartPenAnswer(
          _selection(page: 1, label: 'A', group: firstProvisional),
          _pageSize,
        );
        studio.toggleSmartPenAnswer(
          _selection(page: 2, label: 'D', group: secondProvisional),
          _pageSize,
        );

        studio.migrateSmartPenAnswerGroup(
          firstProvisional,
          canonicalId,
          affectedPages: [1, 2],
        );
        studio.migrateSmartPenAnswerGroup(
          secondProvisional,
          canonicalId,
          affectedPages: [1, 2],
        );

        final visible = [
          ...studio.pdfAnnotationsForPage(1),
          ...studio.pdfAnnotationsForPage(2),
        ].where((stroke) => stroke.isSmartPenOval).toList();
        expect(visible, hasLength(1));
        expect(visible.single.smartPenGroupId, canonicalId);
        expect(visible.single.smartPenLabel, 'D');
        expect(studio.smartPenAnswerSelection?.groupId, canonicalId);
        expect(studio.smartPenAnswerSelection?.label, 'D');
      },
    );

    test(
      'latest saved pre-index answer replaces an earlier temporary circle',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        const firstProvisional = 'partial-g8-p1-0';
        const secondProvisional = 'partial-g8-p2-0';
        const canonicalId = 'answer-g8-p1-1-p2-2';
        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'A', group: firstProvisional),
          _pageSize,
        );
        studio.toggleSmartPenAnswer(
          _selection(page: 2, label: 'D', group: secondProvisional),
          _pageSize,
        );

        studio.migrateSmartPenAnswerGroup(
          firstProvisional,
          canonicalId,
          affectedPages: [1, 2],
        );
        studio.migrateSmartPenAnswerGroup(
          secondProvisional,
          canonicalId,
          affectedPages: [1, 2],
        );

        final visible = [
          ...studio.pdfAnnotationsForPage(1),
          ...studio.pdfAnnotationsForPage(2),
        ].where((stroke) => stroke.isSmartPenOval).toList();
        expect(visible, hasLength(1));
        expect(visible.single.smartPenGroupId, canonicalId);
        expect(visible.single.smartPenLabel, 'D');
        expect(_ovals(studio, 1), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);

        studio.undo();
        expect(
          _ovalsIn(
            studio.pdfAnnotationsForPage(1),
          ).map((stroke) => stroke.smartPenLabel),
          ['A'],
        );
        expect(_ovalsIn(studio.pdfAnnotationsForPage(2)), isEmpty);
        studio.redo();
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
        expect(_ovals(studio, 2).map((stroke) => stroke.smartPenLabel), ['D']);
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

    test(
      'new PDF ink invalidates answer redo from any page in the document',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        studio.setSaveAnswerCirclesEnabled(false);
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
      },
    );

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

    test(
      'replacing the PDF invalidates undo and redo from its previous bytes',
      () {
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
      },
    );
  });

  group('Smart Pen session-only answer annotations', () {
    test('saved circles survive closing and reopening the same PDF', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final sourceBytes = Uint8List.fromList([1, 2, 3]);
      studio.setPdfFile(r'C:\old\quiz.pdf', sourceBytes);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-close-reopen'),
        _pageSize,
      );

      studio.setPdfFile(null, null);
      expect(studio.pdfAnnotations, isEmpty);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));

      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'A',
      );
    });

    test('reimporting the active PDF keeps unsnapshotted saved circles', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final sourceBytes = Uint8List.fromList([1, 2, 3]);
      studio.setPdfFile('quiz.pdf', sourceBytes);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-active-reimport'),
        _pageSize,
      );

      studio.addImportedDoc(
        'quiz.pdf',
        r'D:\new\quiz.pdf',
        Uint8List.fromList([1, 2, 3]),
      );

      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'B',
      );
    });

    test('replacing active PDF content clears temporary circles and history', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));
      studio.setSaveAnswerCirclesEnabled(false);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-active-replacement'),
        _pageSize,
      );
      expect(studio.canUndo, isTrue);

      studio.addImportedDoc(
        'quiz.pdf',
        'quiz.pdf',
        Uint8List.fromList([4, 5, 6]),
      );

      expect(studio.pdfAnnotationsForPage(1), isEmpty);
      expect(studio.canUndo, isFalse);
    });

    test('saved circles survive close after an in-place PDF export', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-in-place-export'),
        _pageSize,
      );
      final exportedBytes = Uint8List.fromList([4, 5, 6]);
      studio.updatePdfBytesInPlace(exportedBytes);

      studio.setPdfFile(null, null);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([4, 5, 6]));

      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'C',
      );
    });

    test(
      'lesson save while PDF is closed restores saved circles on reimport',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final sourceBytes = Uint8List.fromList([1, 2, 3]);
        studio.setPdfFile('quiz.pdf', sourceBytes);
        studio.toggleSmartPenAnswer(
          _selection(page: 1, label: 'D', group: 'q-closed-lesson-save'),
          _pageSize,
        );
        studio.setPdfFile(null, null);

        final savedLesson = studio.exportLessonJson();
        final restored = StudioState()..restoreFromJson(savedLesson);
        addTearDown(restored.dispose);
        expect(restored.pdfAnnotations, isEmpty);
        restored.setPdfFile('stale.pdf', Uint8List.fromList([9, 9, 9]));
        restored.restoreFromJson(savedLesson);
        expect(restored.pdfFilePath, isNull);
        expect(restored.pdfBytes, isNull);

        restored.addImportedDoc(
          'quiz.pdf',
          r'D:\new\quiz.pdf',
          Uint8List.fromList([1, 2, 3]),
        );

        expect(
          _ovalsIn(restored.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'D',
        );

        final replacement = StudioState()..restoreFromJson(savedLesson);
        addTearDown(replacement.dispose);
        replacement.addImportedDoc(
          'quiz.pdf',
          r'D:\different\quiz.pdf',
          Uint8List.fromList([9, 8, 7]),
        );
        expect(replacement.pdfAnnotationsForPage(1), isEmpty);
      },
    );

    test('closing PDF discards temporary circle but keeps saved answer', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final sourceBytes = Uint8List.fromList([1, 2, 3]);
      studio.setPdfFile('quiz.pdf', sourceBytes);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-save-mode-close'),
        _pageSize,
      );
      studio.setSaveAnswerCirclesEnabled(false);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-save-mode-close'),
        _pageSize,
      );
      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'B',
      );

      studio.setPdfFile(null, null);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));

      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'A',
      );
    });

    test(
      'temporary circles are visible but excluded from persisted annotations',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final selection = _selection(page: 1, label: 'C', group: 'q-temporary');

        studio.toggleTemporarySmartPenAnswer(selection, _pageSize);

        expect(_ovals(studio, 1), isEmpty);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'C',
        );
      },
    );

    test(
      'temporary-only circles do not enter saved lesson JSON or restore',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        studio.setSaveAnswerCirclesEnabled(false);
        studio.toggleSmartPenAnswer(
          _selection(page: 1, label: 'C', group: 'q-json-temporary'),
          _pageSize,
        );

        final lesson = studio.exportLessonJson();
        expect(lesson['pdfAnnotations'], isEmpty);

        final restored = StudioState()..restoreFromJson(lesson);
        addTearDown(restored.dispose);
        expect(restored.pdfAnnotations, isEmpty);
        expect(restored.pdfAnnotationsForPage(1), isEmpty);
      },
    );

    test('restoring a lesson without a PDF clears prior session overrides', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-prior-session'),
        _pageSize,
      );

      studio.restoreFromJson({'title': 'Another lesson'});

      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
      expect(studio.canUndo, isFalse);
    });

    test(
      'temporary answer shadows saved group without mutating its circle',
      () {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final saved = SmartPenOvalAnnotation.fromSelection(
          selection: _selection(page: 1, label: 'A', group: 'q-shadow'),
          pageSize: _pageSize,
          color: const Color(0xffaabbcc),
          width: 2.5,
          seed: 41,
        ).toBoardStroke();
        studio.pdfAnnotations[1] = [saved];
        final savedJson = saved.toJson();

        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'D', group: 'q-shadow'),
          _pageSize,
        );

        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'D',
        );
        expect(studio.pdfAnnotations[1]!.single.toJson(), savedJson);

        studio.clearTemporarySmartPenAnswer(1, 'q-shadow');

        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.toJson(),
          savedJson,
        );
        expect(studio.pdfAnnotations[1]!.single.toJson(), savedJson);
      },
    );

    test('temporary suppression hides saved circle only in the live view', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      final saved = SmartPenOvalAnnotation.fromSelection(
        selection: _selection(page: 2, label: 'B', group: 'q-suppress'),
        pageSize: _pageSize,
        color: const Color(0xff123456),
        width: 3,
        seed: 51,
      ).toBoardStroke();
      studio.pdfAnnotations[2] = [saved];
      final savedJson = saved.toJson();

      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 2, label: 'B', group: 'q-suppress'),
        _pageSize,
      );

      expect(_ovalsIn(studio.pdfAnnotationsForPage(2)), isEmpty);
      expect(studio.pdfAnnotations[2]!.single.toJson(), savedJson);

      studio.clearTemporarySmartPenAnswer(2, 'q-suppress');

      expect(_ovalsIn(studio.pdfAnnotationsForPage(2)), hasLength(1));
      expect(studio.pdfAnnotations[2]!.single.toJson(), savedJson);
    });

    test(
      'temporary overrides are isolated by page and imported document',
      () async {
        final studio = StudioState();
        addTearDown(studio.dispose);
        final firstBytes = Uint8List.fromList([1, 2, 3]);
        final secondBytes = Uint8List.fromList([4, 5, 6]);
        studio.addImportedDoc('first.pdf', null, firstBytes);
        final firstId = studio.activeDoc!.id;
        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'A', group: 'q-shared'),
          _pageSize,
        );

        expect(_ovalsIn(studio.pdfAnnotationsForPage(2)), isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 2));
        studio.addImportedDoc('second.pdf', null, secondBytes);
        final secondId = studio.activeDoc!.id;
        expect(secondId, isNot(firstId));
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);

        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'D', group: 'q-shared'),
          _pageSize,
        );
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'D',
        );

        studio.selectDoc(firstId);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'A',
        );
        studio.selectDoc(secondId);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'D',
        );
      },
    );

    test('temporary annotations clear when their document is removed', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.addImportedDoc('first.pdf', null, Uint8List.fromList([1]));
      final firstId = studio.activeDoc!.id;
      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 1, label: 'C', group: 'q-removed'),
        _pageSize,
      );
      studio.addImportedDoc('second.pdf', null, Uint8List.fromList([2]));

      studio.removeDoc(firstId);
      expect(studio.canUndo, isFalse);
      expect(studio.canRedo, isFalse);
      studio.addImportedDoc('first.pdf', null, Uint8List.fromList([3]));

      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
    });

    test(
      'document snapshots copy saved ink, never temporary overrides',
      () async {
        final studio = StudioState();
        addTearDown(studio.dispose);
        studio.addImportedDoc('first.pdf', null, Uint8List.fromList([1]));
        final firstId = studio.activeDoc!.id;
        final saved = SmartPenOvalAnnotation.fromSelection(
          selection: _selection(page: 1, label: 'A', group: 'q-doc-snapshot'),
          pageSize: _pageSize,
          color: Colors.red,
          width: 3,
        ).toBoardStroke();
        studio.pdfAnnotations[1] = [
          saved,
          BoardStroke(Colors.blue, 2, const [
            Offset(0.1, 0.2),
            Offset(0.2, 0.3),
          ]),
        ];
        studio.setSaveAnswerCirclesEnabled(false);
        studio.toggleSmartPenAnswer(
          _selection(page: 1, label: 'D', group: 'q-doc-snapshot'),
          _pageSize,
        );

        await Future<void>.delayed(const Duration(milliseconds: 2));
        studio.addImportedDoc('second.pdf', null, Uint8List.fromList([2]));

        expect(
          studio.importedDocs
              .firstWhere((doc) => doc.id == firstId)
              .annotations[1],
          hasLength(2),
        );
        expect(
          studio.importedDocs
              .firstWhere((doc) => doc.id == firstId)
              .annotations[1]!
              .where((stroke) => stroke.isSmartPenOval)
              .single
              .smartPenLabel,
          'A',
        );
        studio.selectDoc(firstId);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'D',
        );
      },
    );

    test('temporary annotations clear when the source PDF is replaced', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.setPdfFile('quiz.pdf', Uint8List.fromList([1, 2, 3]));
      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-replaced'),
        _pageSize,
      );
      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), hasLength(1));

      studio.setPdfFile('quiz.pdf', Uint8List.fromList([4, 5, 6]));

      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
    });

    test(
      'replacing one PDF preserves other loaded documents temporary state',
      () async {
        final studio = StudioState();
        addTearDown(studio.dispose);
        studio.addImportedDoc('first.pdf', null, Uint8List.fromList([1]));
        final firstId = studio.activeDoc!.id;
        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'A', group: 'q-first'),
          _pageSize,
        );
        await Future<void>.delayed(const Duration(milliseconds: 2));
        studio.addImportedDoc('second.pdf', null, Uint8List.fromList([2]));
        final secondId = studio.activeDoc!.id;
        expect(secondId, isNot(firstId));
        studio.toggleTemporarySmartPenAnswer(
          _selection(page: 1, label: 'B', group: 'q-second'),
          _pageSize,
        );

        studio.setPdfFile('replacement.pdf', Uint8List.fromList([3]));

        studio.selectDoc(firstId);
        expect(
          _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
          'A',
        );
        studio.selectDoc(secondId);
        expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
      },
    );

    test('replacing the active PDF clears only its undo history', () async {
      final studio = StudioState();
      addTearDown(studio.dispose);
      studio.addImportedDoc('first.pdf', null, Uint8List.fromList([1]));
      final firstId = studio.activeDoc!.id;
      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 1, label: 'A', group: 'q-first-history'),
        _pageSize,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      studio.addImportedDoc('second.pdf', null, Uint8List.fromList([2]));
      studio.toggleTemporarySmartPenAnswer(
        _selection(page: 1, label: 'B', group: 'q-second-history'),
        _pageSize,
      );

      studio.setPdfFile('replacement.pdf', Uint8List.fromList([3]));
      studio.selectDoc(firstId);

      expect(studio.canUndo, isTrue);
      studio.undo();
      expect(_ovalsIn(studio.pdfAnnotationsForPage(1)), isEmpty);
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

  test('PDF export ignores temporary-only answer circles', () async {
    final source = sf.PdfDocument();
    source.pages.add();
    final sourceBytes = source.saveSync();
    source.dispose();

    final studio = StudioState()..pdfBytes = Uint8List.fromList(sourceBytes);
    addTearDown(studio.dispose);
    final baseline = await PdfAnnotationExporter.exportHighlightedPdfBytes(
      studio,
    );
    studio.setSaveAnswerCirclesEnabled(false);
    studio.toggleSmartPenAnswer(
      _selection(page: 1, label: 'B', group: 'q-export-temporary'),
      _pageSize,
    );

    final exported = await PdfAnnotationExporter.exportHighlightedPdfBytes(
      studio,
    );

    expect(exported, isNotNull);
    expect(exported!.length, baseline!.length);
    expect(studio.pdfAnnotations, isEmpty);
  });

  test(
    'mixed PDF export includes saved answer circle and freehand ink only',
    () async {
      final source = sf.PdfDocument();
      source.pages.add();
      final sourceBytes = source.saveSync();
      source.dispose();

      final studio = StudioState()..pdfBytes = Uint8List.fromList(sourceBytes);
      addTearDown(studio.dispose);
      final savedOval = SmartPenOvalAnnotation.fromSelection(
        selection: _selection(page: 1, label: 'A', group: 'q-mixed-export'),
        pageSize: _pageSize,
        color: Colors.red,
        width: 3,
      ).toBoardStroke();
      final freehand = BoardStroke(Colors.blue, 2, const [
        Offset(0.1, 0.2),
        Offset(0.3, 0.4),
      ]);
      studio.pdfAnnotations[1] = [savedOval, freehand];
      final persistedExport =
          await PdfAnnotationExporter.exportHighlightedPdfBytes(studio);
      studio.setSaveAnswerCirclesEnabled(false);
      studio.toggleSmartPenAnswer(
        _selection(page: 1, label: 'D', group: 'q-mixed-export'),
        _pageSize,
      );
      expect(
        _ovalsIn(studio.pdfAnnotationsForPage(1)).single.smartPenLabel,
        'D',
      );

      final exported = await PdfAnnotationExporter.exportHighlightedPdfBytes(
        studio,
      );

      expect(exported!.length, persistedExport!.length);
      expect(studio.pdfAnnotations[1], hasLength(2));
      expect(studio.pdfAnnotations[1]!.first.toJson(), savedOval.toJson());
      expect(studio.pdfAnnotations[1]!.last.toJson(), freehand.toJson());
    },
  );

  testWidgets('temporary-only ink does not enable PDF export action', (
    tester,
  ) async {
    final source = sf.PdfDocument();
    source.pages.add();
    final sourceBytes = source.saveSync();
    source.dispose();

    final studio = StudioState()..pdfBytes = Uint8List.fromList(sourceBytes);
    addTearDown(studio.dispose);
    studio.setSaveAnswerCirclesEnabled(false);
    studio.toggleSmartPenAnswer(
      _selection(page: 1, label: 'A', group: 'q-export-availability'),
      _pageSize,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => const SizedBox(key: Key('export-context')),
          ),
        ),
      ),
    );
    final context = tester.element(find.byKey(const Key('export-context')));

    final temporaryOnlyResult =
        await PdfAnnotationExporter.applyHighlightDirectlyToPdf(
          context,
          studio,
          showFeedback: false,
        );
    expect(temporaryOnlyResult, isFalse);
    expect(studio.pdfAnnotations, isEmpty);

    studio.setSaveAnswerCirclesEnabled(true);
    studio.toggleSmartPenAnswer(
      _selection(page: 1, label: 'B', group: 'q-export-availability'),
      _pageSize,
    );
    final persistedResult =
        await PdfAnnotationExporter.applyHighlightDirectlyToPdf(
          context,
          studio,
          showFeedback: false,
        );
    expect(persistedResult, isTrue);
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

List<BoardStroke> _ovalsIn(Iterable<BoardStroke> strokes) =>
    strokes.where((stroke) => stroke.isSmartPenOval).toList();

