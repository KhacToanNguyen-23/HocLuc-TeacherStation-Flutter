import 'preparation_document.dart';

/// The same sequential, case-sensitive whole-term replacements as the worker.
String preparationSpokenText(String text, List<PreparationMap> glossary) {
  for (final entry in glossary) {
    final term = '${entry['term'] ?? ''}';
    if (term.isEmpty) continue;
    final word = RegExp(r'[\p{L}\p{N}_]', unicode: true);
    final prefix = word.hasMatch(term[0]) ? r'(?<![\p{L}\p{N}_])' : '';
    final suffix = word.hasMatch(term[term.length - 1])
        ? r'(?![\p{L}\p{N}_])'
        : '';
    final pattern = RegExp(
      '$prefix${RegExp.escape(term)}$suffix',
      unicode: true,
    );
    text = text.replaceAllMapped(
      pattern,
      (_) => '${entry['replacement'] ?? ''}',
    );
  }
  return text;
}

void preparationChangeGlossary(
  PreparationDocument document,
  List<PreparationMap> glossary,
) {
  final before = document.rows('glossary');
  final scenes = document.rows('scenes');
  for (final scene in scenes) {
    final text = '${scene['narration'] ?? ''}';
    if (preparationSpokenText(text, before) ==
        preparationSpokenText(text, glossary)) {
      continue;
    }
    scene['captionsReviewed'] = false;
    scene.remove('audioDuration');
    scene.remove('audioAssetId');
  }
  document.setRows('glossary', glossary);
  document.setRows('scenes', scenes);
}
