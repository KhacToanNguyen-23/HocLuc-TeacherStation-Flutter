import 'dart:math' as math;

import '../models/text_profile_models.dart';
import 'cefr_profiler.dart';
import 'exam_profiler.dart';
import 'lexical_diversity_calculator.dart';
import 'readability_calculator.dart';
import 'syllable_counter.dart';
import 'syntactic_complexity_analyzer.dart';
import 'teacher_recommendation_engine.dart';
import 'text_tokenizer.dart';

class TextProfilerService {
  /// Profiles an English text passage locally and deterministically.
  /// Works completely offline without requiring an AI API or remote service.
  static TextProfileResult profile(String rawText) {
    final text = rawText.trim();
    final sentences = TextTokenizer.extractSentences(text);
    final rawSpans = TextTokenizer.extractWordSpans(text);

    // 1. CEFR & Word Token Classification
    final cefrOutput = CefrProfiler.profileTokens(text, rawSpans);
    final tokens = cefrOutput.tokens;
    final cefrCounts = cefrOutput.counts;
    final cefrPercentages = cefrOutput.percentages;
    final coverage = cefrOutput.coverage;

    // 2. Aggregate Character & Syllable Statistics
    int totalLetters = 0;
    int totalSyllables = 0;
    int totalPolysyllables = 0;
    int totalComplexWords = 0;

    for (final token in tokens) {
      final clean = token.clean;
      totalLetters += clean.length;
      totalSyllables += token.syllables;

      if (SyllableCounter.isPolysyllabic(clean)) {
        totalPolysyllables++;
      }
      if (SyllableCounter.isComplexWord(
        clean,
        isProperNoun: token.isProperNoun,
      )) {
        totalComplexWords++;
      }
    }

    final totalWords = tokens.length;
    final sentenceCount = math.max(1, sentences.length);
    final avgWordLen = totalWords > 0
        ? double.parse((totalLetters / totalWords).toStringAsFixed(1))
        : 0.0;
    final avgSentenceLen = totalWords > 0
        ? double.parse((totalWords / sentenceCount).toStringAsFixed(1))
        : 0.0;

    final stats = TextStatistics(
      totalCharacters: text.length,
      totalLetters: totalLetters,
      totalWords: totalWords,
      totalSentences: sentences.length,
      totalSyllables: totalSyllables,
      totalPolysyllables: totalPolysyllables,
      totalComplexWords: totalComplexWords,
      avgWordLength: avgWordLen,
      avgSentenceLength: avgSentenceLen,
    );

    // 3. Readability Metrics
    final readability = ReadabilityCalculator.calculateMetrics(stats);

    // 4. Lexical Diversity (TTR, MATTR, MTLD, AWL)
    final diversity = LexicalDiversityCalculator.calculate(tokens);

    // 5. Syntactic Complexity
    final syntax = SyntacticComplexityAnalyzer.analyze(text, sentences);

    // 6. Teacher Recommendations
    final recommendations = TeacherRecommendationEngine.generate(
      stats: stats,
      cefrPercentages: cefrPercentages,
      readability: readability,
      diversity: diversity,
      syntax: syntax,
      coverage: coverage,
    );

    // 7. Exam-Oriented Profiles (VSTEP & ĐGNL)
    final examProfiles = ExamProfiler.evaluateExams(
      stats: stats,
      cefrPercentages: cefrPercentages,
      readability: readability,
      diversity: diversity,
      syntax: syntax,
    );

    return TextProfileResult(
      originalText: text,
      statistics: stats,
      tokens: tokens,
      cefrCounts: cefrCounts,
      cefrPercentages: cefrPercentages,
      readabilityMetrics: readability,
      lexicalDiversity: diversity,
      syntacticComplexity: syntax,
      vocabularyCoverage: coverage,
      recommendations: recommendations,
      examProfiles: examProfiles,
      analyzedAt: DateTime.now(),
      isShortText: totalWords < 15,
    );
  }
}
