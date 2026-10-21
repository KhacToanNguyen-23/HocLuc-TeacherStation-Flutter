import 'package:flutter/material.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';

class SavedPlanningPicker extends StatefulWidget {
  const SavedPlanningPicker({super.key, required this.load});
  final Future<List<PlanningMeta>> Function() load;

  @override
  State<SavedPlanningPicker> createState() => _SavedPlanningPickerState();
}

class _SavedPlanningPickerState extends State<SavedPlanningPicker> {
  late Future<List<PlanningMeta>> _plans;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _plans = widget.load();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Mở bài đã soạn'),
    content: SizedBox(
      width: 560,
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Chọn bài để dùng trong phòng hiện tại. Phòng Meet và bài soạn gốc được giữ nguyên.',
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Tìm theo tên bài hoặc môn học',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<PlanningMeta>>(
              future: _plans,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Chưa tải được bài đã soạn. Kiểm tra kết nối và đăng nhập.',
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _plans = widget.load();
                          }),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }
                final all = snapshot.data ?? [];
                final rows =
                    all
                        .where(
                          (p) => '${p.title} ${p.subject}'
                              .toLowerCase()
                              .contains(_query),
                        )
                        .toList()
                      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                if (rows.isEmpty) {
                  return Center(
                    child: Text(
                      all.isEmpty
                          ? 'Chưa có bài đã lưu. Vào Soạn bài để chuẩn bị bài trước.'
                          : 'Không tìm thấy bài phù hợp.',
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final plan = rows[index];
                    return ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(plan.title),
                      subtitle: Text(
                        '${plan.subject} · ${plan.pageCount} trang · ${plan.formattedUpdatedAt}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pop(context, plan),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
    ],
  );
}
