import 'package:test/test.dart';

import '../lib/src/models/text_profile_models.dart';
import '../lib/src/profiler/cefr_dictionary_data.dart';
import '../lib/src/profiler/cefr_profiler.dart';
import '../lib/src/profiler/lexical_diversity_calculator.dart';
import '../lib/src/profiler/readability_calculator.dart';
import '../lib/src/profiler/syllable_counter.dart';
import '../lib/src/profiler/syntactic_complexity_analyzer.dart';
import '../lib/src/profiler/text_profiler_service.dart';
import '../lib/src/profiler/text_tokenizer.dart';

void main() {
  group('SyllableCounter Tests', () {
    test(
      'counts syllables accurately for common words and inflectional endings',
      () {
        expect(SyllableCounter.countSyllables('cat'), equals(1));
        expect(SyllableCounter.countSyllables('student'), equals(2));
        expect(SyllableCounter.countSyllables('difficult'), equals(3));
        expect(SyllableCounter.countSyllables('university'), equals(5));
        expect(SyllableCounter.countSyllables('table'), equals(2));
        expect(SyllableCounter.countSyllables('simple'), equals(2));
        expect(
          SyllableCounter.countSyllables('played'),
          equals(1),
        ); // -ed not after t/d
        expect(
          SyllableCounter.countSyllables('wanted'),
          equals(2),
        ); // -ed after t
        expect(SyllableCounter.countSyllables('cats'), equals(1));
        expect(SyllableCounter.countSyllables('watches'), equals(2));
      },
    );

    test('identifies polysyllabic and complex words', () {
      expect(SyllableCounter.isPolysyllabic('education'), isTrue);
      expect(SyllableCounter.isPolysyllabic('book'), isFalse);
      expect(SyllableCounter.isComplexWord('unprecedented'), isTrue);
      expect(
        SyllableCounter.isComplexWord('Mr. Smith', isProperNoun: true),
        isFalse,
      );
    });
  });

  group('TextTokenizer Tests', () {
    test('segments sentences without splitting on abbreviations or decimal points', () {
      const text =
          'Dr. Smith visited the U.S. last year. The GDP grew by 3.5% in Q4! Is it sustainable? Yes, it is.';
      final sentences = TextTokenizer.extractSentences(text);
      expect(sentences.length, equals(4));
      expect(sentences[0], equals('Dr. Smith visited the U.S. last year.'));
      expect(sentences[1], equals('The GDP grew by 3.5% in Q4!'));
      expect(sentences[2], equals('Is it sustainable?'));
      expect(sentences[3], equals('Yes, it is.'));
    });

    test('extracts exact word token spans and positions', () {
      const text = 'The smart student reads.';
      final spans = TextTokenizer.extractWordSpans(text);
      expect(spans.length, equals(4));
      expect(spans[0].surface, equals('The'));
      expect(spans[0].startIndex, equals(0));
      expect(spans[0].endIndex, equals(3));
      expect(spans[1].surface, equals('smart'));
      expect(spans[2].surface, equals('student'));
      expect(spans[3].surface, equals('reads'));
    });

    test(
      'keeps hyphenated and Unicode-hyphenated compounds as single spans',
      () {
        const text = 'bitter-tasting, bitter‑tasting';
        final spans = TextTokenizer.extractWordSpans(text);

        expect(spans.map((span) => span.surface), [
          'bitter-tasting',
          'bitter‑tasting',
        ]);
        for (final span in spans) {
          expect(text.substring(span.startIndex, span.endIndex), span.surface);
        }
      },
    );

    test('normalizes inflected words and irregular verbs to base lemmas', () {
      expect(TextTokenizer.normalizeLemma('went'), equals('go'));
      expect(TextTokenizer.normalizeLemma('studies'), equals('study'));
      expect(TextTokenizer.normalizeLemma('running'), equals('run'));
      expect(TextTokenizer.normalizeLemma('bitter'), equals('bitter'));
      expect(TextTokenizer.normalizeLemma('bitterness'), equals('bitter'));
      expect(TextTokenizer.normalizeTokenLemma('bitterness'), 'bitterness');
      expect(TextTokenizer.normalizeLemma('boxes'), equals('box'));
      expect(TextTokenizer.normalizeLemma('children'), equals('child'));
    });

    test(
      'resolves suffix variations and hyphen compounds through offline CEFR',
      () {
        const text = 'Bitterness, potentials, bitterly, and bitter-tasting.';
        final profile = TextProfilerService.profile(text);
        final tokens = {
          for (final token in profile.tokens) token.surface: token,
        };

        expect(tokens['Bitterness']!.cefrLevel, 'Unknown');
        expect(tokens['Bitterness']!.isRecognizedUnrated, isTrue);
        expect(tokens['potentials']!.cefrLevel, 'B1');
        expect(tokens['bitterly']!.cefrLevel, 'B2');
        expect(tokens['bitter-tasting']!.cefrLevel, 'B1');
        expect(tokens['bitter-tasting']!.lemma, 'bitter-tasting');
        expect(profile.cefrCounts['Unknown'], 1);
      },
    );

    test('resolves medication plurals without crossing part of speech', () {
      const passage = 'Medications can help. Medication can help.';
      final profile = TextProfilerService.profile(passage);
      final medications = profile.tokens.firstWhere(
        (token) => token.surface == 'Medications',
      );
      final medication = profile.tokens.firstWhere(
        (token) => token.surface == 'Medication',
      );

      expect(medications.lemma, 'medication');
      expect(medications.cefrLevel, 'B2');
      expect(medications.lexicalStatus, LexicalStatus.graded);
      expect(medication.cefrLevel, 'B2');
      expect(TextTokenizer.lookupCandidates('medication'), ['medication']);
      expect(
        TextTokenizer.lookupCandidates('medications'),
        isNot(contains('medicate')),
      );
    });

    test(
      'does not join an unknown compound into a different dictionary word',
      () {
        final profile = TextProfilerService.profile('I re-mark the answer.');
        final compound = profile.tokens.singleWhere(
          (token) => token.surface == 're-mark',
        );

        expect(CefrDictionaryData.lookupCefr('remark'), isNotNull);
        expect(compound.cefrLevel, 'Unknown');
        expect(compound.lemma, 're-mark');
      },
    );

    test('distinguishes proper nouns from regular words', () {
      expect(TextTokenizer.isProperNoun('London', 1, false), isTrue);
      expect(TextTokenizer.isProperNoun('student', 1, false), isFalse);
      expect(TextTokenizer.isProperNoun('The', 0, true), isFalse);
    });
  });

  group('CefrProfiler & Lexical Coverage Tests', () {
    test('classifies words into 6 CEFR levels accurately and isolates unknown tokens', () {
      const passage =
          'A smart student reads a book. The government announced preliminary economic measures. Notwithstanding the delay, the committee agreed.';
      final spans = TextTokenizer.extractWordSpans(passage);
      final result = CefrProfiler.profileTokens(passage, spans);

      expect(result.counts['A1']! > 0, isTrue); // 'a', 'reads', 'book'
      expect(result.counts['B1']! > 0, isTrue); // 'government', 'economic'
      expect(result.counts['B2']! > 0, isTrue); // 'preliminary'
      expect(result.counts['C1']! > 0, isTrue); // 'notwithstanding'

      // Unknown words are NOT artificially elevated to C1/C2
      final unknownSpans = TextTokenizer.extractWordSpans(
        'Zorblaxian flumptrick',
      );
      final unknownResult = CefrProfiler.profileTokens(
        'Zorblaxian flumptrick',
        unknownSpans,
      );
      expect(unknownResult.counts['Unknown'], equals(2));
      expect(unknownResult.counts['C1'], equals(0));
      expect(unknownResult.counts['C2'], equals(0));
    });

    test(
      'keeps mid-sentence proper nouns Unknown despite common-word matches',
      () {
        const passage = 'I met Apple, May, and Analysis.';
        final result = CefrProfiler.profileTokens(
          passage,
          TextTokenizer.extractWordSpans(passage),
        );
        final apple = result.tokens.singleWhere(
          (token) => token.surface == 'Apple',
        );
        final may = result.tokens.singleWhere(
          (token) => token.surface == 'May',
        );
        final analysis = result.tokens.singleWhere(
          (token) => token.surface == 'Analysis',
        );

        expect(apple.isProperNoun, isTrue);
        expect(apple.cefrLevel, 'Unknown');
        expect(may.isProperNoun, isTrue);
        expect(may.cefrLevel, 'Unknown');
        expect(analysis.isProperNoun, isTrue);
        expect(analysis.cefrLevel, 'Unknown');
        expect(analysis.isAcademic, isFalse);
        expect(analysis.academicMetricLevel, isNull);
        expect(analysis.frequencyBand, 'Off-list');
        expect(result.counts['A1'], 3); // I, met, and
        expect(result.counts['Unknown'], 3);
      },
    );

    test('computes K1-K3 frequency coverage and extracts pre-teach vocabulary', () {
      const passage =
          'The committee will evaluate whether this innovative strategy is feasible and inevitable.';
      final spans = TextTokenizer.extractWordSpans(passage);
      final result = CefrProfiler.profileTokens(passage, spans);

      expect(result.coverage.k1Percent > 0, isTrue);
      expect(result.coverage.coveredPercent >= 70.0, isTrue);

      final preTeachSurfaces = result.coverage.preTeachWords
          .map((w) => w.surface.toLowerCase())
          .toList();
      expect(
        preTeachSurfaces.contains('feasible') ||
            preTeachSurfaces.contains('inevitable'),
        isTrue,
      );
    });
  });

  group('ReadabilityCalculator Benchmark Tests', () {
    test('calculates Flesch Reading Ease and Grade Level mathematically', () {
      // 100 words, 10 sentences, 150 syllables
      const stats = TextStatistics(
        totalCharacters: 500,
        totalLetters: 450,
        totalWords: 100,
        totalSentences: 10,
        totalSyllables: 150,
        totalPolysyllables: 15,
        totalComplexWords: 12,
        avgWordLength: 4.5,
        avgSentenceLength: 10.0,
      );

      final metrics = ReadabilityCalculator.calculateMetrics(stats);
      final flesch = metrics.firstWhere((m) => m.id == 'flesch_reading_ease');
      final fk = metrics.firstWhere((m) => m.id == 'flesch_kincaid_grade');
      final fog = metrics.firstWhere((m) => m.id == 'gunning_fog');
      final smog = metrics.firstWhere((m) => m.id == 'smog_index');
      final cl = metrics.firstWhere((m) => m.id == 'coleman_liau');
      final ari = metrics.firstWhere(
        (m) => m.id == 'automated_readability_index',
      );

      // Flesch: 206.835 - (1.015 * 10) - (84.6 * 1.5) = 206.835 - 10.15 - 126.9 = 69.785 -> ~69.8
      expect(flesch.score, closeTo(69.8, 0.2));
      expect(flesch.interpretation.contains('Tiêu chuẩn'), isTrue);

      // FK: (0.39 * 10) + (11.8 * 1.5) - 15.59 = 3.9 + 17.7 - 15.59 = 6.01 -> ~6.0
      expect(fk.score, closeTo(6.0, 0.2));

      // Fog: 0.4 * [ 10 + 100 * (12 / 100) ] = 0.4 * [10 + 12] = 8.8
      expect(fog.score, closeTo(8.8, 0.2));

      // Coleman-Liau: 0.0588 * 450 - 0.296 * 10 - 15.8 = 26.46 - 2.96 - 15.8 = 7.7
      expect(cl.score, closeTo(7.7, 0.2));

      // ARI: 4.71 * 4.5 + 0.5 * 10 - 21.43 = 21.195 + 5 - 21.43 = 4.765 -> ~4.8
      expect(ari.score, closeTo(4.8, 0.2));
      expect(smog.score > 0, isTrue);
    });

    test(
      'handles very short text gracefully with explicit reliability disclaimer',
      () {
        const stats = TextStatistics(
          totalCharacters: 15,
          totalLetters: 12,
          totalWords: 3,
          totalSentences: 1,
          totalSyllables: 3,
          totalPolysyllables: 0,
          totalComplexWords: 0,
          avgWordLength: 4.0,
          avgSentenceLength: 3.0,
        );

        final metrics = ReadabilityCalculator.calculateMetrics(stats);
        for (final m in metrics) {
          expect(m.isReliable, isFalse);
          expect(m.reliabilityNote.isNotEmpty, isTrue);
        }
      },
    );
  });

  group('LexicalDiversityCalculator Tests', () {
    test('computes TTR, MATTR, and MTLD accurately', () {
      const text =
          'The teacher explained the lesson. The teacher was patient and the lesson was clear.';
      final spans = TextTokenizer.extractWordSpans(text);
      final profileOutput = CefrProfiler.profileTokens(text, spans);
      final diversity = LexicalDiversityCalculator.calculate(
        profileOutput.tokens,
      );

      expect(diversity.ttr > 0.0 && diversity.ttr <= 1.0, isTrue);
      expect(diversity.mattr > 0.0, isTrue);
      expect(diversity.mtld > 0.0, isTrue);
      expect(
        diversity.topRepeatedWords.any(
          (e) => e.key == 'teacher' || e.key == 'lesson',
        ),
        isTrue,
      );
    });
  });

  group('SyntacticComplexityAnalyzer Tests', () {
    test('identifies compound, complex sentences, passive voice, and relative clauses', () {
      const text =
          'The book was written by a scientist who lives in London, although many critics disagreed with the hypothesis.';
      final sentences = TextTokenizer.extractSentences(text);
      final syntax = SyntacticComplexityAnalyzer.analyze(text, sentences);

      expect(syntax.sentenceCount, equals(1));
      expect(syntax.passiveVoiceCount >= 1, isTrue); // "was written"
      expect(syntax.relativeClauseCount >= 1, isTrue); // "who lives"
      expect(syntax.subordinateClauseCount >= 1, isTrue); // "although"
      expect(
        syntax.complexSentenceCount + syntax.compoundComplexSentenceCount,
        equals(1),
      );
    });
  });

  group('TextProfilerService Master Pipeline & Recommendations', () {
    test('produces comprehensive deterministic profile offline', () {
      const passage = '''
Many environmental researchers agree that passive smoking poses an increased risk of heart disease and lung cancer.
A preliminary investigation was conducted by the medical committee to evaluate alternative technological solutions.
Although some critics deliberately questioned the feasibility of the report, the majority supported the conclusion.
''';

      final profile = TextProfilerService.profile(passage);

      expect(profile.statistics.totalWords >= 40, isTrue);
      expect(profile.dominantCefrLevel, equals('B1'));
      expect(profile.readabilityMetrics.length, equals(6));
      expect(profile.recommendations.isNotEmpty, isTrue);
      expect(profile.examProfiles.any((e) => e.examName == 'VSTEP'), isTrue);
      expect(profile.vocabularyCoverage.preTeachWords.isNotEmpty, isTrue);

      // JSON serialization integrity
      final json = profile.toJson();
      expect(json['originalText'], isNotEmpty);
      expect(json['statistics'], isNotNull);
      expect(json['cefrCounts'], isNotNull);
      expect(json['readabilityMetrics'], isNotEmpty);
    });

    test('handles empty and malformed input gracefully', () {
      final emptyProfile = TextProfilerService.profile('');
      expect(emptyProfile.statistics.totalWords, equals(0));
      expect(emptyProfile.isShortText, isTrue);

      final punctOnlyProfile = TextProfilerService.profile('... ??? !!! ---');
      expect(punctOnlyProfile.statistics.totalWords, equals(0));
    });

    test('guarantees determinism on repeated runs', () {
      const text =
          'Education is the most powerful weapon which you can use to change the world.';
      final run1 = TextProfilerService.profile(text);
      final run2 = TextProfilerService.profile(text);

      expect(run1.statistics.totalWords, equals(run2.statistics.totalWords));
      expect(run1.dominantCefrLevel, equals(run2.dominantCefrLevel));
      expect(
        run1.readabilityMetrics[0].score,
        equals(run2.readabilityMetrics[0].score),
      );
      expect(run1.lexicalDiversity.ttr, equals(run2.lexicalDiversity.ttr));
    });
  });
}
