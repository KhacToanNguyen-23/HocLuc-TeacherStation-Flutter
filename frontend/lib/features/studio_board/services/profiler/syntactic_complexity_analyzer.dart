import '../../domain/models/text_profile_models.dart';
import 'text_tokenizer.dart';

class SyntacticComplexityAnalyzer {
  static final RegExp _coordinatingConjunctions = RegExp(
    r'\b(and|but|or|so|yet|for|nor)\b',
    caseSensitive: false,
  );

  static final RegExp _subordinatingConjunctions = RegExp(
    r'\b(because|although|even though|though|while|whereas|since|if|unless|provided that|after|before|as soon as|as long as|in order that|so that|despite|in spite of)\b',
    caseSensitive: false,
  );

  static final RegExp _relativePronouns = RegExp(
    r'\b(who|whom|whose|which|that)\b',
    caseSensitive: false,
  );

  static final RegExp _passiveVoicePattern = RegExp(
    r'\b(is|are|am|was|were|been|being|be)\s+([a-z]+ed|[a-z]+en|shown|known|given|built|made|written|caught|found|bought|sold|brought|taught|held|chosen)\b',
    caseSensitive: false,
  );

  static final RegExp _inversionOrParticiplePattern = RegExp(
    r'\b(hardly|scarcely|no sooner|seldom|rarely|not only|having\s+[a-z]+(?:ed|en))\b',
    caseSensitive: false,
  );

  /// Analyzes sentence length distribution, clause structures, and syntactic complexity.
  static SyntacticComplexityResult analyze(String text, List<String> rawSentences) {
    if (rawSentences.isEmpty) {
      return const SyntacticComplexityResult(
        sentenceCount: 0,
        avgSentenceLength: 0.0,
        minSentenceLength: 0,
        maxSentenceLength: 0,
        shortSentences: 0,
        mediumSentences: 0,
        longSentences: 0,
        simpleSentenceCount: 0,
        compoundSentenceCount: 0,
        complexSentenceCount: 0,
        compoundComplexSentenceCount: 0,
        passiveVoiceCount: 0,
        relativeClauseCount: 0,
        subordinateClauseCount: 0,
        challengingStructures: [],
      );
    }

    int shortCount = 0;
    int mediumCount = 0;
    int longCount = 0;
    int minLength = 999999;
    int maxLength = 0;
    int totalWordsAcrossSentences = 0;

    int simpleCount = 0;
    int compoundCount = 0;
    int complexCount = 0;
    int compoundComplexCount = 0;
    int totalPassiveCount = 0;
    int totalRelativeClauseCount = 0;
    int totalSubordinateCount = 0;
    final challenging = <String>[];

    for (final sent in rawSentences) {
      final words = TextTokenizer.extractWordSpans(sent);
      final wordCount = words.length;
      if (wordCount == 0) continue;

      totalWordsAcrossSentences += wordCount;
      if (wordCount < minLength) minLength = wordCount;
      if (wordCount > maxLength) maxLength = wordCount;

      // Sentence Length Distribution
      if (wordCount < 12) {
        shortCount++;
      } else if (wordCount <= 25) {
        mediumCount++;
      } else {
        longCount++;
        challenging.add('Câu dài ($wordCount từ): "${sent.length > 60 ? "${sent.substring(0, 57)}..." : sent}"');
      }

      // Clause Pattern Detection
      final hasCoord = _coordinatingConjunctions.hasMatch(sent);
      final hasSubord = _subordinatingConjunctions.hasMatch(sent);
      final hasRel = _relativePronouns.hasMatch(sent);
      final hasComplexClause = hasSubord || hasRel;

      if (hasCoord && hasComplexClause) {
        compoundComplexCount++;
      } else if (hasComplexClause) {
        complexCount++;
      } else if (hasCoord) {
        compoundCount++;
      } else {
        simpleCount++;
      }

      // Syntactic Patterns
      final passives = _passiveVoicePattern.allMatches(sent).length;
      totalPassiveCount += passives;

      final relMatches = _relativePronouns.allMatches(sent).length;
      totalRelativeClauseCount += relMatches;

      final subMatches = _subordinatingConjunctions.allMatches(sent).length;
      totalSubordinateCount += subMatches;

      if (_inversionOrParticiplePattern.hasMatch(sent)) {
        challenging.add('Cấu trúc đảo ngữ / phân từ hoàn thành: "${sent.length > 50 ? "${sent.substring(0, 47)}..." : sent}"');
      }
    }

    if (minLength == 999999) minLength = 0;
    final avgLength = rawSentences.isNotEmpty
        ? double.parse((totalWordsAcrossSentences / rawSentences.length).toStringAsFixed(1))
        : 0.0;

    return SyntacticComplexityResult(
      sentenceCount: rawSentences.length,
      avgSentenceLength: avgLength,
      minSentenceLength: minLength,
      maxSentenceLength: maxLength,
      shortSentences: shortCount,
      mediumSentences: mediumCount,
      longSentences: longCount,
      simpleSentenceCount: simpleCount,
      compoundSentenceCount: compoundCount,
      complexSentenceCount: complexCount,
      compoundComplexSentenceCount: compoundComplexCount,
      passiveVoiceCount: totalPassiveCount,
      relativeClauseCount: totalRelativeClauseCount,
      subordinateClauseCount: totalSubordinateCount,
      challengingStructures: challenging,
    );
  }
}
