import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/generated_cefr_source_words.dart';

void main() {
  group('Generated CEFR source lexicon', () {
    test('contains 8,000-10,000 source-backed headwords, excluding inflections', () {
      expect(generatedCefrSourceHeadwords.length, inInclusiveRange(8000, 10000));
      expect(generatedCefrSourceWords['medication'], 'B2');
      expect(generatedRecognizedUnratedWords, contains('noodle'));
      expect(generatedRecognizedUnratedWords, contains('alacrity'));
      expect(generatedRecognizedUnratedWords.length, 189);
      expect(generatedCefrSourceWords, isNot(contains('noodle')));
      expect(generatedCefrSourceWords, isNot(contains('alacrity')));
      for (final word in generatedRecognizedUnratedWords) {
        expect(generatedCefrSourceWords, isNot(contains(word)), reason: word);
      }
    });

    test('contains only valid CEFR labels and normalized single tokens', () {
      const levels = {'A1', 'A2', 'B1', 'B2', 'C1', 'C2'};
      for (final entry in generatedCefrSourceWords.entries) {
        expect(levels, contains(entry.value), reason: entry.key);
        expect(entry.key, matches(RegExp(r"^[a-z]+(?:[-'][a-z]+)*$")));
      }
    });
  });
}
