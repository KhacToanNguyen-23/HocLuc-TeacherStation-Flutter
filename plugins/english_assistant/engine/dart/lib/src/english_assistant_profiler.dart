import 'analysis_request.dart';
import 'analysis_result.dart';
import 'models/text_profile_models.dart';
import 'profiler/text_profiler_service.dart';

class EnglishAssistantProfiler {
  static AnalysisResult analyze(AnalysisRequest request) {
    final profile = TextProfilerService.profile(request.text);
    final leadingTrimCodePoints = request.text
        .substring(0, request.text.length - request.text.trimLeft().length)
        .runes
        .length;
    final convertedLexemes = Map<WordTokenInfo, WordTokenInfo>.identity();
    final tokens = profile.tokens
        .map((token) {
          final converted = _toCodePointToken(
            token,
            profileText: profile.originalText,
            leadingTrimCodePoints: leadingTrimCodePoints,
          );
          convertedLexemes[token] = converted;
          return AnalysisToken(lexicalInfo: converted);
        })
        .toList(growable: false);
    final coverage = profile.vocabularyCoverage;
    final apiCoverage = VocabularyCoverageResult(
      k1Percent: coverage.k1Percent,
      k2Percent: coverage.k2Percent,
      k3Percent: coverage.k3Percent,
      k4PlusPercent: coverage.k4PlusPercent,
      offListPercent: coverage.offListPercent,
      coveredPercent: coverage.coveredPercent,
      preTeachWords: coverage.preTeachWords
          .map(
            (token) =>
                convertedLexemes[token] ??
                _toCodePointToken(
                  token,
                  profileText: profile.originalText,
                  leadingTrimCodePoints: leadingTrimCodePoints,
                ),
          )
          .toList(growable: false),
    );
    final apiProfile = TextProfileResult(
      originalText: request.text,
      statistics: profile.statistics,
      tokens: tokens.map((token) => token.lexicalInfo).toList(growable: false),
      cefrCounts: profile.cefrCounts,
      cefrPercentages: profile.cefrPercentages,
      readabilityMetrics: profile.readabilityMetrics,
      lexicalDiversity: profile.lexicalDiversity,
      syntacticComplexity: profile.syntacticComplexity,
      vocabularyCoverage: apiCoverage,
      recommendations: profile.recommendations,
      examProfiles: profile.examProfiles,
      analyzedAt: profile.analyzedAt,
      isShortText: profile.isShortText,
    );

    return AnalysisResult(
      requestId: request.requestId,
      status: 'complete',
      sourceText: request.text,
      profile: apiProfile,
      tokens: tokens,
    );
  }

  static WordTokenInfo _toCodePointToken(
    WordTokenInfo token, {
    required String profileText,
    required int leadingTrimCodePoints,
  }) {
    final prefix = profileText.substring(0, token.startIndex);
    final surface = profileText.substring(token.startIndex, token.endIndex);
    final start = leadingTrimCodePoints + prefix.runes.length;
    return WordTokenInfo(
      surface: token.surface,
      clean: token.clean,
      lemma: token.lemma,
      pos: token.pos,
      cefrLevel: token.cefrLevel,
      frequencyBand: token.frequencyBand,
      isProperNoun: token.isProperNoun,
      isNumber: token.isNumber,
      isAcademic: token.isAcademic,
      lexicalStatus: token.lexicalStatus,
      academicMetricLevel: token.academicMetricLevel,
      syllables: token.syllables,
      startIndex: start,
      endIndex: start + surface.runes.length,
    );
  }

  static AnalysisResult analyzeJson(Map<String, Object?> json) {
    try {
      return analyze(AnalysisRequest.fromJson(json));
    } on FormatException catch (error) {
      final profile = TextProfilerService.profile('');
      return AnalysisResult(
        requestId: json['requestId'] is String
            ? json['requestId']! as String
            : '',
        status: 'invalidRequest',
        sourceText: '',
        profile: profile,
        tokens: const [],
        diagnostics: [error.message],
      );
    } catch (_) {
      final profile = TextProfilerService.profile('');
      return AnalysisResult(
        requestId: json['requestId'] is String
            ? json['requestId']! as String
            : '',
        status: 'invalidRequest',
        sourceText: '',
        profile: profile,
        tokens: const [],
        diagnostics: const ['Malformed analysis request.'],
      );
    }
  }
}
