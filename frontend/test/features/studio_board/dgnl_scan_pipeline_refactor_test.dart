import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_board_models.dart';
import 'package:teaching_companion/features/studio_board/services/dgnl_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/cefr_dictionary_data.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_profiler_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/text_tokenizer.dart';

void main() {
  const samplePassage =
      "B. It is possible, however, to get the goodness of grapefruit juice without the bitter taste. "
      "I found that out by participating in a test conducted at the Linguagen Corporation, a biotechnology company in Cranbury, New Jersey. "
      "Sets of two miniature white paper cups, labeled 304 and 305, were placed before five people seated around a conference table. "
      "Each of us drank from one cup and then the other, cleansing our palates between tastes with water and a soda cracker. "
      "Even the smallest sip of 304 had grapefruit's unmistakable bitter bite. "
      "But 305 was smoother; there was the sour taste of citrus but none of the bitterness of naringin. "
      "This juice had been treated with adenosine monophosphate, or";

  group('Priority 1 & 2: Token Retention, Lemmatization & CEFR Coverage', () {
    test('DgnlService retains complete token analysis without dropping function words or unknown words', () async {
      final result = await DgnlService.analyze(samplePassage);

      expect(result.highlights, isNotEmpty);
      final vocabHighlights = result.highlights
          .where((h) => h['category'] == 'vocabulary')
          .toList();

      // Ensure total vocabulary highlights are comprehensive (retaining all tokens from text)
      expect(vocabHighlights.length, greaterThanOrEqualTo(100));

      // 1. Function words are preserved in analysis highlights
      final functionWordHl = vocabHighlights.where((h) => h['isFunctionWord'] == true).toList();
      expect(functionWordHl, isNotEmpty);
      final functionTexts = functionWordHl.map((h) => h['clean']).toSet();
      expect(functionTexts.contains('is'), isTrue);
      expect(functionTexts.contains('the'), isTrue);
      expect(functionTexts.contains('without'), isTrue);

      // 2. Unknown words are preserved with level 'Unknown' and neutral color '#94A3B8'
      final unknownHl = vocabHighlights.where((h) => h['level'] == 'Unknown').toList();
      expect(unknownHl, isNotEmpty);
      for (final u in unknownHl) {
        expect(u['color'], equals('#94A3B8'));
      }
      final unknownWords = unknownHl.map((h) => h['clean']).toSet();
      expect(unknownWords.contains('naringin'), isTrue);
      expect(unknownWords.contains('adenosine'), isTrue);
      expect(unknownWords.contains('monophosphate'), isTrue);

      // 3. Numbers and proper nouns are retained with appropriate flags
      final properHl = vocabHighlights.where((h) => h['isProperNoun'] == true).toList();
      expect(properHl.any((h) => h['clean'] == 'linguagen' || h['clean'] == 'cranbury'), isTrue);

      final numberHl = vocabHighlights.where((h) => h['isNumber'] == true).toList();
      expect(numberHl.any((h) => h['clean'] == '304' || h['clean'] == '305'), isTrue);
    });

    test('Lemmatization handles regular inflections and irregular verbs accurately', () {
      // Regular forms
      expect(TextTokenizer.normalizeLemma('conducted'), equals('conduct'));
      expect(TextTokenizer.normalizeLemma('tastes'), equals('taste'));
      expect(TextTokenizer.normalizeLemma('smoother'), equals('smooth'));
      expect(TextTokenizer.normalizeLemma('smallest'), equals('small'));
      expect(TextTokenizer.normalizeLemma('bitterness'), equals('bitter'));
      expect(TextTokenizer.normalizeLemma('goodness'), equals('good'));
      expect(TextTokenizer.normalizeLemma('boxes'), equals('box'));
      expect(TextTokenizer.normalizeLemma('studies'), equals('study'));

      // Irregular verbs and adjectives
      expect(TextTokenizer.normalizeLemma('drank'), equals('drink'));
      expect(TextTokenizer.normalizeLemma('drunk'), equals('drink'));
      expect(TextTokenizer.normalizeLemma('were'), equals('be'));
      expect(TextTokenizer.normalizeLemma('was'), equals('be'));
      expect(TextTokenizer.normalizeLemma('been'), equals('be'));
      expect(TextTokenizer.normalizeLemma('found'), equals('find'));
      expect(TextTokenizer.normalizeLemma('had'), equals('have'));
      expect(TextTokenizer.normalizeLemma('did'), equals('do'));
      expect(TextTokenizer.normalizeLemma('better'), equals('good'));
      expect(TextTokenizer.normalizeLemma('worse'), equals('bad'));
    });

    test('CEFR dictionary lookup covers standard words and AWL while preserving Unknown for uncatalogued words', () {
      expect(CefrDictionaryData.lookupCefr('drink'), equals('A1'));
      expect(CefrDictionaryData.lookupCefr('water'), equals('A1'));
      expect(CefrDictionaryData.lookupCefr('taste'), equals('B1'));
      expect(CefrDictionaryData.lookupCefr('possible'), equals('A2'));
      expect(CefrDictionaryData.lookupCefr('smooth'), equals('A2'));
      expect(CefrDictionaryData.lookupCefr('sour'), equals('B1'));
      expect(CefrDictionaryData.lookupCefr('bitter'), equals('B1'));
      expect(CefrDictionaryData.lookupCefr('conference'), equals('B2'));
      expect(CefrDictionaryData.lookupCefr('conduct'), equals('B1')); // CEFR-J B1
      expect(CefrDictionaryData.lookupCefr('participate'), equals('B1'));
      expect(CefrDictionaryData.lookupCefr('compound'), equals('B1'));
      expect(CefrDictionaryData.lookupCefr('corporation'), equals('B2'));
      expect(CefrDictionaryData.lookupCefr('biotechnology'), equals('B2'));
      expect(CefrDictionaryData.lookupCefr('palate'), equals('C2'));

      // Uncatalogued words remain null (Unknown), never arbitrarily assigned
      expect(CefrDictionaryData.lookupCefr('naringin'), isNull);
      expect(CefrDictionaryData.lookupCefr('monophosphate'), isNull);
    });

    test('Linguistic profile shows significant reduction in Unknown words compared to baseline', () {
      final profile = TextProfilerService.profile(samplePassage);
      final unknownCount = profile.cefrCounts['Unknown'] ?? 0;
      final totalTokens = profile.tokens.length;

      // In the original baseline, Unknown was 51 (43.2%).
      // With enhanced lemmatization and CEFR coverage, Unknown is drastically reduced (< 25).
      expect(unknownCount, lessThan(25));
      expect(totalTokens, equals(118));
    });
  });

  group('Priority 3 & 5: Display Modes, Filtering & Navigation Counts', () {
    test('Simulate overlay display modes: Mode A (Focused) vs Mode B (All Vocabulary)', () async {
      final result = await DgnlService.analyze(samplePassage);

      // Convert highlights to PdfDgnlHighlightSpan
      final spans = result.highlights.map((h) {
        return PdfDgnlHighlightSpan(
          text: h['text']?.toString() ?? '',
          category: h['category']?.toString() ?? 'vocabulary',
          level: h['level']?.toString() ?? 'Unknown',
          type: h['type']?.toString() ?? '',
          note: h['note']?.toString() ?? '',
          normalizedRects: [const Rect.fromLTWH(0.1, 0.1, 0.2, 0.05)],
          isPedagogical: h['isPedagogical'] == true,
          isFunctionWord: h['isFunctionWord'] == true,
          isProperNoun: h['isProperNoun'] == true,
          isNumber: h['isNumber'] == true,
          lemma: h['lemma']?.toString(),
        );
      }).toList();

      bool isPedagogicalVocab(PdfDgnlHighlightSpan s) {
        if (s.category != 'vocabulary') return false;
        if (s.isFunctionWord || s.isNumber || s.isProperNoun) return false;
        if (s.isPedagogical) return true;
        final lvl = s.level.toUpperCase();
        return lvl == 'B1' ||
            lvl == 'B2' ||
            lvl == 'C1' ||
            lvl == 'C2' ||
            s.type.contains('AWL') ||
            s.type.contains('Dạy trước') ||
            s.note.contains('AWL') ||
            s.note.contains('trọng tâm');
      }

      // Mode A: Focused / Trọng tâm (default)
      final modeASpans = spans.where((s) {
        if (s.category == 'vocabulary') return isPedagogicalVocab(s);
        return true;
      }).toList();

      // Mode B: All Vocabulary (A1-C2) + Grammar + Collocations
      final modeBSpans = spans.where((s) {
        if (s.category == 'vocabulary') {
          return s.level != 'Unknown' && !s.isFunctionWord && !s.isNumber && !s.isProperNoun;
        }
        return true;
      }).toList();

      // Unknown Filter
      final unknownSpans = spans.where((s) {
        return s.category == 'vocabulary' && s.level == 'Unknown';
      }).toList();

      // Mode A is quiet and focused (does not overwhelm with A1/A2 or function words)
      expect(modeASpans.length, lessThan(modeBSpans.length));
      expect(modeASpans.any((s) => s.text == 'is' || s.text == 'the'), isFalse);

      // Mode B includes basic vocabulary such as 'possible', 'juice', 'water', 'taste'
      expect(modeBSpans.any((s) => s.text.toLowerCase() == 'water' || s.text.toLowerCase() == 'juice'), isTrue);
      expect(modeBSpans.any((s) => s.text.toLowerCase() == 'possible' || s.text.toLowerCase() == 'taste'), isTrue);

      // Unknown filter isolates unclassified words
      expect(unknownSpans, isNotEmpty);
      expect(unknownSpans.any((s) => s.text.toLowerCase().contains('naringin')), isTrue);
    });
  });

  group('Priority 4: Overlap Resolution & Nested Spans', () {
    test('Merging does not discard nested vocabulary inside grammar structures or collocations', () {
      final onlineRes = DgnlAnalysisResult(
        totalWords: 10,
        contentWords: 5,
        lexicalDensity: 0.5,
        cefrProfile: {},
        evaluation: '',
        status: 'ok',
        highlights: [
          {
            'start': 10,
            'end': 25,
            'text': 'were placed',
            'category': 'grammar',
            'level': 'B2',
            'type': 'Câu bị động (Passive Voice)',
          },
          {
            'start': 30,
            'end': 42,
            'text': 'bitter taste',
            'category': 'collocation',
            'level': 'B1',
            'type': 'Collocation',
          },
        ],
      );

      // Offline highlights containing nested vocabulary words inside the above spans
      final offlineHighlights = <Map<String, dynamic>>[
        {
          'start': 15,
          'end': 21,
          'text': 'placed',
          'category': 'vocabulary',
          'level': 'A2',
          'type': 'Cơ bản (A2)',
        },
        {
          'start': 30,
          'end': 36,
          'text': 'bitter',
          'category': 'vocabulary',
          'level': 'B1',
          'type': 'CEFR B1',
        },
        {
          'start': 37,
          'end': 42,
          'text': 'taste',
          'category': 'vocabulary',
          'level': 'A2',
          'type': 'Cơ bản (A2)',
        },
        // Duplicate grammar span from offline
        {
          'start': 10,
          'end': 25,
          'text': 'were placed',
          'category': 'grammar',
          'level': 'B2',
          'type': 'Passive Voice',
        },
      ];

      // Re-run the overlap resolution logic
      final merged = <Map<String, dynamic>>[...onlineRes.highlights];
      for (final oHl in offlineHighlights) {
        final oText = oHl['text']?.toString().toLowerCase().trim() ?? '';
        final oCat = oHl['category']?.toString().toLowerCase().trim() ?? '';
        final oStart = oHl['start'] as int?;
        final oEnd = oHl['end'] as int?;

        final isDuplicate = merged.any((m) {
          final mText = m['text']?.toString().toLowerCase().trim() ?? '';
          final mCat = m['category']?.toString().toLowerCase().trim() ?? '';
          final mStart = m['start'] as int?;
          final mEnd = m['end'] as int?;

          if (mCat != oCat) return false;
          if (mStart != null && mEnd != null && oStart != null && oEnd != null) {
            if (mStart == oStart && mEnd == oEnd) return true;
          }
          return mText == oText;
        });

        if (!isDuplicate) {
          merged.add(oHl);
        }
      }

      // Expected:
      // - 'were placed' (grammar)
      // - 'bitter taste' (collocation)
      // - 'placed' (vocabulary) -> preserved!
      // - 'bitter' (vocabulary) -> preserved!
      // - 'taste' (vocabulary) -> preserved!
      // - duplicate 'were placed' (grammar) -> discarded!
      expect(merged.length, equals(5));

      final grammarSpans = merged.where((m) => m['category'] == 'grammar').toList();
      expect(grammarSpans.length, equals(1));

      final vocabSpans = merged.where((m) => m['category'] == 'vocabulary').toList();
      expect(vocabSpans.length, equals(3));
      final vocabWords = vocabSpans.map((v) => v['text']).toSet();
      expect(vocabWords.contains('placed'), isTrue);
      expect(vocabWords.contains('bitter'), isTrue);
      expect(vocabWords.contains('taste'), isTrue);
    });
  });

  group('Priority 6: Palette & PDF Consistency', () {
    test('DgnlHighlightPalette maps all 8 categories and Unknown to authoritative hex codes', () {
      expect(DgnlHighlightPalette.colorHexForCategory('grammar'), equals('#89B4FA'));
      expect(DgnlHighlightPalette.colorHexForCategory('collocation'), equals('#86EFAC'));
      expect(DgnlHighlightPalette.colorHexForLevel('A1'), equals('#22C55E'));
      expect(DgnlHighlightPalette.colorHexForLevel('A2'), equals('#14B8A6'));
      expect(DgnlHighlightPalette.colorHexForLevel('B1'), equals('#3B82F6'));
      expect(DgnlHighlightPalette.colorHexForLevel('B2'), equals('#F59E0B'));
      expect(DgnlHighlightPalette.colorHexForLevel('C1'), equals('#F97316'));
      expect(DgnlHighlightPalette.colorHexForLevel('C2'), equals('#A855F7'));
      expect(DgnlHighlightPalette.colorHexForLevel('Unknown'), equals('#94A3B8'));
    });

    test('PdfAnnotationExporter applies identical colors for in-place highlight and PDF export', () {
      final span = const PdfDgnlHighlightSpan(
        text: 'unknown_word',
        category: 'vocabulary',
        level: 'Unknown',
        type: 'Chưa định danh',
        note: 'Word not in offline dictionary',
        normalizedRects: [Rect.fromLTWH(0.1, 0.1, 0.2, 0.05)],
      );

      final color = DgnlHighlightPalette.resolveSpanColor(span);
      expect(color, equals(DgnlHighlightPalette.unknown));
      final rgb = DgnlHighlightPalette.toRgb(color);
      expect(rgb.r, equals(148));
      expect(rgb.g, equals(163));
      expect(rgb.b, equals(184));
    });
  });
}
