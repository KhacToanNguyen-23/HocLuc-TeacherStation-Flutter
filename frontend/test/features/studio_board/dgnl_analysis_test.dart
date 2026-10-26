import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/services/dgnl_service.dart';
import 'package:teaching_companion/features/studio_board/services/profiler/dgnl_collocation_data.dart';

void main() {
  group('Passive Voice False Positive & Detection Tests', () {
    test(
      'Negative: "They are often slightly sensitive." produces NO passive voice',
      () {
        final res = DgnlService.fallbackAnalyze(
          'They are often slightly sensitive.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(
          passives,
          isEmpty,
          reason:
              'Trạng từ "often" kết thúc bằng -en không được bị nhận diện nhầm thành phân từ 2.',
        );
      },
    );

    test('Negative: "They are happy." produces NO passive voice', () {
      final res = DgnlService.fallbackAnalyze('They are happy.');
      final passives = res.highlights
          .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
          .toList();
      expect(passives, isEmpty);
    });

    test(
      'Negative: "They have different capacities." produces NO passive voice',
      () {
        final res = DgnlService.fallbackAnalyze(
          'They have different capacities.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(passives, isEmpty);
      },
    );

    test(
      'Positive: "The document is written in English." identifies "is written"',
      () {
        final res = DgnlService.fallbackAnalyze(
          'The document is written in English.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(passives, isNotEmpty);
        expect(passives.first['text'], equals('is written'));
      },
    );

    test(
      'Positive: "The food was prepared yesterday." identifies "was prepared"',
      () {
        final res = DgnlService.fallbackAnalyze(
          'The food was prepared yesterday.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(passives, isNotEmpty);
        expect(passives.first['text'], equals('was prepared'));
      },
    );

    test(
      'Positive: "The results have been published." identifies "been published"',
      () {
        final res = DgnlService.fallbackAnalyze(
          'The results have been published.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(passives, isNotEmpty);
        expect(passives.first['text'], equals('been published'));
      },
    );

    test(
      'Positive with adverb: "These methods are often used in laboratories."',
      () {
        final res = DgnlService.fallbackAnalyze(
          'These methods are often used in laboratories.',
        );
        final passives = res.highlights
            .where((h) => h['type'] == 'Câu bị động (Passive Voice)')
            .toList();
        expect(passives, isNotEmpty);
        expect(passives.first['text'], equals('are often used'));
      },
    );
  });

  group('Collocation Lexicon & Multiple Occurrence Tests', () {
    const fixturePassage =
        'People have varying capacities for tasting bitterness, and the differences appear to be genetic. '
        'About 75 percent of people are sensitive to the taste of the bitter compounds phenylthiocarbamide and 6-n-propylthiouracil. '
        'and 25 percent are insensitive. Those who are sensitive to phenylthiocarbamide seem to be less likely than others to eat '
        'cruciferous vegetables, according to Stephen Wooding, a geneticist at the University of Utah. '
        'Some people, known as supertasters, are especially sensitive to 6-n-propylthiouracil because they have an unusually high number of taste buds. '
        'Supertasters tend to shun all kinds of bitter-tasting things, including vegetable, coffee, and dark chocolate. '
        'Perhaps as a result, they tend to be thin. They are also less fond of alcoholic drinks, which are often slightly bitter.';

    test('extracts all required collocations from the target passage', () {
      final collocs = DgnlCollocationLexicon.extractCollocations(
        fixturePassage,
      );

      // 1. "sensitive to" appears 3 times in this passage
      final sensitiveOccurrences = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'sensitive to')
          .toList();
      expect(
        sensitiveOccurrences.length,
        equals(3),
        reason: '"sensitive to" xuất hiện 3 lần trong bài đọc mẫu.',
      );

      // Check distinct offsets for each occurrence
      expect(
        sensitiveOccurrences[0]['start'],
        isNot(equals(sensitiveOccurrences[1]['start'])),
      );
      expect(
        sensitiveOccurrences[1]['start'],
        isNot(equals(sensitiveOccurrences[2]['start'])),
      );

      // 2. "fond of"
      final fondOf = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'fond of')
          .toList();
      expect(fondOf, isNotEmpty);

      // 3. "tend to" appears 2 times
      final tendTo = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'tend to')
          .toList();
      expect(tendTo.length, equals(2));
      expect(tendTo[0]['start'], isNot(equals(tendTo[1]['start'])));

      // 4. "taste buds"
      final tasteBuds = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'taste buds')
          .toList();
      expect(tasteBuds, isNotEmpty);

      // 5. "as a result"
      final asAResult = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'as a result')
          .toList();
      expect(asAResult, isNotEmpty);

      // 6. "according to"
      final accordingTo = collocs
          .where((c) => c['text'].toString().toLowerCase() == 'according to')
          .toList();
      expect(accordingTo, isNotEmpty);
    });

    test('handles case-insensitivity and respects punctuation boundaries', () {
      const text =
          'ACCORDING TO the report, students are FOND OF reading. The result. They decided.';
      final collocs = DgnlCollocationLexicon.extractCollocations(text);

      expect(collocs.any((c) => c['text'] == 'ACCORDING TO'), isTrue);
      expect(collocs.any((c) => c['text'] == 'FOND OF'), isTrue);

      // "result. They" should NOT match "as a result"
      expect(
        collocs.any(
          (c) => c['text'].toString().toLowerCase().contains('result. they'),
        ),
        isFalse,
      );
    });
  });

  group('Vocabulary Filtering & Clean Layer Tests', () {
    const fixturePassage =
        'People have varying capacities for tasting bitterness, and the differences appear to be genetic. '
        'About 75 percent of people are sensitive to the taste of the bitter compounds phenylthiocarbamide. '
        'They are also less fond of alcoholic drinks, which are often slightly bitter.';

    test('excludes basic function words from vocabulary highlights', () {
      final res = DgnlService.fallbackAnalyze(fixturePassage);
      final vocabHighlights = res.highlights
          .where((h) => h['category'] == 'vocabulary')
          .toList();

      final vocabWords = vocabHighlights
          .map((v) => v['text'].toString().toLowerCase())
          .toSet();

      // Common grammatical function words must NOT be highlighted as isolated vocabulary targets
      expect(
        vocabWords.contains('the'),
        isFalse,
        reason: '"the" là mạo từ ngữ pháp, không phải từ vựng trọng tâm.',
      );
      expect(
        vocabWords.contains('and'),
        isFalse,
        reason: '"and" là liên từ đẳng lập.',
      );
      expect(
        vocabWords.contains('they'),
        isFalse,
        reason: '"they" là đại từ nhân xưng.',
      );
      expect(
        vocabWords.contains('are'),
        isFalse,
        reason: '"are" là trợ động từ.',
      );
      expect(vocabWords.contains('of'), isFalse, reason: '"of" là giới từ.');

      // Content words and AWL terms MUST be preserved
      expect(
        vocabWords.contains('capacities') || vocabWords.contains('varying'),
        isTrue,
      );
      expect(
        vocabWords.contains('genetic') || vocabWords.contains('sensitive'),
        isTrue,
      );
    });

    test('preserves exact character offsets for PDF highlighting', () {
      final res = DgnlService.fallbackAnalyze(fixturePassage);

      for (final hl in res.highlights) {
        final start = hl['start'] as int;
        final end = hl['end'] as int;
        final textSpan = fixturePassage.substring(start, end);

        expect(
          textSpan.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
          equals(
            hl['text'].toString().toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
          ),
          reason:
              'Tọa độ ký tự [start:end] phải khớp chính xác với đoạn văn bản gốc.',
        );
      }
    });

    test('classifies pedagogical vs non-pedagogical vocabulary clearly', () {
      final res = DgnlService.fallbackAnalyze(fixturePassage);
      final vocabHighlights = res.highlights
          .where((h) => h['category'] == 'vocabulary')
          .toList();

      final pedagogicalVocab = vocabHighlights
          .where((v) => v['isPedagogical'] == true)
          .toList();
      expect(pedagogicalVocab, isNotEmpty);

      // All pedagogical vocabulary should be B1, B2, C1, C2, or AWL
      for (final pv in pedagogicalVocab) {
        final lvl = pv['level'] as String;
        final isAwl = pv['isAcademic'] == true;
        final isPreTeach = pv['isPreTeach'] == true;
        expect(
          lvl == 'B1' ||
              lvl == 'B2' ||
              lvl == 'C1' ||
              lvl == 'C2' ||
              isAwl ||
              isPreTeach,
          isTrue,
        );
      }
    });
  });
}
