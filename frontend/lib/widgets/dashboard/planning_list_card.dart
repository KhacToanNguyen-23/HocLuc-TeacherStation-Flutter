import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/planning_meta.dart';
import 'dashboard_empty_card.dart';

class PlanningListCard extends StatelessWidget {
  const PlanningListCard({
    super.key,
    required this.plannings,
    required this.isLoading,
    required this.selectedSubject,
    required this.subjectOptions,
    required this.onSubjectChanged,
    required this.onCreateNew,
    required this.onEdit,
    required this.onLaunch,
    required this.onDelete,
  });

  final List<PlanningMeta> plannings;
  final bool isLoading;
  final String selectedSubject;
  final List<String> subjectOptions;
  final ValueChanged<String?> onSubjectChanged;
  final VoidCallback onCreateNew;
  final ValueChanged<PlanningMeta> onEdit;
  final ValueChanged<PlanningMeta> onLaunch;
  final ValueChanged<PlanningMeta> onDelete;

  Color _getSubjectColor(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('anh') || lower.contains('english')) {
      return AppColors.primary; // Royal Blue
    } else if (lower.contains('toán') || lower.contains('math')) {
      return AppColors.warning; // Amber
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return AppColors.success; // Emerald
    } else if (lower.contains('lý') ||
        lower.contains('hóa') ||
        lower.contains('sinh')) {
      return const Color(0xFF7C3AED); // Purple
    }
    return AppColors.textSecondary; // Slate
  }

  Color _getSubjectBg(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('anh') || lower.contains('english')) {
      return AppColors.sky50;
    } else if (lower.contains('toán') || lower.contains('math')) {
      return AppColors.warningSurface;
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return AppColors.successSurface;
    } else if (lower.contains('lý') ||
        lower.contains('hóa') ||
        lower.contains('sinh')) {
      return const Color(0xFFF5F3FF);
    }
    return AppColors.surfaceMuted;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadii.panel),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final filtered = selectedSubject == 'Tất cả'
        ? plannings
        : plannings.where((p) => p.subject == selectedSubject).toList();

    if (filtered.isEmpty) {
      return DashboardEmptyCard(
        title: 'Kế hoạch bài giảng',
        dropdownValue: selectedSubject,
        dropdownItems: subjectOptions,
        onDropdownChanged: onSubjectChanged,
        illustrationType: 'planning',
        emptyText: 'Chưa có kế hoạch bài giảng',
        actionButton: SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Soạn bài mới',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Kế hoạch bài giảng',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sky50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        '${filtered.length} bài',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                        isDense: true,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        items: subjectOptions.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: onSubjectChanged,
                      ),
                    ),
                    const SizedBox(width: 14),
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        onPressed: onCreateNew,
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'Soạn mới',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppRadii.control,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Planning List Cards
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final plan = filtered[index];
                final subjectColor = _getSubjectColor(plan.subject);
                final subjectBg = _getSubjectBg(plan.subject);

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      // Subject icon or badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: subjectBg,
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          border: Border.all(
                            color: subjectColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          plan.subject,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subjectColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Title & metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              plan.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 2,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.layers_outlined,
                                      size: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        '${plan.pageCount} trang',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.access_time_rounded,
                                      size: 12,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        plan.formattedUpdatedAt,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: () => onEdit(plan),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 20,
                              ),
                              label: const Text(
                                'Soạn tiếp',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.slate700,
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: AppColors.inputBorder,
                                  width: 1.2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.control,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () => onLaunch(plan),
                              icon: const Icon(
                                Icons.videocam_rounded,
                                size: 19,
                              ),
                              label: const Text(
                                'Dạy ngay',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shadowColor: AppColors.primary.withValues(
                                  alpha: 0.3,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.control,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 21,
                                color: AppColors.textMuted,
                              ),
                              tooltip: 'Xóa kế hoạch bài giảng',
                              padding: EdgeInsets.zero,
                              hoverColor: AppColors.errorSurface,
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.control,
                                  ),
                                ),
                              ),
                              onPressed: () => onDelete(plan),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
