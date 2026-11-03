import 'dart:math' as math;

import '../models/text_profile_models.dart';

class LexicalDiversityCalculator {
  static const Set<String> _stopWords = {
    'the',
    'be',
    'to',
    'of',
    'and',
    'a',
    'in',
    'that',
    'have',
    'i',
    'it',
    'for',
    'not',
    'on',
    'with',
    'he',
    'as',
    'you',
    'do',
    'at',
    'this',
    'but',
    'his',
    'by',
    'from',
    'they',
    'we',
    'say',
    'her',
    'she',
    'or',
    'an',
    'will',
    'my',
    'one',
    'all',
    'would',
    'there',
    'their',
    'what',
    'so',
    'up',
    'out',
    'if',
    'about',
    'who',
    'get',
    'which',
    'go',
    'me',
    'is',
    'are',
    'was',
    'were',
    'been',
    'has',
    'had',
    'did',
    'does',
  };

  /// Calculates TTR, MATTR, MTLD, and academic vocabulary usage.
  static LexicalDiversityResult calculate(List<WordTokenInfo> tokens) {
    if (tokens.isEmpty) {
      return const LexicalDiversityResult(
        ttr: 0.0,
        ttrInterpretation: 'Văn bản rỗng.',
        mattr: 0.0,
        mtld: 0.0,
        uniqueWordCount: 0,
        totalTokens: 0,
        topRepeatedWords: [],
        academicWordCount: 0,
        academicPercentage: 0.0,
        academicWords: [],
      );
    }

    final lemmas = tokens.map((t) => t.lemma.toLowerCase()).toList();
    final totalTokens = lemmas.length;
    final uniqueLemmas = lemmas.toSet();
    final uniqueCount = uniqueLemmas.length;

    // 1. Raw Type-Token Ratio (TTR)
    final ttr = double.parse((uniqueCount / totalTokens).toStringAsFixed(3));
    final String ttrInterpretation = totalTokens > 100
        ? 'Chỉ số TTR đạt $ttr ($uniqueCount từ vựng khác nhau trên $totalTokens lượt từ). Lưu ý: TTR thô có xu hướng giảm tự nhiên khi văn bản dài hơn.'
        : 'Chỉ số TTR đạt $ttr ($uniqueCount/$totalTokens từ). Đối với đoạn văn ngắn, TTR phản ánh độ đa dạng từ vựng ban đầu.';

    // 2. Moving-Average Type-Token Ratio (MATTR)
    // Computes TTR over a fixed window (e.g. 25 tokens) sliding by 1 token
    final windowSize = math.min(25, totalTokens);
    double mattrSum = 0.0;
    final windowCount = totalTokens - windowSize + 1;

    for (int i = 0; i < windowCount; i++) {
      final windowLemmas = lemmas.sublist(i, i + windowSize).toSet();
      mattrSum += windowLemmas.length / windowSize;
    }
    final mattr = double.parse(
      (mattrSum / math.max(1, windowCount)).toStringAsFixed(3),
    );

    // 3. Measure of Textual Lexical Diversity (MTLD)
    // Standard factor threshold = 0.72. Calculates average segment length to reach threshold.
    final mtldForward = _computeMtldDirection(lemmas, 0.72);
    final mtldBackward = _computeMtldDirection(lemmas.reversed.toList(), 0.72);
    final mtld = double.parse(
      ((mtldForward + mtldBackward) / 2.0).toStringAsFixed(1),
    );

    // 4. Repeated Content Words
    final frequencyMap = <String, int>{};
    for (final l in lemmas) {
      if (!_stopWords.contains(l) &&
          l.length > 2 &&
          !RegExp(r'^\d+$').hasMatch(l)) {
        frequencyMap[l] = (frequencyMap[l] ?? 0) + 1;
      }
    }
    final sortedRepeated = frequencyMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topRepeated = sortedRepeated.take(8).toList();

    // 5. Academic Word List (AWL) usage
    final academicTokens = tokens.where((t) => t.isAcademic).toList();
    final academicCount = academicTokens.length;
    final academicPct = double.parse(
      ((academicCount / totalTokens) * 100).toStringAsFixed(1),
    );
    final academicUniqueList =
        academicTokens.map((t) => t.lemma).toSet().toList()..sort();

    return LexicalDiversityResult(
      ttr: ttr,
      ttrInterpretation: ttrInterpretation,
      mattr: mattr,
      mtld: mtld,
      uniqueWordCount: uniqueCount,
      totalTokens: totalTokens,
      topRepeatedWords: topRepeated,
      academicWordCount: academicCount,
      academicPercentage: academicPct,
      academicWords: academicUniqueList,
    );
  }

  /// Evaluates MTLD in one direction.
  static double _computeMtldDirection(List<String> words, double threshold) {
    if (words.isEmpty) return 0.0;

    double factorCount = 0.0;
    final currentTypes = <String>{};
    int currentTokenCount = 0;

    for (final w in words) {
      currentTypes.add(w);
      currentTokenCount++;
      final currentTtr = currentTypes.length / currentTokenCount;

      if (currentTtr <= threshold) {
        factorCount += 1.0;
        currentTypes.clear();
        currentTokenCount = 0;
      }
    }

    // Handle remaining partial factor
    if (currentTokenCount > 0) {
      final currentTtr = currentTypes.length / currentTokenCount;
      if (currentTtr < 1.0) {
        final partialFactor = (1.0 - currentTtr) / (1.0 - threshold);
        factorCount += partialFactor.clamp(0.0, 1.0);
      }
    }

    if (factorCount <= 0.0) return words.length.toDouble();
    return words.length / factorCount;
  }
}
