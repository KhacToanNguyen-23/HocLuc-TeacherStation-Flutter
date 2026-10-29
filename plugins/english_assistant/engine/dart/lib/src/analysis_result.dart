import 'models/text_profile_models.dart';

class AnalysisToken {
  final WordTokenInfo lexicalInfo;

  const AnalysisToken({required this.lexicalInfo});

  String get surface => lexicalInfo.surface;
  int get start => lexicalInfo.startIndex;
  int get end => lexicalInfo.endIndex;

  Map<String, Object?> toJson() => {
    ...lexicalInfo.toJson(),
    'startIndex': start,
    'endIndex': end,
    'offsetUnit': 'unicodeCodePoint',
  };
}

class AnalysisResult {
  final int schemaVersion;
  final String requestId;
  final String sourceKind;
  final String status;
  final String offsetUnit;
  final String sourceText;
  final TextProfileResult profile;
  final List<AnalysisToken> tokens;
  final List<String> diagnostics;

  const AnalysisResult({
    this.schemaVersion = 1,
    required this.requestId,
    this.sourceKind = 'text',
    required this.status,
    this.offsetUnit = 'unicodeCodePoint',
    required this.sourceText,
    required this.profile,
    required this.tokens,
    this.diagnostics = const [],
  });

  Map<String, Object?> toJson() {
    final analysis = profile.toJson();
    analysis['originalText'] = sourceText;
    analysis['tokens'] = tokens.map((token) => token.toJson()).toList();
    return {
      'schemaVersion': schemaVersion,
      'requestId': requestId,
      'sourceKind': sourceKind,
      'status': status,
      'offsetUnit': offsetUnit,
      'analysis': analysis,
      'diagnostics': diagnostics,
    };
  }
}
