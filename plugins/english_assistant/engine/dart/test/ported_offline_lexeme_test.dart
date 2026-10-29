import 'package:test/test.dart';

import '../lib/src/models/offline_lexeme.dart';
import '../lib/src/models/text_profile_models.dart';
import '../lib/src/profiler/cefr_dictionary_data.dart';
import '../lib/src/profiler/cefr_profiler.dart';
import '../lib/src/profiler/daily_life_vocabulary.dart';
import '../lib/src/profiler/text_tokenizer.dart';

void main() {
  group('1. OfflineLexeme Model & Recognition Decoupling', () {
    test('OfflineLexeme correctly distinguishes graded vs unrated lexemes', () {
      const graded = OfflineLexeme(
        headword: 'researcher',
        cefrLevel: 'B1',
        isRecognized: true,
        frequencyBand: 'K2',
      );
      expect(graded.isGraded, isTrue);
      expect(graded.isUnrated, isFalse);

      const unrated = OfflineLexeme(
        headword: 'noodle',
        cefrLevel: null,
        isRecognized: true,
        isDailyLife: true,
        frequencyBand: 'K1',
      );
      expect(unrated.isGraded, isFalse);
      expect(unrated.isUnrated, isTrue);
    });

    test('OfflineLexeme serializes and deserializes cleanly', () {
      const lexeme = OfflineLexeme(
        headword: 'medication',
        cefrLevel: null,
        isRecognized: true,
        isAwlHeadword: false,
        awlSublist: null,
        isDailyLife: true,
        frequencyBand: 'K2',
        defaultPos: 'NOUN',
        provenance: 'Daily-Life Curated',
      );

      final json = lexeme.toJson();
      expect(json['headword'], 'medication');
      expect(json['cefrLevel'], isNull);
      expect(json['isDailyLife'], isTrue);

      final restored = OfflineLexeme.fromJson(json);
      expect(restored.headword, 'medication');
      expect(restored.cefrLevel, isNull);
      expect(restored.isDailyLife, isTrue);
      expect(restored.isUnrated, isTrue);
    });

    test('DailyLifeVocabulary contains common everyday terms with decoupled ratings', () {
      expect(DailyLifeVocabulary.contains('noodle'), isTrue);
      expect(DailyLifeVocabulary.get('noodle')!.isUnrated, isTrue);

      expect(DailyLifeVocabulary.contains('tofu'), isTrue);
      expect(DailyLifeVocabulary.get('tofu')!.isUnrated, isTrue);

      expect(DailyLifeVocabulary.contains('medication'), isTrue);
      expect(DailyLifeVocabulary.get('medication')!.cefrLevel, 'B2');

      expect(DailyLifeVocabulary.contains('pizza'), isTrue);
      expect(DailyLifeVocabulary.get('pizza')!.cefrLevel, 'A1');

      expect(DailyLifeVocabulary.contains('laptop'), isTrue);
      expect(DailyLifeVocabulary.get('laptop')!.cefrLevel, 'A2');

      expect(DailyLifeVocabulary.contains('wifi'), isTrue);
      expect(DailyLifeVocabulary.get('wifi')!.cefrLevel, 'A1');

      expect(DailyLifeVocabulary.contains('subway'), isTrue);
      expect(DailyLifeVocabulary.get('subway')!.cefrLevel, 'A2');
    });
  });

  group('2. 4-Tier Lookup Precedence in CefrDictionaryData', () {
    test('Tier 1: Exact surface form match takes precedence (preserves specific headwords & unrated entries)', () {
      // 'bitterness' is recognized unrated offline (retained from curated list)
      final bitternessLexeme = CefrDictionaryData.lookupLexeme('bitterness');
      expect(bitternessLexeme, isNotNull);
      expect(bitternessLexeme!.headword, 'bitterness');
      expect(bitternessLexeme.isUnrated, isTrue);

      // 'bitter' is A2/B1 in CEFR-J
      final bitterLexeme = CefrDictionaryData.lookupLexeme('bitter');
      expect(bitterLexeme, isNotNull);
      expect(bitterLexeme!.headword, 'bitter');
      expect(bitterLexeme.cefrLevel, 'B1');

      // 'bitterly' has its own dedicated B2 headword entry in CEFR-J
      final bitterlyLexeme = CefrDictionaryData.lookupLexeme('bitterly');
      expect(bitterlyLexeme, isNotNull);
      expect(bitterlyLexeme!.headword, 'bitterly');
      expect(bitterlyLexeme.cefrLevel, 'B2');

      // Daily life exact matches: graded vs unrated
      final medicationLexeme = CefrDictionaryData.lookupLexeme('medication');
      expect(medicationLexeme, isNotNull);
      expect(medicationLexeme!.headword, 'medication');
      expect(medicationLexeme.cefrLevel, 'B2');

      final tofuLexeme = CefrDictionaryData.lookupLexeme('tofu');
      expect(tofuLexeme, isNotNull);
      expect(tofuLexeme!.headword, 'tofu');
      expect(tofuLexeme.isUnrated, isTrue);
    });

    test(
      'Tier 2: Safe inflection rules resolve inflected forms to base headword',
      () {
        // Plural nouns -> base singular
        final noodlesLexeme = CefrDictionaryData.lookupLexeme('noodles');
        expect(noodlesLexeme, isNotNull);
        expect(noodlesLexeme!.headword, 'noodle');
        expect(noodlesLexeme.isUnrated, isTrue);

        final medicationsLexeme = CefrDictionaryData.lookupLexeme(
          'medications',
        );
        expect(medicationsLexeme, isNotNull);
        expect(medicationsLexeme!.headword, 'medication');
        expect(medicationsLexeme.cefrLevel, 'B2');

        // Past tense verbs -> base infinitive with silent-e restoration
        final createdLexeme = CefrDictionaryData.lookupLexeme('created');
        expect(createdLexeme, isNotNull);
        expect(createdLexeme!.headword, 'create');
        expect(createdLexeme.cefrLevel, 'A2');

        final decidedLexeme = CefrDictionaryData.lookupLexeme('decided');
        expect(decidedLexeme, isNotNull);
        expect(decidedLexeme!.headword, 'decide');
        expect(decidedLexeme.cefrLevel, 'A2');

        // Irregular inflections without dedicated headword row
        final feetLexeme = CefrDictionaryData.lookupLexeme('feet');
        expect(feetLexeme, isNotNull);
        expect(feetLexeme!.headword, 'foot');
        expect(feetLexeme.cefrLevel, 'B1');
      },
    );

    test(
      'Tier 3: Curated derivations resolve adverbs and hyphenated compounds',
      () {
        // -ly adverb without own entry -> adjective base
        final sourlyLexeme = CefrDictionaryData.lookupLexeme('sourly');
        expect(sourlyLexeme, isNotNull);
        expect(sourlyLexeme!.headword, 'sour');
        expect(sourlyLexeme.cefrLevel, 'B1');

        // Hyphenated compound with known parts
        final compoundLexeme = CefrDictionaryData.lookupLexeme(
          'bitter-tasting',
        );
        expect(compoundLexeme, isNotNull);
        expect(compoundLexeme!.headword, 'bitter-tasting');
        expect(compoundLexeme.cefrLevel, 'B1');
      },
    );

    test('Tier 4: Unassigned fallback returns null for uncatalogued words', () {
      expect(CefrDictionaryData.lookupLexeme('naringin'), isNull);
      expect(CefrDictionaryData.lookupLexeme('adenosine'), isNull);
      expect(CefrDictionaryData.lookupLexeme('monophosphate'), isNull);
      expect(CefrDictionaryData.lookupCefr('naringin'), isNull);
    });
  });

  group('3. Lemmatization & Over-stemming Prevention in TextTokenizer', () {
    test('Prevents over-stemming on verbs ending in silent-e', () {
      expect(TextTokenizer.normalizeLemma('created'), equals('create'));
      expect(TextTokenizer.normalizeLemma('creating'), equals('create'));
      expect(TextTokenizer.normalizeLemma('decided'), equals('decide'));
      expect(TextTokenizer.normalizeLemma('deciding'), equals('decide'));
      expect(TextTokenizer.normalizeLemma('produced'), equals('produce'));
      expect(TextTokenizer.normalizeLemma('producing'), equals('produce'));
      expect(TextTokenizer.normalizeLemma('required'), equals('require'));
      expect(TextTokenizer.normalizeLemma('requiring'), equals('require'));
    });

    test('Bans broad derivational -ation -> -ate rewrite', () {
      // medication must NOT be stemmed to medicate
      expect(
        TextTokenizer.normalizeTokenLemma('medication'),
        equals('medication'),
      );
      expect(
        TextTokenizer.normalizeTokenLemma('corporation'),
        equals('corporation'),
      );
    });

    test('Correctly handles regular past tense without silent-e', () {
      expect(TextTokenizer.normalizeLemma('conducted'), equals('conduct'));
      expect(TextTokenizer.normalizeLemma('walked'), equals('walk'));
      expect(TextTokenizer.normalizeLemma('started'), equals('start'));
    });
  });

  group('4. CefrProfiler Integration with Decoupled Lexemes', () {
    test('Profiles tokens with accurate lemma, level, and lexicalStatus', () {
      const text =
          'Scientists created delicious noodles and medication for tasting bitterness.';
      final rawSpans = TextTokenizer.extractWordSpans(text);
      final profile = CefrProfiler.profileTokens(text, rawSpans);

      final tokens = profile.tokens;
      expect(tokens, isNotEmpty);

      // 'created' -> lemma is 'create', cefr is 'A2', graded
      final createdToken = tokens.firstWhere((t) => t.clean == 'created');
      expect(createdToken.lemma, equals('create'));
      expect(createdToken.cefrLevel, equals('A2'));
      expect(createdToken.lexicalStatus, equals(LexicalStatus.graded));

      // 'noodles' -> lemma is 'noodle', recognized unrated
      final noodlesToken = tokens.firstWhere((t) => t.clean == 'noodles');
      expect(noodlesToken.lemma, equals('noodle'));
      expect(noodlesToken.isRecognizedUnrated, isTrue);
      expect(
        noodlesToken.lexicalStatus,
        equals(LexicalStatus.recognizedUnrated),
      );

      // 'medication' -> graded B2 noun
      final medToken = tokens.firstWhere((t) => t.clean == 'medication');
      expect(medToken.cefrLevel, equals('B2'));
      expect(medToken.lexicalStatus, equals(LexicalStatus.graded));

      // 'bitterness' -> recognized unrated offline
      final bitternessToken = tokens.firstWhere((t) => t.clean == 'bitterness');
      expect(bitternessToken.lemma, equals('bitterness'));
      expect(bitternessToken.isRecognizedUnrated, isTrue);
      expect(
        bitternessToken.lexicalStatus,
        equals(LexicalStatus.recognizedUnrated),
      );
    });
  });
}
