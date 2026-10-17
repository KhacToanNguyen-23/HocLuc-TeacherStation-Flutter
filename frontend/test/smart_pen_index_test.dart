import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:teaching_companion/services/smart_pen_answer_index.dart';

void main() {
  group('Smart Pen answer candidate classification', () {
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
      expect(SmartPenSyntheticCorpus.version, 1);
      expect(SmartPenSyntheticCorpus.seed, 261017);
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
    });

    test('classifier matches each fixed corpus expected-label manifest', () {
      final classifier = SmartPenAnswerClassifier();
      var expectedCount = 0;
      var predictedCount = 0;
      var truePositiveCount = 0;
      for (final caseId in SmartPenSyntheticCorpus.caseIds) {
        final actual = classifier.classify(
          SmartPenSyntheticCorpus.generate(caseId),
        );
        final actualLabels = actual
            .map((candidate) => candidate.label)
            .toList();
        final expected = SmartPenSyntheticCorpus.expectedLabels[caseId]!;
        expectedCount += expected.length;
        predictedCount += actual.length;
        truePositiveCount += actualLabels
            .where((label) => expected.contains(label))
            .length;
        expect(actualLabels, expected, reason: 'Fixture case: $caseId');
      }
      final precision = truePositiveCount / predictedCount;
      final recall = truePositiveCount / expectedCount;
      expect(precision, greaterThanOrEqualTo(0.99));
      expect(recall, greaterThanOrEqualTo(0.90));
      // ignore: avoid_print
      print(
        'Smart Pen fixture metrics: cases=${SmartPenSyntheticCorpus.caseIds.length}, '
        'expected=$expectedCount, predicted=$predictedCount, '
        'precision=${(precision * 100).toStringAsFixed(1)}%, '
        'recall=${(recall * 100).toStringAsFixed(1)}%, falsePositives=0, falseNegatives=0',
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
          final fragments = await SmartPenPdfTextExtractor().extract(document.pages.first);
          stopwatch.stop();
          // ignore: avoid_print
          print('Smart Pen fixture extraction: vertical=${stopwatch.elapsedMilliseconds}ms, fragments=${fragments.length}');
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

    test(
      'extracts option groups from a deterministic two-column PDF',
      () async {
        await _initializePdfrxForTest();
        final document = await pdfrx.PdfDocument.openData(
          _syntheticAnswerPdf(twoColumns: true),
          useProgressiveLoading: false,
          sourceName: 'smart-pen-fixture-two-column-v1.pdf',
        );
        try {
          final stopwatch = Stopwatch()..start();
          final fragments = await SmartPenPdfTextExtractor().extract(document.pages.first);
          stopwatch.stop();
          // ignore: avoid_print
          print('Smart Pen fixture extraction: two-column=${stopwatch.elapsedMilliseconds}ms, fragments=${fragments.length}');
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
  if (kIsWeb) {
    await pdfrx.pdfrxFlutterInitialize();
  } else {
    await pdfrx.pdfrxInitialize();
  }
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

/// Fixed, source-controlled input set for the initial synthetic classifier
/// evaluation. It deliberately carries no claim about real-world PDF accuracy.
class SmartPenSyntheticCorpus {
  static const version = 1;
  static const seed = 261017;
  static const caseIds = <String>[
    'vertical-abcd',
    'two-column-abcd',
    'prose-a-distractors',
    'ambiguous-label-cluster',
    'textless-page',
  ];
  static const expectedLabels = <String, List<String>>{
    'vertical-abcd': ['A', 'B', 'C', 'D'],
    'two-column-abcd': ['A', 'B', 'C', 'D', 'A', 'B', 'C', 'D'],
    'prose-a-distractors': ['A', 'B', 'C', 'D'],
    'ambiguous-label-cluster': [],
    'textless-page': [],
  };

  static List<SmartPenTextFragment> generate(String caseId) {
    final fragments = switch (caseId) {
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

Uint8List _syntheticAnswerPdf({bool twoColumns = false}) {
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
