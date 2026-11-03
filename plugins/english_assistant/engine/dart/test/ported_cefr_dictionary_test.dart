import 'package:test/test.dart';

import '../lib/src/models/text_profile_models.dart';
import '../lib/src/profiler/cefr_dictionary_data.dart';
import '../lib/src/profiler/text_tokenizer.dart';
import '../lib/src/profiler/text_profiler_service.dart';

void main() {
  group('CefrDictionaryData', () {
    test(
      'uses the full source-backed lexicon and keeps unrated words unknown',
      () {
        expect(CefrDictionaryData.wordToCefr, hasLength(8679));
        expect(CefrDictionaryData.wordToCefrHeadwords, hasLength(8323));
        expect(CefrDictionaryData.lookupCefr('although'), isNotNull);
        expect(CefrDictionaryData.lookupCefr('notwithstanding'), 'C1');
        expect(CefrDictionaryData.lookupCefr('medication'), 'B2');
        expect(CefrDictionaryData.lookupCefr('medications'), 'B2');
        expect(CefrDictionaryData.lookupCefr('medicate'), isNull);
        expect(CefrDictionaryData.lookupCefr('bitterness'), isNull);
        expect(CefrDictionaryData.lookupCefr('bitterly'), 'B2');
        expect(CefrDictionaryData.lookupCefr('species'), 'B2');
        expect(CefrDictionaryData.lookupCefr('analyses'), 'B1');
        expect(TextTokenizer.lookupCandidates('medication'), ['medication']);
        expect(TextTokenizer.lookupCandidates('species'), ['species']);
        expect(TextTokenizer.normalizeLemma('species'), 'species');
        expect(TextTokenizer.normalizeTokenLemma('analyses'), 'analysis');
        expect(TextTokenizer.lookupCandidates('bitterness'), ['bitterness']);
        expect(TextTokenizer.lookupCandidates('kindness'), ['kindness']);
        expect(TextTokenizer.lookupCandidates('teacher'), ['teacher']);
        expect(
          TextTokenizer.lookupCandidates('medications'),
          isNot(contains('medicate')),
        );
        expect(CefrDictionaryData.lookupCefr('alacrity'), isNull);
        expect(CefrDictionaryData.isRecognizedUnrated('alacrity'), isTrue);
        expect(CefrDictionaryData.isRecognizedUnrated('noodle'), isTrue);
        expect(CefrDictionaryData.isRecognizedUnrated('medication'), isFalse);

        final recognized = TextProfilerService.profile('Alacrity and noodle.')
            .tokens
            .where((token) => token.isRecognizedUnrated)
            .toList();
        expect(
          recognized.map((token) => token.clean),
          containsAll(['alacrity', 'noodle']),
        );
        expect(
          recognized.every((token) => token.cefrLevel == 'Unknown'),
          isTrue,
        );
        expect(recognized.first.toJson()['isRecognizedUnrated'], isTrue);
        expect(recognized.first.lexicalStatus, LexicalStatus.recognizedUnrated);
        expect(recognized.first.toJson()['lexicalStatus'], 'recognizedUnrated');

        final academicToken = TextProfilerService.profile('Notwithstanding.')
            .tokens
            .single;
        expect(academicToken.cefrLevel, 'C1');
        expect(academicToken.isAcademic, isTrue);
        expect(academicToken.academicMetricLevel, 'C1');
      },
    );

    test('reports recognized-unrated separately from true lexical misses', () {
      final profile = TextProfilerService.profile('Noodles. Zorblaxian.');
      final noodles = profile.tokens.singleWhere(
        (token) => token.surface == 'Noodles',
      );
      final unknown = profile.tokens.singleWhere(
        (token) => token.surface == 'Zorblaxian',
      );

      expect(noodles.cefrLevel, 'Unknown');
      expect(noodles.lexicalStatus, LexicalStatus.recognizedUnrated);
      expect(unknown.cefrLevel, 'Unknown');
      expect(unknown.lexicalStatus, LexicalStatus.notInLexicon);
      expect(profile.cefrCounts['Unknown'], 2);
      expect(profile.recognizedUnratedCount, 1);
      expect(profile.notInLexiconCount, 1);
      expect(profile.toJson()['lexicalStatusCounts'], {
        'graded': 0,
        'recognizedUnrated': 1,
        'notInLexicon': 1,
      });
    });

    test('includes all 570 Coxhead AWL headwords as academic vocabulary', () {
      expect(CefrDictionaryData.academicWordList, hasLength(3094));
      expect(CefrDictionaryData.academicWordList, contains('analysis'));
      expect(CefrDictionaryData.academicWordList, contains('administration'));
      expect(CefrDictionaryData.coxheadAwlHeadwords, hasLength(570));
      expect(CefrDictionaryData.academicWordList, contains('notwithstanding'));
      expect(CefrDictionaryData.academicWordList, contains('socalled'));
      expect(CefrDictionaryData.lookupAcademicMetricLevel('analyse'), 'B2');
      expect(
        CefrDictionaryData.lookupAcademicMetricLevel('administration'),
        'B2',
      );
      expect(CefrDictionaryData.lookupAcademicMetricLevel('derivative'), 'B2');
      expect(CefrDictionaryData.lookupAcademicMetricLevel('variance'), 'B2');
      expect(
        CefrDictionaryData.lookupAcademicMetricLevel('notwithstanding'),
        'C1',
      );
    });
  });
}
