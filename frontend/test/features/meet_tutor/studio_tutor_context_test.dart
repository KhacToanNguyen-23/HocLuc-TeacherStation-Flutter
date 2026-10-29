import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:teaching_companion/features/meet_tutor/services/studio_tutor_context.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

Uint8List pdf(List<String> texts, {bool privateAnnotation = false}) {
  final doc = sf.PdfDocument();
  try {
    for (final text in texts) {
      final page = doc.pages.add();
      page.graphics.drawString(
        text,
        sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 12),
      );
      if (privateAnnotation) {
        page.annotations.add(
          sf.PdfPopupAnnotation(
            const Rect.fromLTWH(10, 10, 30, 30),
            'PRIVATE PDF ANSWER KEY',
          ),
        );
      }
    }
    return Uint8List.fromList(doc.saveSync());
  } finally {
    doc.dispose();
  }
}

BoardSticker sticker(String id, String text) => BoardSticker(
  id: id,
  type: 'text',
  normalizedRect: const Rect.fromLTWH(.1, .1, .2, .2),
  rawText: text,
  tokens: const [
    {'answerKey': 'PRIVATE TOKEN'},
  ],
);

SmartChalkAnnotation chalk(String id, String text, {bool visible = true}) =>
    SmartChalkAnnotation(
      id: id,
      rawText: text,
      normalizedBounds: const Rect.fromLTWH(.1, .1, .2, .2),
      tokens: [],
      isVisible: visible,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late StudioState studio;
  late StudioTutorContext context;
  setUp(() {
    studio = StudioState();
    context = StudioTutorContext(studio);
  });
  tearDown(() {
    context.dispose();
    studio.dispose();
  });

  test(
    'only current visible text; no notes, drafts, analysis or other pages',
    () async {
      studio.notes = 'PRIVATE NOTES';
      studio.pageNotes[0] = 'PRIVATE SPEAKER NOTES';
      studio.canvas.chalkDraftText = 'PRIVATE DRAFT';
      studio.pageStickers[0] = [sticker('public', 'Visible lesson')];
      studio.pageStickers[1] = [sticker('future', 'PRIVATE FUTURE PAGE')];
      studio.pageChalkAnnotations[0] = [
        chalk('yes', 'Visible chalk'),
        chalk('no', 'PRIVATE HIDDEN', visible: false),
      ];
      final dirty = studio.dirty;
      final result = await context.build('lesson?');
      expect(result.currentPage, 1);
      expect(
        result.sources.map((s) => s.text),
        containsAll(['Visible lesson', 'Visible chalk']),
      );
      expect(
        result.sources.map((s) => s.text).join(),
        isNot(contains('PRIVATE')),
      );
      expect(studio.dirty, dirty);
      expect(studio.pageStickers.keys, [0, 1]);
    },
  );

  test(
    'global chalk visibility and viewport control the allowed sources',
    () async {
      studio.pageChalkAnnotations[0] = [chalk('chalk', 'Board chalk')];
      studio.pageStickers[0] = [sticker('sticker', 'Board sticker')];
      studio.pdfBytes = pdf(['PDF lesson']);
      studio.pdfChalkAnnotations[1] = [chalk('unowned', 'PRIVATE PDF CHALK')];
      studio.setViewportMode(StudioViewportMode.fullPdf);
      var result = await context.build('lesson?');
      expect(result.sources.map((s) => s.text).join(), contains('PDF lesson'));
      expect(
        result.sources.map((s) => s.text).join(),
        isNot(contains('Board')),
      );
      expect(
        result.sources.map((s) => s.text).join(),
        isNot(contains('PRIVATE')),
      );
      studio.setViewportMode(StudioViewportMode.split);
      result = await context.build('lesson?');
      expect(result.sources.map((s) => s.text), contains('Board chalk'));
      studio.toggleChalkAnnotationsVisibility();
      result = await context.build('lesson?');
      expect(result.sources.map((s) => s.text), isNot(contains('Board chalk')));
      expect(result.sources.map((s) => s.text), contains('Board sticker'));
    },
  );

  test(
    'irrelevant notifications do not revise; visible text and ink do',
    () async {
      studio.addPage('Second board');
      studio.setPage(0);
      final baseline = context.revision;
      var notifications = 0;
      context.addListener(() => notifications++);
      studio.change(() => studio.notes = 'Private');
      studio.setPageNote(0, 'Speaker');
      studio.tool = 'highlight';
      expect(context.revision, baseline);
      studio.addSticker(sticker('one', 'A visible statement'));
      expect(context.revision, baseline + 1);
      expect(
        notifications,
        1,
      ); // Child plus forwarded notifications deduplicate.
      studio.addStroke(BoardStroke(Colors.white, 3, [const Offset(.1, .2)]));
      expect(context.revision, baseline + 2);
      expect(notifications, 2);
      studio.setPage(1);
      expect(context.revision, baseline + 3);
      await context.build('anything?');
      expect(context.revision, baseline + 3);
    },
  );

  test('empty read preserves maps and dirty board state', () async {
    studio.dirty = true;
    expect((await context.build('why?')).sources, isEmpty);
    expect(studio.pageStickers, isEmpty);
    expect(studio.pageChalkAnnotations, isEmpty);
    expect(studio.dirty, isTrue);
  });

  test(
    'subject metadata travels with context and changes invalidate a snapshot',
    () async {
      studio.subject = 'Mathematics';
      final first = await context.build('question');
      expect(first.lessonSubject, 'Mathematics');
      studio.change(() => studio.subject = 'Science', persist: false);
      final next = await context.build('question');
      expect(next.lessonSubject, 'Science');
      expect(next.revision, greaterThan(first.revision));
    },
  );

  test(
    'handwriting and scanned/textless pages never become invented evidence',
    () async {
      studio.addStroke(BoardStroke(Colors.white, 3, [const Offset(.1, .2)]));
      expect((await context.build('what is written?')).sources, isEmpty);
      expect(
        StudioTutorContext.handwritingLimitation,
        contains('not recognized'),
      );
      studio.pdfBytes = pdf(['']);
      studio.setViewportMode(StudioViewportMode.fullPdf);
      expect((await context.build('what?')).sources, isEmpty);
    },
  );

  test('PDF current page precedes lexical matches on other pages', () async {
    studio.pdfBytes = pdf([
      'mitochondria energy',
      'Current unrelated lesson',
      'completely different',
    ]);
    studio.setPdfTotalPages(3);
    studio.setPdfPage(2);
    studio.setViewportMode(StudioViewportMode.fullPdf);
    final result = await context.build('What is mitochondria energy?');
    expect(result.currentPage, 2);
    expect(result.sources.first.label, 'PDF page 2');
    expect(result.sources[1].label, 'PDF page 1');
    expect(result.sources, hasLength(2));
  });

  test('bounded chunks and source count for a long visible board', () async {
    studio.pageStickers[0] = [
      sticker(
        'long',
        List.filled(1000, 'A complete sentence about words. ').join(),
      ),
    ];
    final result = await context.build('word?');
    expect(result.sources, hasLength(6));
    expect(result.sources.every((s) => s.text.length <= 3000), isTrue);
    expect(result.sources.map((s) => s.id).toSet(), hasLength(6));
  });

  test(
    'chunk boundaries never turn a negated long sentence into an affirmative suffix',
    () async {
      final longSentence =
          'This switch must not ${List.filled(600, 'ever ').join()}be enabled.';
      expect(longSentence.length, greaterThan(3000));
      studio.pageStickers[0] = [
        sticker('negative', '$longSentence A safe complete sentence.'),
      ];
      final result = await context.build('enabled?');
      expect(
        result.sources.map((s) => s.text).join(),
        isNot(contains('be enabled.')),
      );
      expect(result.sources.single.text, 'A safe complete sentence.');
    },
  );

  test('embedded PDF text excludes private annotation dictionaries', () async {
    studio.pdfBytes = pdf(['Public PDF passage'], privateAnnotation: true);
    studio.setViewportMode(StudioViewportMode.fullPdf);
    final text = (await context.build(
      'passage?',
    )).sources.map((s) => s.text).join();
    expect(text, contains('Public PDF passage'));
    expect(text, isNot(contains('PRIVATE')));
  });

  test('document switch during extraction rejects old evidence', () async {
    studio.pdfBytes = pdf(['Old document evidence']);
    studio.setViewportMode(StudioViewportMode.fullPdf);
    final revision = context.revision;
    final pending = context.build('document?');
    // Yield until parsing has been scheduled, then invalidate its generation.
    await Future<void>.delayed(Duration.zero);
    studio.pdfBytes = pdf(['New document evidence']);
    studio.change(() {}, persist: false);
    final old = await pending;
    expect(old.revision, revision);
    expect(old.sources, isEmpty);
    final fresh = await context.build('document?');
    expect(fresh.revision, greaterThan(old.revision));
    expect(fresh.sources.single.text, contains('New document evidence'));
  });

  test(
    'path fallback caches extraction and releases it on document replacement',
    () async {
      final dir = await Directory.systemTemp.createTemp('tutor-context-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/lesson.pdf');
      await file.writeAsBytes(pdf(['Cached file lesson']));
      studio.pdfFilePath = file.path;
      studio.setViewportMode(StudioViewportMode.fullPdf);
      expect(
        (await context.build('lesson?')).sources.single.text,
        contains('Cached file lesson'),
      );
      await file.delete();
      expect(
        (await context.build('lesson?')).sources.single.text,
        contains('Cached file lesson'),
      );
      studio.pdfFilePath = '${dir.path}/missing.pdf';
      studio.change(() {}, persist: false);
      expect((await context.build('lesson?')).sources, isEmpty);
    },
  );

  test('oversized and over-page-limit PDFs yield board-only context', () async {
    studio.pageStickers[0] = [sticker('board', 'Visible board')];
    studio.setViewportMode(StudioViewportMode.split);
    studio.pdfBytes = Uint8List(StudioTutorContext.maxPdfBytes + 1);
    expect(
      (await context.build('board?')).sources.single.text,
      'Visible board',
    );
    studio.pdfBytes = pdf(List.filled(201, 'Unshared PDF content'));
    studio.change(() {}, persist: false);
    expect(
      (await context.build('board?')).sources.single.text,
      'Visible board',
    );
  });

  test('disposal detaches listeners and blocks future builds', () async {
    final isolated = StudioTutorContext(studio);
    isolated.dispose();
    studio.addSticker(sticker('new', 'After disposal'));
    expect(isolated.revision, 0);
    await expectLater(isolated.build('why?'), throwsStateError);
  });
}
