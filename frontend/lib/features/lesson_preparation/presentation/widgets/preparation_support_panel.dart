import 'package:flutter/material.dart';
import '../../domain/models/preparation_document.dart';

class PreparationSupportPanel extends StatelessWidget {
  const PreparationSupportPanel({
    super.key,
    required this.section,
    required this.onChanged,
  });
  final PreparationMap section;
  final ValueChanged<List<PreparationMap>> onChanged;
  static const kinds = {
    'example': 'Ví dụ / lời giải mẫu',
    'misconception': 'Lỗi hiểu sai / phản ví dụ',
    'hint': 'Gợi ý từng bước',
  };
  Future<void> _edit(BuildContext context, PreparationMap? existing) async {
    var kind = '${existing?['kind'] ?? 'hint'}';
    var teacher = '${existing?['teacherText'] ?? ''}';
    var public = '${existing?['publicText'] ?? ''}';
    var reviewed = existing?['publicReviewed'] == true;
    final result = await showDialog<PreparationMap>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Thẻ hỗ trợ giảng dạy'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Loại thẻ'),
                    items: kinds.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => update(() {
                      kind = v ?? 'hint';
                      reviewed = false;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: teacher,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 8000,
                    decoration: const InputDecoration(
                      labelText: 'Lời giải / hướng dẫn riêng giáo viên',
                    ),
                    onChanged: (v) => teacher = v,
                  ),
                  TextFormField(
                    initialValue: public,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Nội dung cho học sinh (tùy chọn)',
                    ),
                    onChanged: (v) => update(() {
                      public = v;
                      reviewed = false;
                    }),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reviewed,
                    title: const Text(
                      'Tôi đã duyệt chính nội dung phía trên để xuất cho học sinh',
                    ),
                    subtitle: const Text(
                      'Mặc định riêng tư. Sửa nội dung công khai sẽ yêu cầu duyệt lại; lời giải riêng luôn bị loại khỏi học liệu.',
                    ),
                    onChanged: public.trim().isEmpty
                        ? null
                        : (v) => update(() => reviewed = v ?? false),
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
              onPressed: () => Navigator.pop(ctx, <String, dynamic>{
                'id': existing?['id'] ?? PreparationDocument.newId(),
                'kind': kind,
                'teacherText': teacher,
                'publicText': public,
                'publicReviewed': reviewed && public.trim().isNotEmpty,
                if (reviewed && public.trim().isNotEmpty)
                  'publicReviewedText': public,
              }),
              child: const Text('Lưu thẻ'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    final rows = preparationRows(section['supportCards']);
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
    final rows = preparationRows(section['supportCards']);
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text('Thẻ hỗ trợ (${rows.length})'),
      subtitle: const Text('Ví dụ, lỗi dễ nhầm, gợi ý · riêng tư mặc định'),
      children: [
        for (final row in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              row['publicReviewed'] == true
                  ? Icons.fact_check_outlined
                  : Icons.lock_outline,
            ),
            title: Text(kinds['${row['kind']}'] ?? 'Thẻ hỗ trợ'),
            subtitle: Text(
              row['publicReviewed'] == true
                  ? 'Có nội dung học sinh đã duyệt'
                  : 'Chỉ giáo viên',
            ),
            onTap: () => _edit(context, row),
            trailing: IconButton(
              tooltip: 'Xóa thẻ',
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
            label: const Text('Thêm thẻ hỗ trợ'),
          ),
        ),
      ],
    );
  }
}
