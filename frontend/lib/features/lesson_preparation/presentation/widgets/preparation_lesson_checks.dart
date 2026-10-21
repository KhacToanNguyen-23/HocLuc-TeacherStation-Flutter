import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../domain/models/preparation_section_tools.dart';
import 'preparation_editors.dart';

class PreparationLessonChecks extends StatelessWidget {
  const PreparationLessonChecks({
    super.key,
    required this.document,
    required this.onTargetChanged,
  });
  final PreparationDocument document;
  final ValueChanged<int> onTargetChanged;
  @override
  Widget build(BuildContext context) {
    final sections = document.rows('sections');
    final total = sections.fold<int>(
      0,
      (n, s) => n + preparationMinutes(s['minutes']),
    );
    final target = preparationMinutes(document.data['targetMinutes']);
    final warnings = <String>[
      if (target > 0 && total > target)
        'Bài cần $total phút, vượt mục tiêu $target phút.',
      for (final section in sections)
        ...sectionChecks(
          section,
        ).map((w) => '${section['title'] ?? 'Phần bài'}: $w'),
    ];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        'Thời lượng bài: $total phút${target > 0 ? ' / $target phút dự kiến' : ''}',
      ),
      subtitle: Text(
        warnings.isEmpty
            ? 'Đối chiếu mục tiêu và thời lượng (tùy chọn)'
            : '${warnings.length} điểm cần xem lại',
      ),
      children: [
        PreparationField(
          value: target == 0 ? '' : '$target',
          label: 'Thời lượng dự kiến của bài (phút, tùy chọn)',
          onChanged: (v) {
            if (v.trim().isEmpty) {
              onTargetChanged(0);
              return;
            }
            final value = int.tryParse(v);
            if (value != null && value >= 0 && value <= 1440) {
              onTargetChanged(value);
            }
          },
        ),
        for (final warning in warnings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline, size: 18),
            title: Text(warning),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}
