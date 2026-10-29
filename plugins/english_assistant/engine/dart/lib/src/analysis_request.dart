class AnalysisRequest {
  final int schemaVersion;
  final String requestId;
  final String text;

  const AnalysisRequest({
    this.schemaVersion = 1,
    required this.requestId,
    required this.text,
  });

  factory AnalysisRequest.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'];
    final requestId = json['requestId'];
    final source = json['source'];
    if (schemaVersion != 1 ||
        requestId is! String ||
        requestId.trim().isEmpty ||
        source is! Map) {
      throw const FormatException('Invalid analysis request envelope.');
    }
    final sourceMap = Map<String, Object?>.from(source);
    if (sourceMap['kind'] != 'text' ||
        sourceMap['offsetUnit'] != 'unicodeCodePoint' ||
        sourceMap['text'] is! String) {
      throw const FormatException('Text analysis requires a text source.');
    }
    return AnalysisRequest(
      schemaVersion: 1,
      requestId: requestId,
      text: sourceMap['text']! as String,
    );
  }

  Map<String, Object?> toJson() => {
    'schemaVersion': schemaVersion,
    'requestId': requestId,
    'source': {'kind': 'text', 'offsetUnit': 'unicodeCodePoint', 'text': text},
  };
}
