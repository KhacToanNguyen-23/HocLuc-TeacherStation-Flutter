import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/dynamic_dictionary_entry.dart';

void main() {
  test(
    'round-trips API fields, nullable CEFR, source, and cache timestamp',
    () {
      final timestamp = DateTime.utc(2026, 10, 26, 3, 45);
      final entry = DynamicDictionaryEntry(
        word: 'quincunx',
        phonetics: const [
          DictionaryPhonetic(
            text: '/ˈkwɪn.kʌŋks/',
            audio: 'https://audio.test/q.mp3',
          ),
          DictionaryPhonetic(text: '/kwɪnˈkʌŋks/'),
        ],
        meanings: const [
          DictionaryMeaning(
            partOfSpeech: 'noun',
            definitions: [
              DictionaryDefinition(
                definition: 'An arrangement of five objects.',
                example: 'The dots formed a quincunx.',
              ),
            ],
          ),
        ],
        cefrLevel: null,
        source: DictionaryEntrySource.apiCache,
        cachedAt: timestamp,
      );

      final restored = DynamicDictionaryEntry.fromJson(entry.toJson());

      expect(restored.word, 'quincunx');
      expect(restored.phonetics, hasLength(2));
      expect(restored.phonetics.first.audio, 'https://audio.test/q.mp3');
      expect(restored.meanings.single.partOfSpeech, 'noun');
      expect(
        restored.meanings.single.definitions.single.example,
        'The dots formed a quincunx.',
      );
      expect(restored.cefrLevel, isNull);
      expect(restored.source, DictionaryEntrySource.apiCache);
      expect(restored.cachedAt, timestamp);
    },
  );

  test('supports an offline source with a known CEFR level', () {
    final entry = DynamicDictionaryEntry(
      word: 'juice',
      phonetics: const [],
      meanings: const [],
      cefrLevel: 'A2',
      source: DictionaryEntrySource.offlineDictionary,
      cachedAt: DateTime.utc(2026, 10, 26),
    );

    final restored = DynamicDictionaryEntry.fromJson(entry.toJson());
    expect(restored.source, DictionaryEntrySource.offlineDictionary);
    expect(restored.cefrLevel, 'A2');
  });
}
