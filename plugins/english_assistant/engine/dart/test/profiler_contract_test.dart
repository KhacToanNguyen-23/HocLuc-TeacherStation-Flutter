import 'package:test/test.dart';

import '../lib/english_assistant_engine.dart';

void main() {
  test(
    'profiles deterministically and emits exact Unicode code-point spans',
    () {
      final request = const AnalysisRequest(
        requestId: 'parity-1',
        text: '\u{1F600} A smart student reads. reads!',
      );
      final first = EnglishAssistantProfiler.analyze(request);
      final second = EnglishAssistantProfiler.analyze(request);
      final firstJson = first.toJson();
      final secondJson = second.toJson();
      (firstJson['analysis'] as Map).remove('analyzedAt');
      (secondJson['analysis'] as Map).remove('analyzedAt');

      expect(firstJson.toString(), secondJson.toString());
      expect(first.sourceKind, 'text');
      expect(first.offsetUnit, 'unicodeCodePoint');
      expect((firstJson['analysis'] as Map)['originalText'], request.text);
      for (final token in first.tokens) {
        final selected = String.fromCharCodes(
          request.text.runes.toList().sublist(token.start, token.end),
        );
        expect(selected, token.surface);
      }
      expect(first.profile.originalText, request.text);
      expect(
        first.profile.tokens.map((token) => token.startIndex),
        first.tokens.map((token) => token.start),
      );

      final smart = first.tokens.firstWhere(
        (token) => token.surface == 'smart',
      );
      expect(smart.start, 4);
      expect(smart.end, 9);
    },
  );

  test('handles empty and malformed requests safely', () {
    final empty = EnglishAssistantProfiler.analyze(
      const AnalysisRequest(requestId: 'empty', text: ' \n\t '),
    );
    expect(empty.profile.statistics.totalWords, 0);
    expect(empty.tokens, isEmpty);
    expect(
      EnglishAssistantProfiler.analyzeJson({'schemaVersion': 1}),
      isA<AnalysisResult>(),
    );
    expect(
      EnglishAssistantProfiler.analyzeJson({
        'schemaVersion': 1,
        'requestId': 'bad-offset-unit',
        'source': {'kind': 'text', 'offsetUnit': 'utf16', 'text': 'hello'},
      }).status,
      'invalidRequest',
    );
    expect(
      EnglishAssistantProfiler.analyzeJson({
        'schemaVersion': 1,
        'requestId': 'image-source-unsupported',
        'source': {'kind': 'image', 'bytes': 'AA=='},
      }).status,
      'invalidRequest',
    );
  });

  test('counts supplementary and combining code points in source offsets', () {
    const text = ' \u{1F600} e\u0301 smart';
    final result = EnglishAssistantProfiler.analyze(
      const AnalysisRequest(requestId: 'unicode', text: text),
    );
    final smart = result.tokens.firstWhere((token) => token.surface == 'smart');
    final selected = String.fromCharCodes(
      text.runes.toList().sublist(smart.start, smart.end),
    );

    expect(smart.start, 6);
    expect(selected, 'smart');
    expect((result.toJson()['analysis'] as Map)['originalText'], text);
  });

  test(
    'pre-teach word offsets use the same code-point source coordinate base',
    () {
      const text = '\u{1F600} notwithstanding the preliminary committee';
      final result = EnglishAssistantProfiler.analyze(
        const AnalysisRequest(requestId: 'pre-teach-offset', text: text),
      );
      final preTeach = result.profile.vocabularyCoverage.preTeachWords.first;
      final selected = String.fromCharCodes(
        text.runes.toList().sublist(preTeach.startIndex, preTeach.endIndex),
      );

      expect(selected, preTeach.surface);
      final serialized = result.toJson()['analysis'] as Map;
      final serializedPreTeach =
          (serialized['vocabularyCoverage'] as Map)['preTeachWords'] as List;
      expect(serializedPreTeach.first['startIndex'], preTeach.startIndex);
    },
  );
}
