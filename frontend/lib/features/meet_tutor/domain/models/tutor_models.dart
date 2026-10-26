class TutorConfig {
  const TutorConfig({
    required this.baseUrl,
    required this.model,
    this.apiKey = '',
    this.useEnvironment = false,
  });
  final String baseUrl;
  final String model;
  final String apiKey;
  final bool useEnvironment;

  Map<String, dynamic> toJson() => useEnvironment
      ? {'useEnvironment': true}
      : {
          'baseUrl': baseUrl.trim(),
          'model': model.trim(),
          'apiKey': apiKey.trim(),
        };
}

class TutorSource {
  const TutorSource({
    required this.id,
    required this.label,
    required this.text,
  });
  final String id;
  final String label;
  final String text;
  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'text': text};
}

class TutorContext {
  const TutorContext({
    required this.revision,
    required this.currentPage,
    required this.sources,
    this.lessonSubject = '',
  });
  final int revision;
  final int currentPage;
  final List<TutorSource> sources;
  final String lessonSubject;
}

enum TutorConfidence { grounded, tentative, outOfScope, unavailable }

class TutorResult {
  const TutorResult({
    required this.answer,
    required this.evidence,
    this.reason = '',
    this.confidence = TutorConfidence.grounded,
  });
  final String answer;
  final Map<String, String> evidence;
  final String reason;
  final TutorConfidence confidence;

  bool canAutoSend(List<TutorSource> sources) {
    if (confidence == TutorConfidence.unavailable) return false;
    if (confidence == TutorConfidence.grounded) return supportedBy(sources);
    if (answer.trim().isEmpty || answer.length > 1200) return false;
    final texts = {for (final s in sources) s.id: s.text};
    return evidence.entries.every(
      (e) =>
          e.value.trim().length >= 8 &&
          (texts[e.key]?.contains(e.value) ?? false),
    );
  }

  bool supportedBy(List<TutorSource> sources) {
    if (answer.trim().isEmpty || answer.length > 1200 || evidence.isEmpty) {
      return false;
    }
    final texts = {for (final s in sources) s.id: s.text};
    return evidence.entries.every(
          (e) =>
              e.value.trim().length >= 8 &&
              (texts[e.key]?.contains(e.value) ?? false),
        ) &&
        // The grounded/high-confidence branch remains strictly extractive.
        // Never auto-send unsupported prose merely because it cites a real quote.
        answer.trim() == evidence.values.join('\n').trim();
  }
}

class TutorReview {
  const TutorReview(this.sender, this.question, this.reason);
  final String sender;
  final String question;
  final String reason;
}
