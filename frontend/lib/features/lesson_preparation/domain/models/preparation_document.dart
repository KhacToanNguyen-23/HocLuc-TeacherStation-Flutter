import 'dart:convert';
import 'dart:math';
import 'preparation_section_tools.dart';
import 'preparation_types.dart';
export 'preparation_types.dart';

class PreparationDocument {
  PreparationDocument(this.data);
  final PreparationMap data;
  factory PreparationDocument.fromJson(PreparationMap value) =>
      PreparationDocument(Map<String, dynamic>.from(value));
  factory PreparationDocument.empty(String title, String subject) =>
      PreparationDocument({
        'schemaVersion': 1,
        'revision': 0,
        'title': title,
        'subject': subject,
        'sections': <PreparationMap>[],
        'scenes': <PreparationMap>[],
        'glossary': <PreparationMap>[],
      });
  int get revision => (data['revision'] as num?)?.toInt() ?? 0;
  String get title => data['title']?.toString() ?? 'Bài soạn';
  List<PreparationMap> rows(String key) => preparationRows(data[key]);
  void setRows(String key, List<PreparationMap> rows) => data[key] = rows;
  PreparationDocument copy() => PreparationDocument.fromJson(
    jsonDecode(jsonEncode(data)) as PreparationMap,
  );
  static String newId() => List.generate(
    16,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Student-facing projection intentionally excludes teacher notes and sources.
  PreparationMap studentProjection() => {
    'title': title,
    'sections': rows('sections').map(studentSectionProjection).toList(),
    'scenes': rows('scenes')
        .map(
          (s) => {
            'id': s['id'],
            'title': s['title'],
            'text': s['text'],
            'narration': s['narration'],
            'language': s['language'],
            'template': s['template'],
          },
        )
        .toList(),
  };
}
