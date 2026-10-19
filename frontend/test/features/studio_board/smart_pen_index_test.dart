import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:teaching_companion/features/studio_board/services/smart_pen_answer_index.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory pdfrxCacheDirectory;
  setUpAll(() {
    pdfrxCacheDirectory = Directory.systemTemp.createTempSync(
      'smart_pen_index_test_',
    );
    pdfrx.Pdfrx.cacheDirectoryPath = pdfrxCacheDirectory.path;
  });
  tearDownAll(() {
    pdfrxCacheDirectory.deleteSync(recursive: true);
    pdfrx.Pdfrx.cacheDirectoryPath = null;
  });

  group('Smart Pen answer candidate classification', () {
    test(
      'debug diagnostics are opt-in and explain isolated label rejection',
      () {
        final fragments = [
          _token('A.', 20, 20),
          _token('Isolated', 40, 20),
          _token('A', 300, 400),
        ];
        final classifier = SmartPenAnswerClassifier();

        final production = classifier.analyze(fragments);
        final debug = classifier.analyze(fragments, includeDebugData: true);

        expect(production.debugFragments, isEmpty);
        expect(debug.debugFragments, hasLength(3));
        expect(
          debug.debugFragments
              .singleWhere((item) => item.fragment.text == 'A')
              .decision,
          SmartPenDebugDecision.rejected,
        );
        expect(
          debug.debugFragments
              .singleWhere((item) => item.fragment.text == 'A')
              .reasonCode,
          'classifier_filter',
        );
        expect(
          debug.debugFragments
              .firstWhere((item) => item.fragment.text == 'Isolated')
              .decision,
          SmartPenDebugDecision.raw,
        );
      },
    );

    test('debug reason codes distinguish accepted and partial labels', () {
      final fragments = <SmartPenTextFragment>[
        for (var i = 0; i < 4; i++) ...[
          _token('${String.fromCharCode(65 + i)}.', 40, 100 + i * 24),
          _token('Option', 61, 100 + i * 24),
        ],
        _token('C.', 40, 736),
        _token('Penultimate option', 61, 736),
        _token('D.', 40, 760),
        _token('Final option', 61, 760),
        _token('A.', 300, 400),
        _token('Unrelated isolated label', 321, 400),
      ];

      final debug = SmartPenAnswerClassifier().analyze(
        fragments,
        pageSize: const Size(600, 800),
        pageNumber: 1,
        documentGeneration: 21,
        includeDebugData: true,
      );

      SmartPenDebugFragment diagnosticFor(String text, {double? minTop}) =>
          debug.debugFragments.singleWhere(
            (item) =>
                item.fragment.text == text &&
                (minTop == null || item.fragment.bounds.top >= minTop),
          );

      expect(diagnosticFor('B.').decision, SmartPenDebugDecision.accepted);
      expect(diagnosticFor('B.').reasonCode, 'candidate_accepted');
      expect(
        diagnosticFor('C.', minTop: 700).decision,
        SmartPenDebugDecision.partial,
      );
      expect(diagnosticFor('C.', minTop: 700).reasonCode, 'edge_partial');
      expect(
        diagnosticFor('Unrelated isolated label').decision,
        SmartPenDebugDecision.raw,
      );
      expect(
        debug.debugFragments
            .where((item) => item.fragment.text == 'Option')
            .every((item) => item.decision == SmartPenDebugDecision.raw),
        isTrue,
      );
    });

    test(
      'detects split-token and number-first headings near top-edge options',
      () {
        for (final heading in [
          [_token('Question', 40, 4), _token('21', 105, 4)],
          [_token('6.', 40, 4), _token('Câu', 58, 4), _token('văn', 88, 4)],
        ]) {
          final result = SmartPenAnswerClassifier().analyze(
            [
              ...heading,
              _token('C.', 40, 42),
              _token('Choice', 60, 42),
              _token('D.', 40, 72),
              _token('Choice', 60, 72),
            ],
            pageSize: const Size(600, 800),
            pageNumber: 2,
            documentGeneration: 4,
          );

          expect(result.partialGroups, hasLength(1));
          expect(
            result.partialGroups.single.hasQuestionHeadingEvidence,
            isTrue,
          );
        }
      },
    );

    final classifier = SmartPenAnswerClassifier();

    test('accepts labels only in nearby, aligned option groups', () {
      final candidates = classifier.classify(_verticalOptions());

      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(1),
      );
      expect(candidates.first.bounds, const Rect.fromLTWH(40, 100, 10, 12));
    });

    test('separates two-column groups by visual geometry', () {
      final candidates = classifier.classify(_twoColumnOptions());

      expect(candidates, hasLength(8));
      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
    });

    test('joins aligned A/C and B/D columns into one question group', () {
      final candidates = classifier.classify(_twoColumnQuestionOptions());

      expect(candidates, hasLength(4));
      expect(
        candidates.map((candidate) => candidate.label),
        unorderedEquals(['A', 'B', 'C', 'D']),
      );
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(1),
      );
    });

    test(
      'recognizes attached marker prefixes and keeps the hit box on the label',
      () {
        final fragments = <SmartPenTextFragment>[
          SmartPenTextFragment(
            text: 'A.Thất ngôn tứ tuyệt Đường luật',
            bounds: const Rect.fromLTWH(40, 100, 190, 12),
          ),
          SmartPenTextFragment(
            text: 'C.Song thất lục bát',
            bounds: const Rect.fromLTWH(40, 124, 118, 12),
          ),
        ];

        final candidates = classifier.classify(fragments);

        expect(candidates.map((candidate) => candidate.label), ['A', 'C']);
        expect(
          candidates.map((candidate) => candidate.groupId).toSet(),
          hasLength(1),
        );
        expect(candidates.first.bounds.width, lessThan(20));
        final index = _index(fragments);
        expect(
          index
              .hitTest(
                const Offset(44, 106),
                logicalPixelTolerance: 0,
                zoomScale: 1,
              )
              ?.label,
          'A',
        );
        expect(
          index.hitTest(
            const Offset(120, 106),
            logicalPixelTolerance: 0,
            zoomScale: 1,
          ),
          isNull,
        );
      },
    );

    test('caps attached marker hit boxes to a glyph-sized width', () {
      final fragments = [
        for (var i = 0; i < 4; i++)
          SmartPenTextFragment(
            text:
                '${String.fromCharCode(65 + i)}.${'long option content ' * 12}',
            bounds: Rect.fromLTWH(40, 100 + i * 24, 420, 12),
          ),
      ];

      final candidates = classifier.classify(fragments);
      expect(candidates, hasLength(4));
      expect(
        candidates.every((candidate) => candidate.bounds.width <= 18),
        isTrue,
      );
      final index = _index(fragments);
      expect(
        index.hitTest(
          const Offset(100, 106),
          logicalPixelTolerance: 0,
          zoomScale: 1,
        ),
        isNull,
      );
    });

    test(
      'associates widely separated formula fragments without merging columns',
      () {
        final fragments = <SmartPenTextFragment>[
          _token('44.', 20, 100),
          _token('Evaluate the following expressions:', 46, 100),
          for (final option in [
            ('A.', 40.0, 130.0, 'I = integral from 0 to π/4'),
            ('B.', 330.0, 130.0, 'I = 8 integral (1 + cos 2t)'),
            ('C.', 40.0, 166.0, 'I = 16 integral sin squared t'),
            ('D.', 330.0, 166.0, 'I = 8 integral (1 - cos 2t)'),
          ]) ...[
            _token(option.$1, option.$2, option.$3),
            SmartPenTextFragment(
              text: option.$4,
              bounds: Rect.fromLTWH(option.$2 + 62, option.$3, 150, 18),
            ),
          ],
          // A distant ordinary use of “A” is not an answer marker for this block.
          _token('Section', 40, 260),
          _token('A', 100, 260),
          _token('applies to the next chapter', 145, 260),
        ];

        final candidates = classifier.classify(fragments);

        expect(
          candidates.map((candidate) => candidate.label),
          unorderedEquals(['A', 'B', 'C', 'D']),
        );
        expect(
          candidates.map((candidate) => candidate.groupId).toSet(),
          hasLength(1),
        );
        expect(
          candidates.every((candidate) => candidate.bounds.width < 20),
          isTrue,
        );
      },
    );

    test('exposes a credible lone page-edge marker as a partial group', () {
      final index = SmartPenPageIndex.build(
        documentGeneration: 7,
        pageNumber: 2,
        pageSize: const Size(600, 800),
        fragments: [
          _token('C.', 40, 736),
          _token('Penultimate option', 61, 736),
          _token('D.', 40, 760),
          _token('Final formula option', 61, 760),
        ],
      );

      expect(index.candidates, isEmpty);
      expect(index.partialGroups, hasLength(1));
      expect(index.partialGroups.single.edge, SmartPenPageEdge.bottom);
      expect(
        index.partialGroups.single.candidates.map(
          (candidate) => candidate.label,
        ),
        ['C', 'D'],
      );
    });

    test('groups inline A-D choices by row across widely spaced columns', () {
      final fragments = <SmartPenTextFragment>[
        for (final y in [100.0, 140.0]) ...[
          _token('A.', 40, y),
          _token('First', 59, y),
          _token('B.', 160, y),
          _token('Second', 179, y),
          _token('C.', 300, y),
          _token('Third', 319, y),
          _token('D.', 460, y),
          _token('Fourth', 479, y),
        ],
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates, hasLength(8));
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
        'A',
        'B',
        'C',
        'D',
      ]);
    });

    test('groups bare A-D error markers below a numbered sentence', () {
      final fragments = <SmartPenTextFragment>[
        _token('26.', 20, 100),
        _token('The', 46, 100),
        _token('most', 82, 100),
        _token('common', 126, 100),
        _token('sentence', 190, 100),
        _token('continues', 220, 100),
        _token('A', 62, 130),
        _token('B', 128, 130),
        _token('C', 194, 130),
        _token('D', 260, 130),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(1),
      );
    });

    test(
      'does not classify a bare A-D row without a nearby numbered sentence',
      () {
        final fragments = <SmartPenTextFragment>[
          _token('A', 62, 130),
          _token('B', 128, 130),
          _token('C', 194, 130),
          _token('D', 260, 130),
        ];

        expect(classifier.classify(fragments), isEmpty);
      },
    );

    test('splits compact consecutive two-column questions', () {
      List<SmartPenTextFragment> question(double y) => [
        _token('A.', 40, y),
        _token('First', 61, y),
        _token('B.', 330, y),
        _token('Second', 351, y),
        _token('C.', 40, y + 24),
        _token('Third', 61, y + 24),
        _token('D.', 330, y + 24),
        _token('Fourth', 351, y + 24),
      ];
      final fragments = [...question(100), ...question(148)];

      final candidates = classifier.classify(fragments);

      expect(candidates, hasLength(8));
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
      expect(
        candidates
            .where((candidate) => candidate.bounds.top < 148)
            .map((candidate) => candidate.groupId)
            .toSet(),
        hasLength(1),
      );
      expect(
        candidates
            .where((candidate) => candidate.bounds.top >= 148)
            .map((candidate) => candidate.groupId)
            .toSet(),
        hasLength(1),
      );
    });

    test('recognizes tightly spaced inline choices within one text column', () {
      final fragments = <SmartPenTextFragment>[
        _token('A.', 40, 100),
        _token('Yes', 53, 100),
        _token('B.', 105, 100),
        _token('No', 118, 100),
        _token('C.', 170, 100),
        _token('Maybe', 183, 100),
        _token('D.', 250, 100),
        _token('Never', 263, 100),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
      ]);
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(1),
      );
    });

    test('keeps a nearby vertical question separate from an inline row', () {
      final fragments = <SmartPenTextFragment>[
        _token('A.', 40, 100),
        _token('Yes', 53, 100),
        _token('B.', 105, 100),
        _token('No', 118, 100),
        _token('C.', 170, 100),
        _token('Maybe', 183, 100),
        _token('D.', 250, 100),
        _token('Never', 263, 100),
        ...[
          for (var i = 0; i < 4; i++) ...[
            _token('${String.fromCharCode(65 + i)}.', 40, 124 + i * 24),
            _token('Vertical option', 59, 124 + i * 24),
          ],
        ],
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates, hasLength(8));
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
      expect(
        candidates
            .where((candidate) => candidate.bounds.top == 100)
            .map((candidate) => candidate.groupId)
            .toSet(),
        hasLength(1),
      );
      expect(
        candidates
            .where((candidate) => candidate.bounds.top > 100)
            .map((candidate) => candidate.groupId)
            .toSet(),
        hasLength(1),
      );
    });

    test('splits adjacent vertical questions when the option labels reset', () {
      final fragments = <SmartPenTextFragment>[
        _token('A.', 40, 100),
        _token('First', 61, 100),
        _token('B.', 40, 124),
        _token('Second', 61, 124),
        _token('A.', 40, 158),
        _token('Third', 61, 158),
        _token('B.', 40, 182),
        _token('Fourth', 61, 182),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates, hasLength(4));
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
    });

    test('splits a complete question from a compact next A-D run', () {
      final fragments = <SmartPenTextFragment>[
        ..._verticalOptions(),
        _token('A.', 40, 196),
        _token('Fifth', 61, 196),
        _token('B.', 40, 220),
        _token('Sixth', 61, 220),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates, hasLength(6));
      expect(
        candidates.map((candidate) => candidate.groupId).toSet(),
        hasLength(2),
      );
    });

    test('accepts square-bracketed option markers', () {
      final fragments = <SmartPenTextFragment>[
        _token('[A]', 40, 100),
        _token('First', 61, 100),
        _token('[B]', 40, 124),
        _token('Second', 61, 124),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates.map((candidate) => candidate.label), ['A', 'B']);
    });

    test('accepts parenthesized marker punctuation variants', () {
      final fragments = <SmartPenTextFragment>[
        _token('(A)', 40, 100),
        _token('First', 61, 100),
        _token('(B.)', 40, 124),
        _token('Second', 61, 124),
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates.map((candidate) => candidate.label), ['A', 'B']);
    });

    test('finds option markers after unrelated watermark text on the row', () {
      final fragments = <SmartPenTextFragment>[
        for (var i = 0; i < 4; i++) ...[
          SmartPenTextFragment(
            text: 'tuyensinh247.com',
            bounds: Rect.fromLTWH(5 + i * 12, 100 + i * 24, 80, 12),
          ),
          _token('${String.fromCharCode(65 + i)}.', 90, 100 + i * 24),
          _token('Option', 111, 100 + i * 24),
        ],
      ];

      final candidates = classifier.classify(fragments);

      expect(candidates.map((candidate) => candidate.label), [
        'A',
        'B',
        'C',
        'D',
      ]);
    });

    test('does not accept labels preceded by ordinary same-row prose', () {
      final fragments = <SmartPenTextFragment>[
        _token('Summary', 40, 100),
        _token('A.', 55, 100),
        _token('applies here', 76, 100),
        _token('Summary', 40, 124),
        _token('B.', 55, 124),
        _token('belongs here', 76, 124),
      ];

      expect(classifier.classify(fragments), isEmpty);
    });

    test(
      'does not treat inline answer letters in an instruction as choices',
      () {
        final fragments = <SmartPenTextFragment>[
          _token('Choose', 40, 100),
          _token('A', 85, 100),
          _token('B', 103, 100),
          _token('C', 121, 100),
          _token('or', 139, 100),
          _token('D', 157, 100),
        ];

        expect(classifier.classify(fragments), isEmpty);
      },
    );

    test(
      'rejects prose, headings, section labels, isolated labels, and ambiguity',
      () {
        final fragments = <SmartPenTextFragment>[
          _token('An', 40, 300),
          _token('apple', 58, 300),
          _token('A.', 40, 40), // A heading without a nearby option group.
          _token('Section', 40, 230),
          _token('A', 91, 230),
          _token('A.', 40, 360), // Isolated answer-like label.
          _token('A.', 40, 430),
          _token('B.', 40, 460),
          _token('A.', 40, 490), // Duplicate label makes the cluster ambiguous.
          ..._verticalOptions(),
        ];

        final candidates = classifier.classify(fragments);

        expect(candidates.map((candidate) => candidate.label), [
          'A',
          'B',
          'C',
          'D',
        ]);
        expect(
          candidates.every((candidate) => candidate.bounds.top >= 100),
          isTrue,
        );
      },
    );

    test('does not merge nearby options across separate columns', () {
      final candidates = classifier.classify(_twoColumnOptions());

      final left = candidates.where((candidate) => candidate.bounds.left < 200);
      final right = candidates.where(
        (candidate) => candidate.bounds.left > 200,
      );
      expect(left.map((candidate) => candidate.groupId).toSet(), hasLength(1));
      expect(right.map((candidate) => candidate.groupId).toSet(), hasLength(1));
      expect(left.first.groupId, isNot(right.first.groupId));
    });
  });

  group('Smart Pen canonical page index', () {
    test('links horizontally aligned two-choice edge rows from extraction', () {
      SmartPenPageIndex buildEdgePage(
        int page,
        SmartPenPageEdge edge,
        List<(String, double)> options,
      ) {
        final y = edge == SmartPenPageEdge.bottom ? 760.0 : 20.0;
        return SmartPenPageIndex.build(
          documentGeneration: 17,
          pageNumber: page,
          pageSize: const Size(600, 800),
          fragments: [
            for (final (label, x) in options) ...[
              _token('$label.', x, y),
              _token('Choice', x + 20, y),
            ],
          ],
        );
      }

      final bottom = buildEdgePage(1, SmartPenPageEdge.bottom, [
        ('A', 40),
        ('B', 330),
      ]);
      final top = buildEdgePage(2, SmartPenPageEdge.top, [
        ('C', 40),
        ('D', 330),
      ]);
      expect(bottom.partialGroups, hasLength(1));
      expect(top.partialGroups, hasLength(1));
      expect(
        bottom.partialGroups.single.candidates.map(
          (candidate) => candidate.label,
        ),
        ['A', 'B'],
      );
      expect(
        top.partialGroups.single.candidates.map((candidate) => candidate.label),
        ['C', 'D'],
      );

      final groups = SmartPenDocumentAnswerLinker.resolve(
        generation: 17,
        indexes: {1: bottom, 2: top},
      );
      final ids = {
        for (final index in [bottom, top])
          for (final partial in index.partialGroups)
            for (final candidate in partial.candidates)
              groups.canonicalGroupIdFor(index.pageNumber, candidate),
      };
      expect(ids, hasLength(1));
    });

    test(
      'links unique complementary answer groups across adjacent page edges',
      () {
        final pageOne = _edgeIndex(
          generation: 7,
          pageNumber: 1,
          edge: SmartPenPageEdge.bottom,
          labels: ['A', 'B'],
        );
        final pageTwo = _edgeIndex(
          generation: 7,
          pageNumber: 2,
          edge: SmartPenPageEdge.top,
          labels: ['C', 'D'],
        );

        final groups = SmartPenDocumentAnswerLinker.resolve(
          generation: 7,
          indexes: {1: pageOne, 2: pageTwo},
        );
        final linked = [
          for (final candidate in pageOne.partialGroups.single.candidates)
            (1, candidate),
          for (final candidate in pageTwo.partialGroups.single.candidates)
            (2, candidate),
        ];
        final canonicalIds = linked
            .map((entry) => groups.canonicalGroupIdFor(entry.$1, entry.$2))
            .toSet();

        expect(canonicalIds, hasLength(1));
        expect(canonicalIds.single, isNotEmpty);
      },
    );

    test(
      'keeps discontinuous, noncomplementary, and stale page groups separate',
      () {
        final pageOne = _edgeIndex(
          generation: 9,
          pageNumber: 1,
          edge: SmartPenPageEdge.bottom,
          labels: ['A', 'B'],
        );
        final nonAdjacent = _edgeIndex(
          generation: 9,
          pageNumber: 3,
          edge: SmartPenPageEdge.top,
          labels: ['C', 'D'],
        );
        final wrongOrder = _edgeIndex(
          generation: 9,
          pageNumber: 2,
          edge: SmartPenPageEdge.top,
          labels: ['A', 'B'],
        );
        final stale = _edgeIndex(
          generation: 8,
          pageNumber: 2,
          edge: SmartPenPageEdge.top,
          labels: ['C', 'D'],
        );

        for (final indexes in [
          {1: pageOne, 3: nonAdjacent},
          {1: pageOne, 2: wrongOrder},
          {1: pageOne, 2: stale},
        ]) {
          final groups = SmartPenDocumentAnswerLinker.resolve(
            generation: 9,
            indexes: indexes,
          );
          final ids = indexes.entries
              .expand((entry) => entry.value.partialGroups)
              .expand(
                (partial) => partial.candidates.map(
                  (candidate) =>
                      groups.canonicalGroupIdFor(partial.pageNumber, candidate),
                ),
              )
              .toSet();
          expect(ids, hasLength(2));
        }
      },
    );

    test('canonical IDs do not depend on neighbor index readiness order', () {
      final pageOne = _edgeIndex(
        generation: 12,
        pageNumber: 1,
        edge: SmartPenPageEdge.bottom,
        labels: ['A', 'B'],
      );
      final pageTwo = _edgeIndex(
        generation: 12,
        pageNumber: 2,
        edge: SmartPenPageEdge.top,
        labels: ['C', 'D'],
      );
      final forward = SmartPenDocumentAnswerLinker.resolve(
        generation: 12,
        indexes: {1: pageOne, 2: pageTwo},
      );
      final reverse = SmartPenDocumentAnswerLinker.resolve(
        generation: 12,
        indexes: {2: pageTwo, 1: pageOne},
      );
      final nextPageOne = _edgeIndex(
        generation: 13,
        pageNumber: 1,
        edge: SmartPenPageEdge.bottom,
        labels: ['A', 'B'],
      );
      final nextPageTwo = _edgeIndex(
        generation: 13,
        pageNumber: 2,
        edge: SmartPenPageEdge.top,
        labels: ['C', 'D'],
      );
      final nextGeneration = SmartPenDocumentAnswerLinker.resolve(
        generation: 13,
        indexes: {1: nextPageOne, 2: nextPageTwo},
      );

      for (final candidate in pageOne.partialGroups.single.candidates) {
        expect(
          forward.canonicalGroupIdFor(1, candidate),
          reverse.canonicalGroupIdFor(1, candidate),
        );
      }
      for (final candidate in pageTwo.partialGroups.single.candidates) {
        expect(
          forward.canonicalGroupIdFor(2, candidate),
          reverse.canonicalGroupIdFor(2, candidate),
        );
      }
      expect(
        forward.canonicalGroupIdFor(
          1,
          pageOne.partialGroups.single.candidates.first,
        ),
        isNot(
          nextGeneration.canonicalGroupIdFor(
            1,
            nextPageOne.partialGroups.single.candidates.first,
          ),
        ),
      );
    });

    test('incremental readiness refresh preserves unrelated page links', () {
      final pageOne = _edgeIndex(
        generation: 18,
        pageNumber: 1,
        edge: SmartPenPageEdge.bottom,
        labels: ['A', 'B'],
      );
      final pageTwo = _edgeIndex(
        generation: 18,
        pageNumber: 2,
        edge: SmartPenPageEdge.top,
        labels: ['C', 'D'],
      );
      final initial = SmartPenDocumentAnswerLinker.resolve(
        generation: 18,
        indexes: {1: pageOne},
      );
      final afterPageTwo = SmartPenDocumentAnswerLinker.resolve(
        generation: 18,
        indexes: {1: pageOne, 2: pageTwo},
        previous: initial,
        changedPage: 2,
      );
      final canonicalBefore = afterPageTwo.candidatesForPage(1).first.groupId;
      final pageThree = _edgeIndex(
        generation: 18,
        pageNumber: 3,
        edge: SmartPenPageEdge.bottom,
        labels: ['A', 'B'],
      );
      final afterPageThree = SmartPenDocumentAnswerLinker.resolve(
        generation: 18,
        indexes: {1: pageOne, 2: pageTwo, 3: pageThree},
        previous: afterPageTwo,
        changedPage: 3,
      );

      expect(canonicalBefore, startsWith('answer-g18-p1-'));
      expect(
        afterPageThree.candidatesForPage(1).first.groupId,
        canonicalBefore,
      );
    });

    test('does not link competing edge groups when the match is ambiguous', () {
      final pageOne = _edgeIndexWithGroups(
        generation: 15,
        pageNumber: 1,
        edge: SmartPenPageEdge.bottom,
        labels: [
          ['A', 'B'],
          ['A', 'B'],
        ],
      );
      final pageTwo = _edgeIndex(
        generation: 15,
        pageNumber: 2,
        edge: SmartPenPageEdge.top,
        labels: ['C', 'D'],
      );
      final groups = SmartPenDocumentAnswerLinker.resolve(
        generation: 15,
        indexes: {1: pageOne, 2: pageTwo},
      );
      final ids = <String>{
        for (final index in [pageOne, pageTwo])
          for (final partial in index.partialGroups)
            for (final candidate in partial.candidates)
              groups.canonicalGroupIdFor(index.pageNumber, candidate),
      };

      expect(ids, hasLength(3));
    });

    test('does not link across explicit question heading evidence', () {
      final bottom = _edgeIndex(
        generation: 16,
        pageNumber: 1,
        edge: SmartPenPageEdge.bottom,
        labels: ['A', 'B'],
      );
      final plainTop = _edgeIndex(
        generation: 16,
        pageNumber: 2,
        edge: SmartPenPageEdge.top,
        labels: ['C', 'D'],
      );
      final top = SmartPenPageIndex.fromCandidates(
        documentGeneration: 16,
        pageNumber: 2,
        pageSize: plainTop.pageSize,
        candidates: const [],
        partialGroups: [
          SmartPenPartialAnswerGroup(
            pageNumber: 2,
            edge: SmartPenPageEdge.top,
            candidates: plainTop.partialGroups.single.candidates,
            hasQuestionHeadingEvidence: true,
          ),
        ],
      );

      final groups = SmartPenDocumentAnswerLinker.resolve(
        generation: 16,
        indexes: {1: bottom, 2: top},
      );
      final ids = {
        for (final index in [bottom, top])
          for (final partial in index.partialGroups)
            for (final candidate in partial.candidates)
              groups.canonicalGroupIdFor(index.pageNumber, candidate),
      };

      expect(ids, hasLength(2));
    });

    test(
      'keeps candidate bounds canonical while hit tolerance follows zoom',
      () {
        final index = _index(_verticalOptions());
        final candidate = index.candidates.first;
        final canonicalBounds = candidate.bounds;

        // The point sits 9 canonical units outside the label. At zoom 0.5 and
        // 1.0, that is within a 10-logical-pixel snap radius; at 2.0 it is not.
        expect(
          index.hitTest(
            const Offset(59, 100),
            logicalPixelTolerance: 10,
            zoomScale: 0.5,
          ),
          same(candidate),
        );
        expect(
          index.hitTest(
            const Offset(59, 100),
            logicalPixelTolerance: 10,
            zoomScale: 1,
          ),
          same(candidate),
        );
        expect(
          index.hitTest(
            const Offset(59, 100),
            logicalPixelTolerance: 10,
            zoomScale: 2,
          ),
          isNull,
        );
        expect(candidate.bounds, canonicalBounds);
      },
    );

    test(
      'returns no hit when more than one answer candidate is within tolerance',
      () {
        final index = SmartPenPageIndex.fromCandidates(
          documentGeneration: 4,
          pageNumber: 1,
          pageSize: const Size(600, 800),
          candidates: [
            SmartPenAnswerCandidate(
              label: 'A',
              bounds: const Rect.fromLTWH(100, 100, 8, 12),
              groupId: 'left',
            ),
            SmartPenAnswerCandidate(
              label: 'B',
              bounds: const Rect.fromLTWH(120, 100, 8, 12),
              groupId: 'right',
            ),
          ],
        );

        expect(
          index.hitTest(
            const Offset(114, 106),
            logicalPixelTolerance: 10,
            zoomScale: 1,
          ),
          isNull,
        );
      },
    );

    test('empty text and extraction failure remain explicit index states', () {
      final store = SmartPenPageIndexStore();
      store.beginGeneration(7);

      expect(store.markTextless(2), isTrue);
      expect(store.statusFor(2), SmartPenPageIndexStatus.empty);

      expect(store.failPage(3), isTrue);
      expect(store.statusFor(3), SmartPenPageIndexStatus.failed);
    });

    test('ignores completion from a prior PDF generation', () {
      final store = SmartPenPageIndexStore();
      store.beginGeneration(10);
      expect(store.beginPage(5), isTrue);
      final staleIndex = _index(
        _verticalOptions(),
        generation: 10,
        pageNumber: 5,
      );

      store.beginGeneration(11);

      expect(store.completePage(staleIndex), isFalse);
      expect(store.statusFor(5), SmartPenPageIndexStatus.notStarted);
    });

    test(
      'tracks page index lifecycle and accepts only current-generation results',
      () {
        final store = SmartPenPageIndexStore();
        store.beginGeneration(20);

        expect(store.statusFor(1), SmartPenPageIndexStatus.notStarted);
        expect(store.beginPage(1), isTrue);
        expect(store.statusFor(1), SmartPenPageIndexStatus.building);
        expect(
          store.completePage(_index(_verticalOptions(), generation: 20)),
          isTrue,
        );
        expect(store.statusFor(1), SmartPenPageIndexStatus.ready);
        expect(store.indexFor(1)?.candidates, hasLength(4));
      },
    );
  });

  group('Smart Pen synthetic corpus', () {
    test('fixture manifest and generated geometry are reproducible', () {
      expect(SmartPenSyntheticCorpus.version, 3);
      expect(SmartPenSyntheticCorpus.seed, 261017);
      expect(SmartPenSyntheticCorpus.positiveCaseIds, hasLength(150));
      expect(SmartPenSyntheticCorpus.negativeCaseIds, hasLength(100));
      expect(
        SmartPenSyntheticCorpus.caseIds,
        containsAll([
          'vertical-abcd',
          'two-column-abcd',
          'prose-a-distractors',
          'ambiguous-label-cluster',
          'textless-page',
        ]),
      );
      expect(
        SmartPenSyntheticCorpus.expectedLabels.keys,
        unorderedEquals(SmartPenSyntheticCorpus.caseIds),
      );

      final first = SmartPenSyntheticCorpus.generate('two-column-abcd');
      final second = SmartPenSyntheticCorpus.generate('two-column-abcd');
      expect(
        second.map((fragment) => (fragment.text, fragment.bounds)).toList(),
        first.map((fragment) => (fragment.text, fragment.bounds)).toList(),
      );
      expect(
        SmartPenSyntheticCorpus.generate(
          'positive-attached-04',
        ).map((fragment) => (fragment.text, fragment.bounds)).toList(),
        SmartPenSyntheticCorpus.generate(
          'positive-attached-04',
        ).map((fragment) => (fragment.text, fragment.bounds)).toList(),
      );
    });

    test(
      'versioned positive corpus scores formula and error-identification layouts',
      () {
        for (final layout in ['wide-formula', 'error-identification']) {
          final cases = SmartPenSyntheticCorpus.positiveCaseIds
              .where((caseId) => caseId.startsWith('positive-$layout-'))
              .toList();
          expect(cases, isNotEmpty, reason: 'Missing $layout corpus cases');

          for (final caseId in cases) {
            final expected = SmartPenSyntheticCorpus.expectedLabels[caseId]!;
            final actual = SmartPenAnswerClassifier()
                .classify(SmartPenSyntheticCorpus.generate(caseId))
                .map((candidate) => candidate.label)
                .toList();
            expect(
              expected,
              isNotEmpty,
              reason: 'Case $caseId is not positive',
            );
            expect(actual, expected, reason: 'Corpus case: $caseId');
          }
        }
      },
    );

    test('classifier matches each fixed corpus expected-label manifest', () {
      final classifier = SmartPenAnswerClassifier();
      var expectedCount = 0;
      var truePositiveCount = 0;
      var falsePositiveCount = 0;
      var falseNegativeCount = 0;
      final perLayout = <String, Map<String, int>>{};
      for (final caseId in SmartPenSyntheticCorpus.caseIds) {
        final actual = classifier.classify(
          SmartPenSyntheticCorpus.generate(caseId),
        );
        final actualLabels = actual
            .map((candidate) => candidate.label)
            .toList();
        final expected = SmartPenSyntheticCorpus.expectedLabels[caseId]!;
        final layout = caseId.startsWith('positive-')
            ? caseId.split('-')[1]
            : caseId.startsWith('negative-')
            ? 'negative-isolated'
            : 'baseline';
        final layoutCounts = perLayout.putIfAbsent(
          layout,
          () => {'TP': 0, 'FP': 0, 'FN': 0},
        );
        expectedCount += expected.length;
        final unmatchedActual = [...actualLabels];
        for (final label in expected) {
          final matchIndex = unmatchedActual.indexOf(label);
          if (matchIndex < 0) {
            falseNegativeCount++;
            layoutCounts['FN'] = layoutCounts['FN']! + 1;
          } else {
            truePositiveCount++;
            layoutCounts['TP'] = layoutCounts['TP']! + 1;
            unmatchedActual.removeAt(matchIndex);
          }
        }
        falsePositiveCount += unmatchedActual.length;
        layoutCounts['FP'] = layoutCounts['FP']! + unmatchedActual.length;
        expect(actualLabels, expected, reason: 'Fixture case: $caseId');
      }
      final negativeInstances = SmartPenSyntheticCorpus.negativeCaseIds.length;
      final precision =
          truePositiveCount / (truePositiveCount + falsePositiveCount);
      final recall =
          truePositiveCount / (truePositiveCount + falseNegativeCount);
      expect(precision, greaterThanOrEqualTo(0.99));
      expect(recall, greaterThanOrEqualTo(0.95));
      expect(expectedCount, greaterThanOrEqualTo(100));
      expect(negativeInstances, greaterThanOrEqualTo(100));
      final perLayoutMetrics = perLayout.entries
          .map((entry) {
            final tp = entry.value['TP']!;
            final fp = entry.value['FP']!;
            final fn = entry.value['FN']!;
            final layoutPrecision = tp + fp == 0 ? 1.0 : tp / (tp + fp);
            final layoutRecall = tp + fn == 0 ? 1.0 : tp / (tp + fn);
            return '${entry.key}[TP=$tp,FP=$fp,FN=$fn,'
                'P=${(layoutPrecision * 100).toStringAsFixed(0)}%,'
                'R=${(layoutRecall * 100).toStringAsFixed(0)}%]';
          })
          .join('; ');
      // ignore: avoid_print
      print(
        'Smart Pen fixture metrics: cases=${SmartPenSyntheticCorpus.caseIds.length}, '
        'positive=$expectedCount, negative=$negativeInstances, '
        'TP=$truePositiveCount, FP=$falsePositiveCount, FN=$falseNegativeCount, '
        'precision=${(precision * 100).toStringAsFixed(1)}%, '
        'recall=${(recall * 100).toStringAsFixed(1)}%, '
        'per-layout=$perLayoutMetrics',
      );
    });

    test('builds a 1,000-candidate ready-index lookup workload', () {
      final fragments = <SmartPenTextFragment>[];
      for (var group = 0; group < 250; group++) {
        final x = 24.0;
        final y = 20.0 + group * 200;
        for (var option = 0; option < 4; option++) {
          final label = String.fromCharCode(65 + option);
          fragments.add(_token('$label.', x, y + option * 24));
          fragments.add(_token('Option', x + 18, y + option * 24));
        }
      }

      final index = _index(fragments, pageSize: const Size(600, 60000));
      final samples = <int>[];
      for (var i = 0; i < 1000; i++) {
        final candidate = index.candidates[i];
        final watch = Stopwatch()..start();
        index.hitTest(
          candidate.bounds.center,
          logicalPixelTolerance: 10,
          zoomScale: 1,
        );
        watch.stop();
        samples.add(watch.elapsedMicroseconds);
      }
      samples.sort();
      final p95Micros = samples[(samples.length * 0.95).floor()];

      expect(index.candidates, hasLength(1000));
      expect(p95Micros, lessThan(1000));
      // ignore: avoid_print
      print(
        'Smart Pen ready-index lookup: p95=${p95Micros}us, '
        'candidates=${index.candidates.length}, samples=${samples.length}',
      );
    });

    test(
      'extracts positioned labels from a deterministic synthetic PDF',
      () async {
        await _initializePdfrxForTest();
        final document = await pdfrx.PdfDocument.openData(
          _syntheticAnswerPdf(),
          useProgressiveLoading: false,
          sourceName: 'smart-pen-fixture-v1.pdf',
        );
        try {
          final stopwatch = Stopwatch()..start();
          final fragments = await SmartPenPdfTextExtractor().extract(
            document.pages.first,
          );
          stopwatch.stop();
          // ignore: avoid_print
          print(
            'Smart Pen fixture extraction: vertical=${stopwatch.elapsedMilliseconds}ms, fragments=${fragments.length}',
          );
          final candidates = SmartPenAnswerClassifier().classify(fragments);

          expect(candidates.map((candidate) => candidate.label), [
            'A',
            'B',
            'C',
            'D',
          ]);
          expect(
            candidates.map((candidate) => candidate.groupId).toSet(),
            hasLength(1),
          );
          expect(
            candidates.every(
              (candidate) =>
                  candidate.bounds.left >= 39 && candidate.bounds.left <= 41,
            ),
            isTrue,
          );
          expect(
            candidates.every((candidate) => candidate.bounds.top > 0),
            isTrue,
          );
        } finally {
          await document.dispose();
        }
      },
    );

    test('extracts option groups from a deterministic two-column PDF', () async {
      await _initializePdfrxForTest();
      final document = await pdfrx.PdfDocument.openData(
        _syntheticAnswerPdf(twoColumns: true),
        useProgressiveLoading: false,
        sourceName: 'smart-pen-fixture-two-column-v1.pdf',
      );
      try {
        final stopwatch = Stopwatch()..start();
        final fragments = await SmartPenPdfTextExtractor().extract(
          document.pages.first,
        );
        stopwatch.stop();
        // ignore: avoid_print
        print(
          'Smart Pen fixture extraction: two-column=${stopwatch.elapsedMilliseconds}ms, fragments=${fragments.length}',
        );
        final candidates = SmartPenAnswerClassifier().classify(fragments);

        expect(candidates.map((candidate) => candidate.label), [
          'A',
          'B',
          'C',
          'D',
          'A',
          'B',
          'C',
          'D',
        ]);
        expect(
          candidates.map((candidate) => candidate.groupId).toSet(),
          hasLength(2),
        );
      } finally {
        await document.dispose();
      }
    });

    test(
      'extracts attached answer markers from a synthetic text PDF',
      () async {
        await _initializePdfrxForTest();
        final document = await pdfrx.PdfDocument.openData(
          _syntheticAnswerPdf(attachedMarkers: true),
          useProgressiveLoading: false,
          sourceName: 'smart-pen-attached-marker-fixture.pdf',
        );
        try {
          final fragments = await SmartPenPdfTextExtractor().extract(
            document.pages.first,
          );
          final candidates = SmartPenAnswerClassifier().classify(fragments);

          expect(candidates.map((candidate) => candidate.label), [
            'A',
            'B',
            'C',
            'D',
          ]);
          expect(
            candidates.every((candidate) => candidate.bounds.width < 20),
            isTrue,
          );
        } finally {
          await document.dispose();
        }
      },
    );

    test(
      'extracts scale-spaced formula answers from a synthetic text PDF',
      () async {
        await _initializePdfrxForTest();
        final document = await pdfrx.PdfDocument.openData(
          _syntheticAnswerPdf(wideFormula: true),
          useProgressiveLoading: false,
          sourceName: 'smart-pen-wide-formula-fixture.pdf',
        );
        try {
          final fragments = await SmartPenPdfTextExtractor().extract(
            document.pages.first,
          );
          final candidates = SmartPenAnswerClassifier().classify(fragments);

          expect(
            candidates.map((candidate) => candidate.label),
            unorderedEquals(['A', 'B', 'C', 'D']),
          );
          expect(
            candidates.map((candidate) => candidate.groupId).toSet(),
            hasLength(1),
          );
        } finally {
          await document.dispose();
        }
      },
    );

    test(
      'maps text bounds into the displayed orientation of rotated pages',
      () async {
        await _initializePdfrxForTest();
        final document = await pdfrx.PdfDocument.openData(
          _syntheticAnswerPdf(),
          useProgressiveLoading: false,
          sourceName: 'smart-pen-rotated-fixture-v1.pdf',
        );
        try {
          final sourcePage = document.pages.first;
          final rotatedPage = sourcePage.rotatedCW90();
          final extractor = SmartPenPdfTextExtractor();
          final fragments = await extractor.extract(rotatedPage);
          final pageSize = SmartPenPdfTextExtractor.canonicalPageSize(
            rotatedPage,
          );
          final candidates = SmartPenAnswerClassifier().classify(fragments);

          expect(rotatedPage.rotation.index.isOdd, isTrue);
          expect(pageSize, Size(sourcePage.height, sourcePage.width));
          expect(candidates, hasLength(4));
          expect(
            candidates.every(
              (candidate) =>
                  candidate.bounds.left >= 0 &&
                  candidate.bounds.top >= 0 &&
                  candidate.bounds.right <= pageSize.width &&
                  candidate.bounds.bottom <= pageSize.height,
            ),
            isTrue,
          );
        } finally {
          await document.dispose();
        }
      },
    );
  });
}

Future<void> _initializePdfrxForTest() async {
  await pdfrx.pdfrxFlutterInitialize();
}

List<SmartPenTextFragment> _verticalOptions() => [
  for (var i = 0; i < 4; i++) ...[
    _token('${String.fromCharCode(65 + i)}.', 40, 100 + i * 24),
    _token('Option', 61, 100 + i * 24),
  ],
];

List<SmartPenTextFragment> _twoColumnOptions() => [
  for (final x in [40.0, 330.0])
    for (var i = 0; i < 4; i++) ...[
      _token('${String.fromCharCode(65 + i)}.', x, 100 + i * 24),
      _token('Option', x + 21, 100 + i * 24),
    ],
];

List<SmartPenTextFragment> _twoColumnQuestionOptions() => [
  _token('A.', 40, 100),
  _token('First', 61, 100),
  _token('B.', 330, 100),
  _token('Second', 351, 100),
  _token('C.', 40, 124),
  _token('Third', 61, 124),
  _token('D.', 330, 124),
  _token('Fourth', 351, 124),
];

SmartPenPageIndex _edgeIndex({
  required int generation,
  required int pageNumber,
  required SmartPenPageEdge edge,
  required List<String> labels,
}) => _edgeIndexWithGroups(
  generation: generation,
  pageNumber: pageNumber,
  edge: edge,
  labels: [labels],
);

SmartPenPageIndex _edgeIndexWithGroups({
  required int generation,
  required int pageNumber,
  required SmartPenPageEdge edge,
  required List<List<String>> labels,
}) => SmartPenPageIndex.fromCandidates(
  documentGeneration: generation,
  pageNumber: pageNumber,
  pageSize: const Size(600, 800),
  candidates: const [],
  partialGroups: [
    for (var groupIndex = 0; groupIndex < labels.length; groupIndex++)
      SmartPenPartialAnswerGroup(
        pageNumber: pageNumber,
        edge: edge,
        candidates: [
          for (
            var labelIndex = 0;
            labelIndex < labels[groupIndex].length;
            labelIndex++
          )
            SmartPenAnswerCandidate(
              label: labels[groupIndex][labelIndex],
              bounds: Rect.fromLTWH(
                40 + labelIndex * 120,
                edge == SmartPenPageEdge.bottom
                    ? 736 + labelIndex * 24
                    : labelIndex * 24,
                10,
                12,
              ),
              groupId: 'partial-g$generation-p$pageNumber-$groupIndex',
            ),
        ],
      ),
  ],
);

SmartPenTextFragment _token(String text, double x, double y) =>
    SmartPenTextFragment(text: text, bounds: Rect.fromLTWH(x, y, 10, 12));

SmartPenPageIndex _index(
  List<SmartPenTextFragment> fragments, {
  int generation = 1,
  int pageNumber = 1,
  Size pageSize = const Size(600, 800),
}) => SmartPenPageIndex.build(
  documentGeneration: generation,
  pageNumber: pageNumber,
  pageSize: pageSize,
  fragments: fragments,
);

/// Fixed, source-controlled input set for the synthetic classifier
/// evaluation. It deliberately carries no claim about real-world PDF accuracy.
class SmartPenSyntheticCorpus {
  static const version = 3;
  static const seed = 261017;
  static const _baseCaseIds = <String>[
    'vertical-abcd',
    'two-column-abcd',
    'prose-a-distractors',
    'ambiguous-label-cluster',
    'textless-page',
  ];
  static const _baseExpectedLabels = <String, List<String>>{
    'vertical-abcd': ['A', 'B', 'C', 'D'],
    'two-column-abcd': ['A', 'B', 'C', 'D', 'A', 'B', 'C', 'D'],
    'prose-a-distractors': ['A', 'B', 'C', 'D'],
    'ambiguous-label-cluster': [],
    'textless-page': [],
  };

  static final positiveCaseIds = <String>[
    for (final layout in [
      'vertical',
      'two-column',
      'attached',
      'inline',
      'wide-formula',
      'error-identification',
    ])
      for (var index = 0; index < 25; index++)
        'positive-$layout-${index.toString().padLeft(2, '0')}',
  ];
  static final negativeCaseIds = <String>[
    for (var index = 0; index < 100; index++)
      'negative-isolated-${index.toString().padLeft(3, '0')}',
  ];
  static final caseIds = <String>[
    ..._baseCaseIds,
    ...positiveCaseIds,
    ...negativeCaseIds,
  ];
  static final expectedLabels = <String, List<String>>{
    ..._baseExpectedLabels,
    for (final caseId in positiveCaseIds)
      caseId: caseId.startsWith('positive-two-column-')
          ? const ['A', 'C', 'B', 'D']
          : caseId.startsWith('positive-wide-formula-')
          ? const ['A', 'C', 'B', 'D']
          : const ['A', 'B', 'C', 'D'],
    for (final caseId in negativeCaseIds) caseId: const [],
  };

  static List<SmartPenTextFragment> generate(String caseId) {
    final positiveMatch = RegExp(
      r'^positive-(vertical|two-column|attached|inline|wide-formula|error-identification)-(\d+)$',
    ).firstMatch(caseId);
    final negativeMatch = RegExp(
      r'^negative-isolated-(\d+)$',
    ).firstMatch(caseId);
    late final List<SmartPenTextFragment> fragments;
    if (positiveMatch != null) {
      final index = int.parse(positiveMatch.group(2)!);
      fragments =
          switch (positiveMatch.group(1)!) {
                'vertical' => _verticalOptions(),
                'two-column' => _twoColumnQuestionOptions(),
                'attached' => [
                  for (var option = 0; option < 4; option++)
                    _token(
                      '${String.fromCharCode(65 + option)}.Choice',
                      40,
                      100 + option * 24,
                    ),
                ],
                'inline' => [
                  for (var option = 0; option < 4; option++) ...[
                    _token(
                      '${String.fromCharCode(65 + option)}.',
                      40 + option * 125,
                      180,
                    ),
                    _token('Choice', 60 + option * 125, 180),
                  ],
                ],
                'wide-formula' => [
                  _token('44.', 20, 100),
                  _token('Evaluate the following expressions:', 46, 100),
                  _token('A.', 40, 130),
                  _token('I = integral from 0 to pi/4', 102, 130),
                  _token('B.', 330, 130),
                  _token('I = 8 integral (1 + cos 2t)', 392, 130),
                  _token('C.', 40, 166),
                  _token('I = 16 integral sin squared t', 102, 166),
                  _token('D.', 330, 166),
                  _token('I = 8 integral (1 - cos 2t)', 392, 166),
                ],
                'error-identification' => [
                  _token('26.', 20, 100),
                  _token('The', 46, 100),
                  _token('most', 82, 100),
                  _token('common', 126, 100),
                  _token('sentence', 190, 100),
                  _token('continues', 220, 100),
                  _token('A', 62, 130),
                  _token('B', 128, 130),
                  _token('C', 194, 130),
                  _token('D', 260, 130),
                ],
                _ => const <SmartPenTextFragment>[],
              }
              .map((fragment) {
                final offset = Offset((index % 5) * 3.0, (index % 7) * 2.0);
                return SmartPenTextFragment(
                  text: fragment.text,
                  bounds: fragment.bounds.shift(offset),
                );
              })
              .toList(growable: false);
    } else if (negativeMatch != null) {
      final index = int.parse(negativeMatch.group(1)!);
      final label = String.fromCharCode(65 + index % 4);
      final x = 40.0 + (index % 5) * 80;
      final y = 120.0 + (index % 9) * 30;
      fragments = [_token('$label.', x, y), _token('Section', x + 22, y + 40)];
    } else {
      fragments = switch (caseId) {
        'vertical-abcd' => _verticalOptions(),
        'two-column-abcd' => _twoColumnOptions(),
        'prose-a-distractors' => <SmartPenTextFragment>[
          _token('An', 40, 400),
          _token('apple', 58, 400),
          _token('A.', 40, 300),
          _token('Section', 40, 400),
          _token('A', 91, 400),
          ..._verticalOptions(),
        ],
        'ambiguous-label-cluster' => <SmartPenTextFragment>[
          _token('A.', 40, 100),
          _token('B.', 40, 124),
          _token('A.', 40, 148),
        ],
        'textless-page' => const <SmartPenTextFragment>[],
        _ => throw ArgumentError.value(
          caseId,
          'caseId',
          'Unknown synthetic corpus case',
        ),
      };
    }
    // A fixed seed applies a stable positional offset so corpus regeneration
    // remains deterministic while avoiding dependence on a single origin.
    const offset = Offset(seed % 7, seed % 11);
    return fragments
        .map(
          (fragment) => SmartPenTextFragment(
            text: fragment.text,
            bounds: fragment.bounds.shift(offset),
          ),
        )
        .toList(growable: false);
  }
}

Uint8List _syntheticAnswerPdf({
  bool twoColumns = false,
  bool attachedMarkers = false,
  bool wideFormula = false,
}) {
  final stream = twoColumns
      ? 'BT /F1 12 Tf 18 TL 40 740 Td '
            '(A. First left) Tj T* '
            '(B. Second left) Tj T* '
            '(C. Third left) Tj T* '
            '(D. Fourth left) Tj '
            'ET '
            'BT /F1 12 Tf 18 TL 330 740 Td '
            '(A. First right) Tj T* '
            '(B. Second right) Tj T* '
            '(C. Third right) Tj T* '
            '(D. Fourth right) Tj '
            'ET'
      : attachedMarkers
      ? 'BT /F1 12 Tf 18 TL 40 740 Td '
            '(A.First option) Tj T* '
            '(B.Second option) Tj T* '
            '(C.Third option) Tj T* '
            '(D.Fourth option) Tj '
            'ET'
      : wideFormula
      ? [
          for (final option in [
            ('A.', 40, 740, 112, 'I = integral 0 to pi/4'),
            ('B.', 330, 740, 402, 'I = 8 integral (1 + cos 2t)'),
            ('C.', 40, 704, 112, 'I = 16 integral sin squared t'),
            ('D.', 330, 704, 402, 'I = 8 integral (1 - cos 2t)'),
          ])
            'BT /F1 12 Tf ${option.$2} ${option.$3} Td '
                '(${option.$1}) Tj ET '
                'BT /F1 12 Tf ${option.$4} ${option.$3} Td '
                '(${option.$5}) Tj ET ',
        ].join()
      : 'BT /F1 12 Tf 18 TL 40 740 Td '
            '(A. First option) Tj T* '
            '(B. Second option) Tj T* '
            '(C. Third option) Tj T* '
            '(D. Fourth option) Tj T* '
            '(Section A) Tj T* '
            '(An apple is a distractor) Tj '
            'ET';
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [4 0 R] /Count 1 >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Courier >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 600 800] '
        '/Resources << /Font << /F1 3 0 R >> >> /Contents 5 0 R >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[0];
  for (var index = 0; index < objects.length; index++) {
    offsets.add(pdf.length);
    pdf.write('${index + 1} 0 obj\n${objects[index]}\nendobj\n');
  }
  final xref = pdf.length;
  pdf.write('xref\n0 ${offsets.length}\n0000000000 65535 f \n');
  for (final offset in offsets.skip(1)) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write(
    'trailer\n<< /Size ${offsets.length} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF',
  );
  return Uint8List.fromList(ascii.encode(pdf.toString()));
}

