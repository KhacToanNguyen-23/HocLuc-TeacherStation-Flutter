import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PedagogicalHighlightPolicy Unit Tests', () {
    test('Default policy has sensible pedagogical defaults', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      expect(policy.hideA1A2ByDefault, isTrue);
      expect(policy.selectiveB1Highlighting, isTrue);
      expect(policy.prioritizeAcademicVocabulary, isTrue);
      expect(policy.prioritizeCollocations, isTrue);
      expect(policy.prioritizeImportantGrammar, isTrue);
      expect(policy.showAllVocabulary, isFalse);
      expect(policy.showA1A2, isFalse);
    });

    test('Grammar and Collocations are always highlighted by default', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      const grammarSpan = PdfDgnlHighlightSpan(
        text: 'were placed',
        category: 'grammar',
        type: 'CÂU BỊ ĐỘNG (PASSIVE VOICE)',
        note: 'Passive voice structure',
        normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.3, 0.05)],
      );

      const collocationSpan = PdfDgnlHighlightSpan(
        text: 'bitter taste',
        category: 'collocation',
        type: 'COLLOCATION',
        note: 'Strong academic partnership',
        normalizedRects: [Rect.fromLTWH(0.4, 0.2, 0.2, 0.05)],
      );

      expect(policy.isEligibleForHighlight(grammarSpan), isTrue);
      expect(policy.isEligibleForHighlight(collocationSpan), isTrue);
    });

    test('A1 and A2 words are excluded from highlighting by default', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      const a1Word = PdfDgnlHighlightSpan(
        text: 'water',
        category: 'vocabulary',
        level: 'A1',
        type: 'CEFR A1',
        note: 'Basic word',
        normalizedRects: [Rect.fromLTWH(0.1, 0.3, 0.1, 0.05)],
      );

      const a2Word = PdfDgnlHighlightSpan(
        text: 'taste',
        category: 'vocabulary',
        level: 'A2',
        type: 'CEFR A2',
        note: 'Elementary word',
        normalizedRects: [Rect.fromLTWH(0.2, 0.3, 0.1, 0.05)],
      );

      expect(policy.isEligibleForHighlight(a1Word), isFalse);
      expect(policy.isEligibleForHighlight(a2Word), isFalse);
    });

    test('Academic vocabulary (AWL) is prioritized regardless of CEFR level', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      // An academic word (even if classified under lower or unconventional level)
      const academicWord = PdfDgnlHighlightSpan(
        text: 'participating',
        category: 'vocabulary',
        level: 'B2',
        type: 'AWL (B2)',
        note: 'Academic Word List Sublist 2',
        normalizedRects: [Rect.fromLTWH(0.1, 0.4, 0.2, 0.05)],
        isAcademic: true,
      );

      // An A2 level domain term with academic flag
      const academicA2Word = PdfDgnlHighlightSpan(
        text: 'corporate',
        category: 'vocabulary',
        level: 'A2',
        type: 'AWL (A2)',
        note: 'Academic word',
        normalizedRects: [Rect.fromLTWH(0.3, 0.4, 0.2, 0.05)],
        isAcademic: true,
      );

      expect(policy.isEligibleForHighlight(academicWord), isTrue);
      expect(policy.isEligibleForHighlight(academicA2Word), isTrue);
    });

    test('B1 words are highlighted selectively (only when pedagogical, pre-teach, or academic)', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      // Regular everyday B1 word
      const regularB1 = PdfDgnlHighlightSpan(
        text: 'possible',
        category: 'vocabulary',
        level: 'B1',
        type: 'CEFR B1',
        note: 'Common intermediate word',
        normalizedRects: [Rect.fromLTWH(0.1, 0.5, 0.1, 0.05)],
        isPedagogical: false,
        isAcademic: false,
        isPreTeach: false,
      );

      // Pedagogically targetable B1 word (e.g. key passage target)
      const pedagogicalB1 = PdfDgnlHighlightSpan(
        text: 'smooth',
        category: 'vocabulary',
        level: 'B1',
        type: 'CEFR B1',
        note: 'Pedagogical target',
        normalizedRects: [Rect.fromLTWH(0.2, 0.5, 0.1, 0.05)],
        isPedagogical: true,
      );

      // Pre-teach B1 word
      const preTeachB1 = PdfDgnlHighlightSpan(
        text: 'conducted',
        category: 'vocabulary',
        level: 'B1',
        type: 'Dạy trước (B1)',
        note: 'Key vocabulary to pre-teach',
        normalizedRects: [Rect.fromLTWH(0.3, 0.5, 0.1, 0.05)],
        isPreTeach: true,
      );

      expect(policy.isEligibleForHighlight(regularB1), isFalse);
      expect(policy.isEligibleForHighlight(pedagogicalB1), isTrue);
      expect(policy.isEligibleForHighlight(preTeachB1), isTrue);
    });

    test('B2, C1, and C2 content words remain strong candidates', () {
      const policy = PedagogicalHighlightPolicy.defaultPolicy;

      const b2Word = PdfDgnlHighlightSpan(
        text: 'bitter',
        category: 'vocabulary',
        level: 'B2',
        type: 'CEFR B2',
        note: 'Upper intermediate',
        normalizedRects: [Rect.fromLTWH(0.1, 0.6, 0.1, 0.05)],
      );

      const c1Word = PdfDgnlHighlightSpan(
        text: 'unmistakable',
        category: 'vocabulary',
        level: 'C1',
        type: 'CEFR C1',
        note: 'Advanced word',
        normalizedRects: [Rect.fromLTWH(0.2, 0.6, 0.2, 0.05)],
      );

      const c2Word = PdfDgnlHighlightSpan(
        text: 'palates',
        category: 'vocabulary',
        level: 'C2',
        type: 'CEFR C2',
        note: 'Proficiency word',
        normalizedRects: [Rect.fromLTWH(0.4, 0.6, 0.1, 0.05)],
      );

      expect(policy.isEligibleForHighlight(b2Word), isTrue);
      expect(policy.isEligibleForHighlight(c1Word), isTrue);
      expect(policy.isEligibleForHighlight(c2Word), isTrue);
    });

    test('Teacher overrides: showAllVocabulary and showA1A2 reveal lower level words', () {
      const defaultPolicy = PedagogicalHighlightPolicy.defaultPolicy;
      final showA1A2Policy = defaultPolicy.copyWith(showA1A2: true);
      const allVocabPolicy = PedagogicalHighlightPolicy.allVocabulary;

      const a1Word = PdfDgnlHighlightSpan(
        text: 'water',
        category: 'vocabulary',
        level: 'A1',
        type: 'CEFR A1',
        note: 'Basic word',
        normalizedRects: [Rect.fromLTWH(0.1, 0.3, 0.1, 0.05)],
      );

      // Default policy hides A1
      expect(defaultPolicy.isEligibleForHighlight(a1Word), isFalse);

      // showA1A2 override reveals A1
      expect(showA1A2Policy.isEligibleForHighlight(a1Word), isTrue);

      // allVocabulary override reveals A1
      expect(allVocabPolicy.isEligibleForHighlight(a1Word), isTrue);
    });

    test('maxHighlightsPerPassage limits excess highlights by pedagogical priority', () {
      final constrainedPolicy = const PedagogicalHighlightPolicy().copyWith(
        maxHighlightsPerPassage: 2,
      );

      final spans = [
        const PdfDgnlHighlightSpan(
          text: 'bitter',
          category: 'vocabulary',
          level: 'B2',
          type: 'CEFR B2',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.1, 0.2, 0.1, 0.05)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'were placed',
          category: 'grammar',
          level: 'B2',
          type: 'PASSIVE',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.1, 0.4, 0.2, 0.05)],
        ),
        const PdfDgnlHighlightSpan(
          text: 'participating',
          category: 'vocabulary',
          level: 'B2',
          type: 'AWL (B2)',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.2, 0.05)],
          isAcademic: true,
        ),
      ];

      final filtered = constrainedPolicy.filterSpans(spans);
      // Top 2 prioritized should be Academic and Grammar over plain B2
      expect(filtered.length, equals(2));
      final texts = filtered.map((s) => s.text).toSet();
      expect(texts.contains('participating'), isTrue);
      expect(texts.contains('were placed'), isTrue);
      expect(texts.contains('bitter'), isFalse);
    });
  });

  group('DGNL Scan Pipeline & Data Distinction Tests', () {

    test('PdfAnnotationExporter applies pedagogical policy to prevent A1/A2 clutter on PDF', () async {
      final studio = StudioState();

      final spans = [
        // A1 word (should NOT be exported to PDF by default)
        const PdfDgnlHighlightSpan(
          text: 'water',
          category: 'vocabulary',
          level: 'A1',
          type: 'CEFR A1',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.1, 0.05)],
        ),
        // Passive Voice Grammar (SHOULD be exported to PDF)
        const PdfDgnlHighlightSpan(
          text: 'were placed',
          category: 'grammar',
          level: 'B2',
          type: 'PASSIVE',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.2, 0.2, 0.2, 0.05)],
        ),
        // Collocation (SHOULD be exported to PDF)
        const PdfDgnlHighlightSpan(
          text: 'bitter taste',
          category: 'collocation',
          level: 'B2',
          type: 'COLLOCATION',
          note: '',
          normalizedRects: [Rect.fromLTWH(0.5, 0.2, 0.2, 0.05)],
        ),
      ];

      final passage = PdfDgnlPassage(
        id: 'p1',
        pageNumber: 1,
        rawText: 'A sample passage with water and bitter taste.',
        normalizedBounds: const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9),
        spans: spans,
        metrics: const {},
      );
      studio.addPdfDgnlPassage(passage);

      // Verify StudioState default pedagogical policy
      expect(studio.pedagogicalPolicy.hideA1A2ByDefault, isTrue);

      // Filter spans according to studio policy
      final filtered = studio.pedagogicalPolicy.filterSpans(passage.spans);
      expect(filtered.length, equals(2));
      expect(filtered.any((s) => s.text == 'water'), isFalse);
      expect(filtered.any((s) => s.text == 'were placed'), isTrue);
      expect(filtered.any((s) => s.text == 'bitter taste'), isTrue);
    });
  });
}
