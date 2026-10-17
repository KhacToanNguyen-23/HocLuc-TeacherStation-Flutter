import 'package:flutter/material.dart';
import '../../services/exam_api.dart';
import '../../widgets/exams/exam_widgets.dart';

/// Context blocks move and replace together; IDs never need manual copying.
class ExamPaperEditor extends StatefulWidget {
  const ExamPaperEditor({super.key, required this.api, required this.paper});
  final ExamApi api;
  final ExamRow paper;
  @override
  State<ExamPaperEditor> createState() => _ExamPaperEditorState();
}

class _ExamPaperEditorState extends State<ExamPaperEditor> {
  late final title = TextEditingController(
    text: widget.paper['title'].toString(),
  );
  late final instructions = TextEditingController(
    text: widget.paper['instructions']?.toString() ?? '',
  );
  late final duration = TextEditingController(
    text: widget.paper['durationMinutes'].toString(),
  );
  late List<List<ExamRow>> units = group(examRows(widget.paper['questions']));
  bool busy = false;
  Object? error;
  List<List<ExamRow>> group(List<ExamRow> questions) {
    final result = <List<ExamRow>>[];
    for (final q in questions) {
      if (q['groupId'] != null &&
          result.isNotEmpty &&
          result.last.first['groupId'] == q['groupId']) {
        result.last.add(q);
      } else {
        result.add([q]);
      }
    }
    return result;
  }

  Future<void> replace(int index) async {
    setState(() => busy = true);
    try {
      final old = units[index], first = old.first;
      final qs = examRows(
        await widget.api.get(
          'questions?${Uri(queryParameters: {'examType': first['examType'].toString(), 'examVersion': first['examVersion'].toString(), 'section': first['section'].toString()}).query}',
        ),
      );
      final grouped = <String, List<ExamRow>>{};
      for (final q in qs) {
        grouped
            .putIfAbsent(
              q['groupId']?.toString() ?? q['id'].toString(),
              () => [],
            )
            .add(q);
      }
      final used = units.expand((u) => u).map((q) => q['id']).toSet();
      String types(List<ExamRow> unit) {
        final t = unit.map((q) => q['type'].toString()).toList()..sort();
        return t.join(',');
      }

      final available = grouped.values
          .where(
            (u) =>
                u.length == old.length &&
                types(u) == types(old) &&
                u.every((q) => !used.contains(q['id'])),
          )
          .toList();
      if (!mounted) return;
      final picked = await showDialog<List<ExamRow>>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Chọn câu / nhóm thay thế'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (available.isEmpty)
                    const ExamEmpty('Chưa có câu/nhóm phù hợp.'),
                  for (final unit in available)
                    ListTile(
                      title: Text(unit.first['stem'].toString()),
                      subtitle: Text(
                        '${unit.length} câu · ${unit.first['skill']}',
                      ),
                      onTap: () => Navigator.pop(context, unit),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
          ],
        ),
      );
      if (picked != null && mounted) setState(() => units[index] = picked);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final minutes = int.tryParse(duration.text);
    if (minutes == null) {
      setState(() => error = StateError('Thời gian cần là số nguyên.'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.api.put('papers/${widget.paper['id']}', {
        'title': title.text,
        'instructions': instructions.text,
        'durationMinutes': minutes,
        'questionIds': units.expand((u) => u).map((q) => q['id']).toList(),
      });
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    title.dispose();
    instructions.dispose();
    duration.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SizedBox(
      width: 900,
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          ListTile(
            title: const Text(
              'Chỉnh sửa đề',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            trailing: IconButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: instructions,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Hướng dẫn'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: duration,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian (phút)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Kéo để đổi thứ tự. Nhóm ngữ cảnh luôn được giữ nguyên; hệ thống kiểm tra ma trận khi lưu.',
                ),
              ],
            ),
          ),
          if (error != null) ExamError(error!),
          if (busy) const LinearProgressIndicator(),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: units.length,
              onReorderItem: busy
                  ? (_, index) {}
                  : (from, to) => setState(() {
                      final unit = units.removeAt(from);
                      units.insert(to, unit);
                    }),
              itemBuilder: (context, index) {
                final unit = units[index];
                return Card(
                  key: ValueKey(unit.first['id']),
                  child: ListTile(
                    title: Text(
                      unit.first['stem'].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${unit.length} câu · ${unit.first['section']}',
                    ),
                    trailing: Padding(
                      padding: const EdgeInsets.only(right: 32),
                      child: TextButton(
                        onPressed: busy ? null : () => replace(index),
                        child: const Text('Thay thế'),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: busy ? null : save,
              child: const Text('Kiểm tra & lưu bản nháp'),
            ),
          ),
        ],
      ),
    ),
  );
}
