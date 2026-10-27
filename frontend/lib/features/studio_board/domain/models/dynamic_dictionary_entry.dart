/// Provenance of lexical metadata shown by the CEFR profiler.
enum DictionaryEntrySource { offlineDictionary, apiCache }

/// A pronunciation returned by an offline or online dictionary source.
class DictionaryPhonetic {
  const DictionaryPhonetic({required this.text, this.audio});

  final String text;
  final String? audio;

  factory DictionaryPhonetic.fromJson(Map<String, dynamic> json) =>
      DictionaryPhonetic(
        text: json['text']?.toString() ?? '',
        audio: _optionalString(json['audio']),
      );

  Map<String, dynamic> toJson() => {
    'text': text,
    if (audio != null) 'audio': audio,
  };
}

/// One definition and its optional example/synonym metadata.
class DictionaryDefinition {
  const DictionaryDefinition({
    required this.definition,
    this.example,
    this.synonyms = const [],
    this.antonyms = const [],
  });

  final String definition;
  final String? example;
  final List<String> synonyms;
  final List<String> antonyms;

  factory DictionaryDefinition.fromJson(Map<String, dynamic> json) =>
      DictionaryDefinition(
        definition: json['definition']?.toString() ?? '',
        example: _optionalString(json['example']),
        synonyms: _stringList(json['synonyms']),
        antonyms: _stringList(json['antonyms']),
      );

  Map<String, dynamic> toJson() => {
    'definition': definition,
    if (example != null) 'example': example,
    'synonyms': synonyms,
    'antonyms': antonyms,
  };
}

/// Definitions grouped by the part of speech supplied by the source.
class DictionaryMeaning {
  const DictionaryMeaning({
    required this.partOfSpeech,
    this.definitions = const [],
  });

  final String partOfSpeech;
  final List<DictionaryDefinition> definitions;

  factory DictionaryMeaning.fromJson(Map<String, dynamic> json) =>
      DictionaryMeaning(
        partOfSpeech: json['partOfSpeech']?.toString() ?? 'unknown',
        definitions: _mapList(
          json['definitions'],
        ).map(DictionaryDefinition.fromJson).toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'partOfSpeech': partOfSpeech,
    'definitions': definitions
        .map((definition) => definition.toJson())
        .toList(),
  };
}

/// Dictionary metadata for one normalized root word.
///
/// An API entry deliberately has a null [cefrLevel]: DictionaryAPI.dev does
/// not provide a CEFR classification.
class DynamicDictionaryEntry {
  const DynamicDictionaryEntry({
    required this.word,
    required this.phonetics,
    required this.meanings,
    required this.cefrLevel,
    required this.source,
    required this.cachedAt,
  });

  final String word;
  final List<DictionaryPhonetic> phonetics;
  final List<DictionaryMeaning> meanings;
  final String? cefrLevel;
  final DictionaryEntrySource source;
  final DateTime cachedAt;

  factory DynamicDictionaryEntry.fromJson(Map<String, dynamic> json) {
    final sourceName = json['source']?.toString();
    return DynamicDictionaryEntry(
      word: json['word']?.toString() ?? '',
      phonetics: _mapList(
        json['phonetics'],
      ).map(DictionaryPhonetic.fromJson).toList(growable: false),
      meanings: _mapList(
        json['meanings'],
      ).map(DictionaryMeaning.fromJson).toList(growable: false),
      cefrLevel: _optionalString(json['cefrLevel']),
      source: DictionaryEntrySource.values.firstWhere(
        (value) => value.name == sourceName,
        orElse: () => DictionaryEntrySource.apiCache,
      ),
      cachedAt:
          DateTime.tryParse(json['cachedAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'phonetics': phonetics.map((phonetic) => phonetic.toJson()).toList(),
    'meanings': meanings.map((meaning) => meaning.toJson()).toList(),
    'cefrLevel': cefrLevel,
    'source': source.name,
    'cachedAt': cachedAt.toIso8601String(),
  };
}

String? _optionalString(Object? value) {
  final text = value?.toString();
  return text == null || text.isEmpty ? null : text;
}

List<String> _stringList(Object? value) => value is List
    ? value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList()
    : const [];
