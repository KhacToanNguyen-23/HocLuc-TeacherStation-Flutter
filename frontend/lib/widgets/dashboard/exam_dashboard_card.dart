import 'package:flutter/material.dart';
import '../../constants/theme.dart';

/// Visible entry points into the exam tools, using the existing dashboard theme.
class ExamDashboardCard extends StatelessWidget {
  const ExamDashboardCard({
    super.key,
    required this.onOpen,
    this.isAdmin = false,
  });

  final ValueChanged<int> onOpen;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.slate200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: AppColors.sky600,
                      ),
                    ),
                  ),
                  TextSpan(text: 'Đề thi & năng lực'),
                ],
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate900,
              ),
            ),
            TextButton.icon(
              onPressed: () => onOpen(0),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Mở tổng quan'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'V-ACT · HSA — quản lý đề, lớp học và kết quả kiểm tra.',
          style: TextStyle(fontSize: 13, color: AppColors.slate600),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth < 600
                ? 1
                : box.maxWidth < 1000
                ? 2
                : 3;
            final tileWidth = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (page, label, icon) in [
                  (1, 'Ngân hàng câu hỏi', Icons.menu_book_outlined),
                  (2, 'Tạo đề thi', Icons.note_add_outlined),
                  (3, 'Thư viện đề', Icons.folder_outlined),
                  (4, 'Lớp & học sinh', Icons.groups_outlined),
                  (5, 'Kết quả kiểm tra', Icons.fact_check_outlined),
                  (6, 'Phân tích năng lực', Icons.insights_outlined),
                  if (isAdmin) ...[
                    (7, 'Nguồn PDF & duyệt', Icons.upload_file_outlined),
                    (8, 'Ma trận', Icons.tune),
                  ],
                ])
                  SizedBox(
                    width: tileWidth,
                    child: OutlinedButton.icon(
                      onPressed: () => onOpen(page),
                      icon: Icon(icon, size: 20, color: AppColors.sky600),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.slate900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        minimumSize: const Size(0, 48),
                        side: const BorderSide(color: AppColors.slate200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}
