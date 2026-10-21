import 'preparation_types.dart';

int preparationMinutes(dynamic value) => value is num ? value.toInt() : 0;

int activityMinutes(PreparationMap section) => preparationRows(
  section['activities'],
).fold(0, (total, row) => total + preparationMinutes(row['minutes']));

List<String> sectionChecks(PreparationMap section) {
  final warnings = <String>[];
  final activities = preparationRows(section['activities']);
  final allocation = preparationMinutes(section['minutes']);
  final total = activityMinutes(section);
  if (activities.isNotEmpty && total > allocation) {
    warnings.add(
      'Hoạt động cần $total phút, vượt $allocation phút đã dành cho phần này.',
    );
  }
  if (activities.isNotEmpty && '${section['objective'] ?? ''}'.trim().isEmpty) {
    warnings.add('Phần này chưa có mục tiêu để đối chiếu với hoạt động.');
  }
  for (var i = 0; i < activities.length; i++) {
    final a = activities[i];
    if ('${a['studentAction'] ?? ''}'.trim().isEmpty) {
      warnings.add('Hoạt động ${i + 1} chưa nêu việc học sinh làm.');
    }
    if ('${a['objectiveId'] ?? ''}'.isEmpty ||
        a['objectiveId'] != section['id']) {
      warnings.add('Hoạt động ${i + 1} chưa liên kết mục tiêu của phần này.');
    }
  }
  return warnings;
}

PreparationMap studentSectionProjection(PreparationMap section) => {
  if (section['questionBank'] is Map)
    'questionBank': {
      'images': preparationRows((section['questionBank'] as Map)['images'])
          .where((image) => image['private'] == false)
          .map(
            (image) => {
              'imageAssetId': image['imageAssetId'],
              'private': false,
            },
          )
          .toList(),
    },
  for (final key in ['id', 'title', 'body', 'objective', 'minutes'])
    if (section.containsKey(key)) key: section[key],
  'activities': preparationRows(section['activities'])
      .map(
        (a) => {
          for (final key in [
            'id',
            'title',
            'studentAction',
            'minutes',
            'objectiveId',
          ])
            if (a.containsKey(key)) key: a[key],
        },
      )
      .toList(),
  'supportCards': preparationRows(section['supportCards'])
      .where(
        (c) =>
            c['publicReviewed'] == true &&
            '${c['publicText'] ?? ''}'.trim().isNotEmpty &&
            c['publicReviewedText'] == c['publicText'],
      )
      .map(
        (c) => {
          'id': c['id'],
          'kind': c['kind'],
          'publicText': c['publicText'],
        },
      )
      .toList(),
};
