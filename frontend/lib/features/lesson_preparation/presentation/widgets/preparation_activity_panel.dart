import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';
import '../../domain/models/preparation_section_tools.dart';

class PreparationActivityPanel extends StatelessWidget {
  const PreparationActivityPanel({
    super.key,
    required this.section,
    required this.onChanged,
  });
  final PreparationMap section;
  final ValueChanged<List<PreparationMap>> onChanged;
  Future<void> _edit(BuildContext context, PreparationMap? existing) async {
    var title = '${existing?['title'] ?? ''}';
    var teacher = '${existing?['teacherAction'] ?? ''}';
    var student = '${existing?['studentAction'] ?? ''}';
    var minutes = preparationMinutes(existing?['minutes'] ?? 5);
    var linked = existing?['objectiveId'] == section['id'];
    final result = await showDialog<PreparationMap>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: Text(existing == null ? 'Thêm hoạt động' : 'Sửa hoạt động'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: title,
                    maxLength: 200,
                    decoration: const InputDecoration(
                      labelText: 'Tên hoạt động',
                    ),
                    onChanged: (v) => title = v,
                  ),
                  TextFormField(
                    initialValue: teacher,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Giáo viên làm gì? (riêng)',
                    ),
                    onChanged: (v) => teacher = v,
                  ),
                  TextFormField(
                    initialValue: student,
                    minLines: 2,
                    maxLines: 5,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Học sinh làm gì? (được xuất)',
                    ),
                    onChanged: (v) => student = v,
                  ),
                  TextFormField(
                    initialValue: '$minutes',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Thời lượng, 0–600 phút',
                    ),
                    onChanged: (v) =>
                        update(() => minutes = int.tryParse(v) ?? -1),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: linked,
                    title: const Text('Liên kết mục tiêu của phần này'),
                    subtitle: Text(
                      '${section['objective'] ?? ''}'.trim().isEmpty
                          ? 'Điền mục tiêu trong phần bài trước.'
                          : '${section['objective']}',
                    ),
                    onChanged: '${section['objective'] ?? ''}'.trim().isEmpty
                        ? null
                        : (v) => update(() => linked = v ?? false),
                  ),
                  const Text(
                    'Chỉ việc học sinh làm được đưa vào học liệu. Hướng dẫn riêng của giáo viên luôn ở ghi chú.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: minutes < 0 || minutes > 600
                  ? null
                  : () {
                      if (title.trim().isEmpty) return;
                      Navigator.pop(ctx, <String, dynamic>{
                        'id': existing?['id'] ?? PreparationDocument.newId(),
                        'title': title.trim(),
                        'teacherAction': teacher,
                        'studentAction': student,
                        'minutes': minutes,
                        if (linked) 'objectiveId': section['id'],
                      });
                    },
              child: const Text('Lưu hoạt động'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final rows = preparationRows(section['activities']);
    final index = rows.indexWhere((r) => r['id'] == result['id']);
    if (index < 0) {
      rows.add(result);
    } else {
      rows[index] = result;
    }
    onChanged(rows);
  }

  @override
  Widget build(BuildContext context) {
    final rows = preparationRows(section['activities']);
    final warnings = sectionChecks(section);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Hoạt động (${rows.length})'),
      subtitle: Text(
        '${activityMinutes(section)} / ${preparationMinutes(section['minutes'])} phút của phần',
      ),
      children: [
        for (final warning in warnings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline, size: 18),
            title: Text(warning),
          ),
        for (final row in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${row['title']} · ${row['minutes']} phút'),
            subtitle: Text(
              '${row['studentAction'] ?? ''}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _edit(context, row),
            trailing: IconButton(
              tooltip: 'Xóa hoạt động',
              icon: const Icon(Icons.delete_outline),
              onPressed: () =>
                  onChanged(rows.where((r) => r['id'] != row['id']).toList()),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add),
            label: const Text('Thêm hoạt động'),
          ),
        ),
      ],
    );
  }
}
