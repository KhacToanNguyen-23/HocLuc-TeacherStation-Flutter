import 'dart:math' as math;
import '../../domain/models/text_profile_models.dart';
import 'cefr_dictionary_data.dart';
import 'syllable_counter.dart';
import 'text_tokenizer.dart';

class CefrProfiler {
  /// Analyzes word spans, assigns CEFR levels and frequency bands,
  /// and isolates numbers, proper nouns, and unknown words.
  static ({
    List<WordTokenInfo> tokens,
    Map<String, int> counts,
    Map<String, double> percentages,
    VocabularyCoverageResult coverage,
  })
  profileTokens(String text, List<RawTokenSpan> rawSpans) {
    final tokens = <WordTokenInfo>[];
    final counts = <String, int>{
      'A1': 0,
      'A2': 0,
      'B1': 0,
      'B2': 0,
      'C1': 0,
      'C2': 0,
      'Unknown': 0,
    };

    final bandCounts = <String, int>{
      'K1': 0,
      'K2': 0,
      'K3': 0,
      'K4+': 0,
      'Off-list': 0,
    };

    final preTeachCandidateMap = <String, WordTokenInfo>{};

    for (int i = 0; i < rawSpans.length; i++) {
      final span = rawSpans[i];
      final surface = span.surface;
      final clean = surface.toLowerCase().replaceAll(RegExp(r"[^a-z0-9']"), '');

      if (clean.isEmpty) continue;

      // 1. Detect numbers
      final isNumber = RegExp(r'^\d+(\.\d+)?$').hasMatch(clean);
      if (isNumber) {
        final t = WordTokenInfo(
          surface: surface,
          clean: clean,
          lemma: clean,
          pos: 'NUM',
          cefrLevel: 'A1',
          frequencyBand: 'K1',
          isNumber: true,
          syllables: 1,
          startIndex: span.startIndex,
          endIndex: span.endIndex,
        );
        tokens.add(t);
        counts['A1'] = (counts['A1'] ?? 0) + 1;
        bandCounts['K1'] = (bandCounts['K1'] ?? 0) + 1;
        continue;
      }

      // 2. Detect proper nouns (capitalized mid-sentence or known capitalized titles)
      final isSentenceStart =
          i == 0 ||
          (span.startIndex > 0 &&
              text[span.startIndex - 1] == ' ' &&
              text
                  .substring(math.max(0, span.startIndex - 3), span.startIndex)
                  .contains(RegExp(r'[.!?]')));
      final isProperNoun = TextTokenizer.isProperNoun(
        surface,
        i,
        isSentenceStart,
      );

      // 3. Morphological normalization & Offline Lexeme Lookup
      final isHyphenated = surface.contains('-');
      final directLexeme = isProperNoun
          ? null
          : CefrDictionaryData.lookupLexeme(surface) ??
                (isHyphenated ? null : CefrDictionaryData.lookupLexeme(clean));

      final lemma = directLexeme?.headword ??
          TextTokenizer.normalizeTokenLemma(surface);
      final level = isProperNoun
          ? 'Unknown'
          : (directLexeme?.cefrLevel ?? 'Unknown');

      final academicMetricLevel = isProperNoun
          ? null
          : (directLexeme?.isAwlHeadword == true ||
                  (directLexeme?.awlSublist != null)
              ? (directLexeme!.awlSublist! <= 5 ? 'B2' : 'C1')
              : CefrDictionaryData.lookupAcademicMetricLevel(lemma));
      final isAcademic = academicMetricLevel != null;

      final isRecognizedUnrated =
          !isProperNoun && (directLexeme?.isUnrated ?? false);

      // 4. Frequency Band classification
      final band = isProperNoun
          ? 'Off-list'
          : (directLexeme?.frequencyBand ??
              CefrDictionaryData.getFrequencyBand(lemma, level));

      final syllables = SyllableCounter.countSyllables(clean);

      final token = WordTokenInfo(
        surface: surface,
        clean: clean,
        lemma: lemma,
        pos: isProperNoun
            ? 'PROPN'
            : (isAcademic ? 'ACAD' : (directLexeme?.defaultPos ?? 'WORD')),
        cefrLevel: level,
        frequencyBand: band,
        isProperNoun: isProperNoun,
        isNumber: false,
        isAcademic: isAcademic,
        lexicalStatus: level != 'Unknown'
            ? LexicalStatus.graded
            : isRecognizedUnrated
            ? LexicalStatus.recognizedUnrated
            : LexicalStatus.notInLexicon,
        academicMetricLevel: academicMetricLevel,
        syllables: syllables,
        startIndex: span.startIndex,
        endIndex: span.endIndex,
      );

      tokens.add(token);

      counts[level] = (counts[level] ?? 0) + 1;
      bandCounts[band] = (bandCounts[band] ?? 0) + 1;

      // Check pre-teach qualification: B2, C1, C2, or Academic words
      if (!isProperNoun &&
          (level == 'B2' || level == 'C1' || level == 'C2' || isAcademic)) {
        if (!preTeachCandidateMap.containsKey(lemma)) {
          preTeachCandidateMap[lemma] = token;
        }
      }
    }

    final total = math.max(1, tokens.length);
    final percentages = <String, double>{
      for (final entry in counts.entries)
        entry.key: double.parse(
          ((entry.value / total) * 100).toStringAsFixed(1),
        ),
    };

    final k1Pct = double.parse(
      (((bandCounts['K1'] ?? 0) / total) * 100).toStringAsFixed(1),
    );
    final k2Pct = double.parse(
      (((bandCounts['K2'] ?? 0) / total) * 100).toStringAsFixed(1),
    );
    final k3Pct = double.parse(
      (((bandCounts['K3'] ?? 0) / total) * 100).toStringAsFixed(1),
    );
    final k4Pct = double.parse(
      (((bandCounts['K4+'] ?? 0) / total) * 100).toStringAsFixed(1),
    );
    final offListPct = double.parse(
      (((bandCounts['Off-list'] ?? 0) / total) * 100).toStringAsFixed(1),
    );
    final coveredPct = double.parse(
      (k1Pct + k2Pct + k3Pct + k4Pct).toStringAsFixed(1),
    );

    // Sort pre-teach words by difficulty level (C2 > C1 > B2) then alphabetically
    final preTeachList = preTeachCandidateMap.values.toList()
      ..sort((a, b) {
        const order = {
          'C2': 4,
          'C1': 3,
          'B2': 2,
          'B1': 1,
          'A2': 0,
          'A1': 0,
          'Unknown': 0,
        };
        final diff = (order[b.cefrLevel] ?? 0).compareTo(
          order[a.cefrLevel] ?? 0,
        );
        if (diff != 0) return diff;
        return a.surface.compareTo(b.surface);
      });

    final coverage = VocabularyCoverageResult(
      k1Percent: k1Pct,
      k2Percent: k2Pct,
      k3Percent: k3Pct,
      k4PlusPercent: k4Pct,
      offListPercent: offListPct,
      coveredPercent: coveredPct,
      preTeachWords: preTeachList,
    );

    return (
      tokens: tokens,
      counts: counts,
      percentages: percentages,
      coverage: coverage,
    );
  }
}
