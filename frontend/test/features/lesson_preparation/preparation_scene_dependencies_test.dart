import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_document.dart';
import 'package:teaching_companion/features/lesson_preparation/domain/models/preparation_scene_dependencies.dart';

void main() {
  test('glossary only invalidates scenes whose spoken output changes', () {
    final doc = PreparationDocument.empty('Lesson', 'Subject');
    doc.setRows('scenes', [
      {
        'id': 'a',
        'narration': 'Read API.',
        'audioAssetId': 'audio-a',
        'audioDuration': 2,
        'captionsReviewed': true,
        'locked': true,
      },
      {
        'id': 'b',
        'narration': 'APIs and mathematics.',
        'audioAssetId': 'audio-b',
        'audioDuration': 4,
        'captionsReviewed': true,
      },
    ]);
    preparationChangeGlossary(doc, [
      {'term': 'API', 'replacement': 'A P I'},
    ]);
    expect(doc.rows('scenes')[0]['audioAssetId'], isNull);
    expect(doc.rows('scenes')[0]['captionsReviewed'], false);
    expect(doc.rows('scenes')[0]['locked'], true);
    expect(doc.rows('scenes')[1]['audioAssetId'], 'audio-b');
    expect(doc.rows('scenes')[1]['captionsReviewed'], true);
  });
  test(
    'unchanged glossary pronunciation keeps audio; removing replacement invalidates',
    () {
      final doc = PreparationDocument.empty('Lesson', 'Subject');
      doc.setRows('glossary', [
        {'term': 'API', 'replacement': 'A P I'},
      ]);
      doc.setRows('scenes', [
        {'id': 'a', 'narration': 'API', 'audioAssetId': 'a'},
      ]);
      preparationChangeGlossary(doc, [
        {'term': 'API', 'replacement': 'A P I'},
        {'term': 'absent', 'replacement': 'x'},
      ]);
      expect(doc.rows('scenes').single['audioAssetId'], 'a');
      preparationChangeGlossary(doc, []);
      expect(doc.rows('scenes').single['audioAssetId'], isNull);
    },
  );
  test(
    'literal glossary replacement matches worker whole words and casing',
    () {
      expect(
        preparationSpokenText('C++ API APIs api', [
          {'term': 'C++', 'replacement': r'\1'},
          {'term': 'API', 'replacement': 'A P I'},
        ]),
        r'\1 A P I APIs api',
      );
    },
  );
}
