import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/smart_chalk_annotation.dart';

void main() {
  test('plain chalk annotation round-trips text and geometry', () {
    final annotation = SmartChalkAnnotation(
      id: 'chalk-note-1',
      source: 'chalkboard',
      pageIndex: 2,
      rawText: 'A note on the board',
      normalizedBounds: const Rect.fromLTWH(.2, .3, .4, .1),
      tokens: const [
        ChalkWordToken(word: 'A', relativeRect: Rect.fromLTWH(0, 0, .1, 1)),
        ChalkWordToken(
          word: 'note',
          relativeRect: Rect.fromLTWH(.15, 0, .3, 1),
        ),
      ],
      normalizedOffset: const Offset(.02, .01),
    );

    final restored = SmartChalkAnnotation.fromJson(annotation.toJson());
    expect(restored.id, 'chalk-note-1');
    expect(restored.rawText, 'A note on the board');
    expect(restored.pageIndex, 2);
    expect(restored.tokens.map((token) => token.word), ['A', 'note']);
    expect(restored.normalizedBounds.left, closeTo(.2, .001));
    expect(restored.normalizedOffset.dx, closeTo(.02, .001));
  });

  test('legacy role colors deserialize as neutral unclassified text', () {
    final token = ChalkWordToken.fromJson({
      'word': 'teacher',
      'role': 'subject',
      'color': const Color(0xff89b4fa).toARGB32(),
      'relativeRect': [0, 0, 1, 1],
    });

    expect(token.color, ChalkWordToken.neutralColor);
    expect(token.toJson().containsKey('role'), isFalse);
  });
}
