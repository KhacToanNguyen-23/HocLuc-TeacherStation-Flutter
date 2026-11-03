import 'package:english_assistant_engine/english_assistant_engine.dart';
import 'package:test/test.dart';

void main() {
  group('surface grammar rules', () {
    final analyzer = GrammarRuleAnalyzer();

    test('exposes parser-dependent rules as unsupported', () {
      expect(GrammarRuleAnalyzer.unsupportedRules, contains('PASSIVE_VOICE'));
      expect(GrammarRuleAnalyzer.unsupportedRules, contains('RELATIVE_CLAUSE'));
    });

    test('finds inversion with exact code-point span and style metadata', () {
      const text = '😀 Never have I seen such a view.';
      final matches = analyzer.analyze(text);
      final match = matches.singleWhere(
        (item) => item.ruleId == 'INVERSION_NEG',
      );

      expect(
        text.runes.toList().sublist(match.start, match.end),
        'Never have I seen'.runes.toList(),
      );
      expect(match.color, '#3B82F6');
      expect(match.example, 'Never have I seen');
    });

    test('matches supported surface patterns and rejects non-pattern text', () {
      expect(
        analyzer
            .analyze('Having finished the work, she left.')
            .map((item) => item.ruleId),
        contains('PARTICIPLE_PERFECT'),
      );
      expect(
        analyzer.analyze('She is used to working late.'),
        isNot(
          contains(
            predicate<GrammarRuleMatch>((item) => item.ruleId == 'USED_TO'),
          ),
        ),
      );
      expect(
        analyzer.analyze('They used to work late.').map((item) => item.ruleId),
        contains('USED_TO'),
      );
    });
  });

  test('collocation matches are exact, styled and source-aligned', () {
    const text = 'We should take into account.';
    final match = CollocationAnalyzer().analyze(text).single;
    expect(match.text, 'take into account');
    expect(
      text.runes.toList().sublist(match.start, match.end),
      match.text.runes,
    );
    expect(match.category, 'collocation');
    expect(match.color, '#10B981');
  });

  test('finds repeated collocations as separate passage locations', () {
    const text = 'Teachers take into account evidence and take into account context.';
    final matches = CollocationAnalyzer()
        .analyze(text)
        .where((item) => item.text == 'take into account')
        .toList();

    expect(matches, hasLength(2));
    expect(matches[0].start, isNot(matches[1].start));
    for (final match in matches) {
      expect(
        String.fromCharCodes(text.runes.toList().sublist(match.start, match.end)),
        match.text,
      );
    }
  });
}
