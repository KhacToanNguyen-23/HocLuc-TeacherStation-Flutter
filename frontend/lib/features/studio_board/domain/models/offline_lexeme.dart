/// Domain model representing an offline recognized lexical entry.
/// Decouples recognition (`isRecognized = true`) from CEFR classification
/// (`cefrLevel: null` for unrated everyday terms like 'noodle' or 'medication').
class OfflineLexeme {
  /// Base word / lemma form.
  final String headword;

  /// Official or verified CEFR level ('A1', 'A2', 'B1', 'B2', 'C1', 'C2').
  /// Null for recognized lexical entries that do not have an official CEFR rating.
  final String? cefrLevel;

  /// Whether this lexical entry is recognized offline.
  final bool isRecognized;

  /// Whether this is one of Coxhead's 570 Academic Word List headwords.
  final bool isAwlHeadword;

  /// Academic Word List sublist (1–10), if this lexeme belongs to an AWL family.
  final int? awlSublist;

  /// Whether this lexeme belongs to common daily-life vocabulary groups.
  final bool isDailyLife;

  /// Frequency band classification ('K1', 'K2', 'K3', 'K4+', 'Off-list').
  final String frequencyBand;

  /// Canonical or default part of speech if known.
  final String? defaultPos;

  /// Data provenance / source attribution.
  final String? provenance;

  const OfflineLexeme({
    required this.headword,
    this.cefrLevel,
    this.isRecognized = true,
    this.isAwlHeadword = false,
    this.awlSublist,
    this.isDailyLife = false,
    this.frequencyBand = 'Off-list',
    this.defaultPos,
    this.provenance,
  });

  /// True if the lexeme has an official/verified CEFR rating (A1–C2).
  bool get isGraded => cefrLevel != null && cefrLevel!.isNotEmpty;

  /// True if recognized in the offline dictionary but unrated (no CEFR label).
  bool get isUnrated => isRecognized && (cefrLevel == null || cefrLevel!.isEmpty);

  OfflineLexeme copyWith({
    String? headword,
    String? cefrLevel,
    bool? isRecognized,
    bool? isAwlHeadword,
    int? awlSublist,
    bool? isDailyLife,
    String? frequencyBand,
    String? defaultPos,
    String? provenance,
  }) {
    return OfflineLexeme(
      headword: headword ?? this.headword,
      cefrLevel: cefrLevel ?? this.cefrLevel,
      isRecognized: isRecognized ?? this.isRecognized,
      isAwlHeadword: isAwlHeadword ?? this.isAwlHeadword,
      awlSublist: awlSublist ?? this.awlSublist,
      isDailyLife: isDailyLife ?? this.isDailyLife,
      frequencyBand: frequencyBand ?? this.frequencyBand,
      defaultPos: defaultPos ?? this.defaultPos,
      provenance: provenance ?? this.provenance,
    );
  }

  Map<String, dynamic> toJson() => {
    'headword': headword,
    'cefrLevel': cefrLevel,
    'isRecognized': isRecognized,
    'isAwlHeadword': isAwlHeadword,
    'awlSublist': awlSublist,
    'isDailyLife': isDailyLife,
    'frequencyBand': frequencyBand,
    'defaultPos': defaultPos,
    'provenance': provenance,
  };

  factory OfflineLexeme.fromJson(Map<String, dynamic> json) {
    return OfflineLexeme(
      headword: json['headword'] as String? ?? '',
      cefrLevel: json['cefrLevel'] as String?,
      isRecognized: json['isRecognized'] as bool? ?? true,
      isAwlHeadword: json['isAwlHeadword'] as bool? ?? false,
      awlSublist: json['awlSublist'] as int?,
      isDailyLife: json['isDailyLife'] as bool? ?? false,
      frequencyBand: json['frequencyBand'] as String? ?? 'Off-list',
      defaultPos: json['defaultPos'] as String?,
      provenance: json['provenance'] as String?,
    );
  }

  @override
  String toString() =>
      'OfflineLexeme(headword: $headword, cefr: $cefrLevel, '
      'isRecognized: $isRecognized, awl: $isAwlHeadword, '
      'sublist: $awlSublist, band: $frequencyBand)';
}
