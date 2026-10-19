import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';

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
    padding: const EdgeInsets.all(AppSpacing.xxl),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.panel),
      border: Border.all(color: AppColors.surfaceBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.md,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text.rich(
              TextSpan(
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: EdgeInsets.only(right: AppSpacing.md),
                      child: Icon(
                        Icons.assignment_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  TextSpan(text: 'Đề thi & năng lực'),
                ],
              ),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                    child: TextButton.icon(
                      onPressed: () => onOpen(page),
                      icon: Icon(icon, size: 20, color: AppColors.primary),
                      label: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      style:
                          TextButton.styleFrom(
                            backgroundColor: AppColors.surfaceMuted,
                            foregroundColor: AppColors.textPrimary,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.lg,
                            ),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                          ).copyWith(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.pressed)) {
                                return AppColors.selected;
                              }
                              if (states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.focused)) {
                                return AppColors.sky50;
                              }
                              return AppColors.surfaceMuted;
                            }),
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

