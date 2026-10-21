import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_captions.dart';

void main() {
  test(
    'actual generated SRT becomes bilingual WebVTT without interpreting markup',
    () {
      final result = preparationWebVtt(
        '1\r\n00:00:00,200 --> 00:00:01,800\r\nWater rises.\r\nNước <b>bốc</b> & lên.\r\n',
      );
      expect(result, startsWith('WEBVTT\n\n'));
      expect(result, contains('00:00:00.200 --> 00:00:01.800'));
      expect(result, contains('Nước &lt;b&gt;bốc&lt;/b&gt; &amp; lên.'));
    },
  );
  test('subtitle attachment refuses oversized content', () {
    expect(
      () => preparationWebVtt(List.filled(2000001, 'x').join()),
      throwsFormatException,
    );
  });
}
