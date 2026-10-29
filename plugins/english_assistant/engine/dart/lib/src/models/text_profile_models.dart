/// Lexical certainty for a token after offline dictionary resolution.
enum LexicalStatus { graded, recognizedUnrated, notInLexicon }

/// Word token information after morphological and lexical classification.
class WordTokenInfo {
  final String surface;
  final String clean;
  final String lemma;
  final String pos;
  final String cefrLevel; // 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'Unknown'
  final String frequencyBand; // 'K1', 'K2', 'K3', 'K4+', 'Off-list'
  final bool isProperNoun;
  final bool isNumber;
  final bool isAcademic;
  final LexicalStatus lexicalStatus;
  bool get isRecognizedUnrated =>
      lexicalStatus == LexicalStatus.recognizedUnrated;
  final String? academicMetricLevel;
  final int syllables;
  final int startIndex;
  final int endIndex;

  const WordTokenInfo({
    required this.surface,
    required this.clean,
    required this.lemma,
    required this.pos,
    required this.cefrLevel,
    required this.frequencyBand,
    this.isProperNoun = false,
    this.isNumber = false,
    this.isAcademic = false,
    bool isRecognizedUnrated = false,
    LexicalStatus? lexicalStatus,
    this.academicMetricLevel,
    this.syllables = 1,
    this.startIndex = 0,
    this.endIndex = 0,
  }) : lexicalStatus =
           lexicalStatus ??
           (isRecognizedUnrated
               ? LexicalStatus.recognizedUnrated
               : cefrLevel == 'Unknown'
               ? LexicalStatus.notInLexicon
               : LexicalStatus.graded);

  Map<String, dynamic> toJson() => {
    'surface': surface,
    'clean': clean,
    'lemma': lemma,
    'pos': pos,
    'cefrLevel': cefrLevel,
    'frequencyBand': frequencyBand,
    'isProperNoun': isProperNoun,
    'isNumber': isNumber,
    'isAcademic': isAcademic,
    'isRecognizedUnrated': isRecognizedUnrated,
    'lexicalStatus': lexicalStatus.name,
    'academicMetricLevel': academicMetricLevel,
    'syllables': syllables,
    'startIndex': startIndex,
    'endIndex': endIndex,
  };
}

/// Basic statistical counts of the analyzed text.
class TextStatistics {
  final int totalCharacters;
  final int totalLetters;
  final int totalWords;
  final int totalSentences;
  final int totalSyllables;
  final int totalPolysyllables; // Words with >= 3 syllables
  final int totalComplexWords; // Polysyllables excluding simple inflections (-ed, -es, -ing)
  final double avgWordLength;
  final double avgSentenceLength;

  const TextStatistics({
    required this.totalCharacters,
    required this.totalLetters,
    required this.totalWords,
    required this.totalSentences,
    required this.totalSyllables,
    required this.totalPolysyllables,
    required this.totalComplexWords,
    required this.avgWordLength,
    required this.avgSentenceLength,
  });

  Map<String, dynamic> toJson() => {
    'totalCharacters': totalCharacters,
    'totalLetters': totalLetters,
    'totalWords': totalWords,
    'totalSentences': totalSentences,
    'totalSyllables': totalSyllables,
    'totalPolysyllables': totalPolysyllables,
    'totalComplexWords': totalComplexWords,
    'avgWordLength': avgWordLength,
    'avgSentenceLength': avgSentenceLength,
  };
}

/// Individual readability metric item with metadata and caveats.
class ReadabilityMetricItem {
  final String id;
  final String name;
  final double score;
  final String gradeLevelEquivalent;
  final String interpretation;
  final String formula;
  final List<String> mainFactors;
  final String limitations;
  final String references;
  final bool isReliable;
  final String reliabilityNote;

  const ReadabilityMetricItem({
    required this.id,
    required this.name,
    required this.score,
    required this.gradeLevelEquivalent,
    required this.interpretation,
    required this.formula,
    required this.mainFactors,
    required this.limitations,
    required this.references,
    this.isReliable = true,
    this.reliabilityNote = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'score': score,
    'gradeLevelEquivalent': gradeLevelEquivalent,
    'interpretation': interpretation,
    'formula': formula,
    'mainFactors': mainFactors,
    'limitations': limitations,
    'references': references,
    'isReliable': isReliable,
    'reliabilityNote': reliabilityNote,
  };
}

/// Lexical diversity calculations including TTR, MATTR, and MTLD.
class LexicalDiversityResult {
  final double ttr;
  final String ttrInterpretation;
  final double mattr;
  final double mtld;
  final int uniqueWordCount;
  final int totalTokens;
  final List<MapEntry<String, int>> topRepeatedWords;
  final int academicWordCount;
  final double academicPercentage;
  final List<String> academicWords;

  const LexicalDiversityResult({
    required this.ttr,
    required this.ttrInterpretation,
    required this.mattr,
    required this.mtld,
    required this.uniqueWordCount,
    required this.totalTokens,
    required this.topRepeatedWords,
    required this.academicWordCount,
    required this.academicPercentage,
    required this.academicWords,
  });

  Map<String, dynamic> toJson() => {
    'ttr': ttr,
    'ttrInterpretation': ttrInterpretation,
    'mattr': mattr,
    'mtld': mtld,
    'uniqueWordCount': uniqueWordCount,
    'totalTokens': totalTokens,
    'topRepeatedWords': topRepeatedWords
        .map((e) => {'word': e.key, 'count': e.value})
        .toList(),
    'academicWordCount': academicWordCount,
    'academicPercentage': academicPercentage,
    'academicWords': academicWords,
  };
}

/// Syntactic complexity breakdown and clause distribution.
class SyntacticComplexityResult {
  final int sentenceCount;
  final double avgSentenceLength;
  final int minSentenceLength;
  final int maxSentenceLength;
  final int shortSentences; // < 12 words
  final int mediumSentences; // 12-25 words
  final int longSentences; // > 25 words
  final int simpleSentenceCount;
  final int compoundSentenceCount;
  final int complexSentenceCount;
  final int compoundComplexSentenceCount;
  final int passiveVoiceCount;
  final int relativeClauseCount;
  final int subordinateClauseCount;
  final List<String> challengingStructures;

  const SyntacticComplexityResult({
    required this.sentenceCount,
    required this.avgSentenceLength,
    required this.minSentenceLength,
    required this.maxSentenceLength,
    required this.shortSentences,
    required this.mediumSentences,
    required this.longSentences,
    required this.simpleSentenceCount,
    required this.compoundSentenceCount,
    required this.complexSentenceCount,
    required this.compoundComplexSentenceCount,
    required this.passiveVoiceCount,
    required this.relativeClauseCount,
    required this.subordinateClauseCount,
    required this.challengingStructures,
  });

  Map<String, dynamic> toJson() => {
    'sentenceCount': sentenceCount,
    'avgSentenceLength': avgSentenceLength,
    'minSentenceLength': minSentenceLength,
    'maxSentenceLength': maxSentenceLength,
    'shortSentences': shortSentences,
    'mediumSentences': mediumSentences,
    'longSentences': longSentences,
    'simpleSentenceCount': simpleSentenceCount,
    'compoundSentenceCount': compoundSentenceCount,
    'complexSentenceCount': complexSentenceCount,
    'compoundComplexSentenceCount': compoundComplexSentenceCount,
    'passiveVoiceCount': passiveVoiceCount,
    'relativeClauseCount': relativeClauseCount,
    'subordinateClauseCount': subordinateClauseCount,
    'challengingStructures': challengingStructures,
  };
}

/// Vocabulary coverage across frequency bands.
class VocabularyCoverageResult {
  final double k1Percent; // Top 1000
  final double k2Percent; // 1001-2000
  final double k3Percent; // 2001-3000
  final double k4PlusPercent; // 3001+ / Academic
  final double offListPercent; // Unknown / rare
  final double coveredPercent; // K1 + K2 + K3 + K4
  final List<WordTokenInfo> preTeachWords;

  const VocabularyCoverageResult({
    required this.k1Percent,
    required this.k2Percent,
    required this.k3Percent,
    required this.k4PlusPercent,
    required this.offListPercent,
    required this.coveredPercent,
    required this.preTeachWords,
  });

  Map<String, dynamic> toJson() => {
    'k1Percent': k1Percent,
    'k2Percent': k2Percent,
    'k3Percent': k3Percent,
    'k4PlusPercent': k4PlusPercent,
    'offListPercent': offListPercent,
    'coveredPercent': coveredPercent,
    'preTeachWords': preTeachWords.map((e) => e.toJson()).toList(),
  };
}

/// Practical, deterministic teaching recommendation.
class PedagogicalRecommendation {
  final String category; // 'vocabulary', 'syntax', 'readability', 'exam'
  final String title;
  final String description;
  final String priority; // 'high', 'medium', 'low'
  final String actionableStep;

  const PedagogicalRecommendation({
    required this.category,
    required this.title,
    required this.description,
    required this.priority,
    required this.actionableStep,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'title': title,
    'description': description,
    'priority': priority,
    'actionableStep': actionableStep,
  };
}

/// Benchmark comparison against standardized exams (e.g., VSTEP, ĐGNL).
class ExamProfileComparison {
  final String examName;
  final String targetLevel;
  final String overallFit; // 'Phù hợp', 'Hơi dễ so với chuẩn', 'Thử thách cao'
  final String readabilityFit;
  final String vocabularyFit;
  final String sentenceComplexityFit;
  final String notes;

  const ExamProfileComparison({
    required this.examName,
    required this.targetLevel,
    required this.overallFit,
    required this.readabilityFit,
    required this.vocabularyFit,
    required this.sentenceComplexityFit,
    required this.notes,
  });

  Map<String, dynamic> toJson() => {
    'examName': examName,
    'targetLevel': targetLevel,
    'overallFit': overallFit,
    'readabilityFit': readabilityFit,
    'vocabularyFit': vocabularyFit,
    'sentenceComplexityFit': sentenceComplexityFit,
    'notes': notes,
  };
}

/// Comprehensive aggregate profiling result for an analyzed English text.
class TextProfileResult {
  final String originalText;
  final TextStatistics statistics;
  final List<WordTokenInfo> tokens;
  final Map<String, int> cefrCounts;
  final Map<String, double> cefrPercentages;
  final List<ReadabilityMetricItem> readabilityMetrics;
  final LexicalDiversityResult lexicalDiversity;
  final SyntacticComplexityResult syntacticComplexity;
  final VocabularyCoverageResult vocabularyCoverage;
  final List<PedagogicalRecommendation> recommendations;
  final List<ExamProfileComparison> examProfiles;
  final DateTime analyzedAt;
  final bool isShortText;

  int get recognizedUnratedCount => tokens
      .where((token) => token.lexicalStatus == LexicalStatus.recognizedUnrated)
      .length;

  int get notInLexiconCount => tokens
      .where((token) => token.lexicalStatus == LexicalStatus.notInLexicon)
      .length;

  Map<LexicalStatus, int> get lexicalStatusCounts {
    final counts = {for (final status in LexicalStatus.values) status: 0};
    for (final token in tokens) {
      counts[token.lexicalStatus] = counts[token.lexicalStatus]! + 1;
    }
    return Map.unmodifiable(counts);
  }

  const TextProfileResult({
    required this.originalText,
    required this.statistics,
    required this.tokens,
    required this.cefrCounts,
    required this.cefrPercentages,
    required this.readabilityMetrics,
    required this.lexicalDiversity,
    required this.syntacticComplexity,
    required this.vocabularyCoverage,
    required this.recommendations,
    required this.examProfiles,
    required this.analyzedAt,
    this.isShortText = false,
  });

  /// Primary CEFR classification of the passage overall
  String get dominantCefrLevel {
    final b2Plus =
        (cefrPercentages['B2'] ?? 0) +
        (cefrPercentages['C1'] ?? 0) +
        (cefrPercentages['C2'] ?? 0);
    if (b2Plus >= 25.0) return 'C1';
    if (b2Plus >= 15.0) return 'B2';
    final b1Plus = b2Plus + (cefrPercentages['B1'] ?? 0);
    if (b1Plus >= 20.0) return 'B1';
    return 'A2';
  }

  Map<String, dynamic> toJson() => {
    'originalText': originalText,
    'statistics': statistics.toJson(),
    'tokens': tokens.map((t) => t.toJson()).toList(),
    'cefrCounts': cefrCounts,
    'cefrPercentages': cefrPercentages,
    'lexicalStatusCounts': {
      for (final entry in lexicalStatusCounts.entries)
        entry.key.name: entry.value,
    },
    'readabilityMetrics': readabilityMetrics.map((r) => r.toJson()).toList(),
    'lexicalDiversity': lexicalDiversity.toJson(),
    'syntacticComplexity': syntacticComplexity.toJson(),
    'vocabularyCoverage': vocabularyCoverage.toJson(),
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'examProfiles': examProfiles.map((e) => e.toJson()).toList(),
    'analyzedAt': analyzedAt.toIso8601String(),
    'isShortText': isShortText,
  };
}
