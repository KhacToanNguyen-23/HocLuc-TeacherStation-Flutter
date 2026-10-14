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
      return const Color(0xFF2563EB); // Royal Blue
    } else if (lower.contains('toán') || lower.contains('math')) {
      return const Color(0xFFD97706); // Amber
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return const Color(0xFF059669); // Emerald
    } else if (lower.contains('lý') || lower.contains('hóa') || lower.contains('sinh')) {
      return const Color(0xFF7C3AED); // Purple
    }
    return const Color(0xFF475569); // Slate
  }

  Color _getSubjectBg(String subject) {
    final lower = subject.toLowerCase();
    if (lower.contains('anh') || lower.contains('english')) {
      return const Color(0xFFEFF6FF);
    } else if (lower.contains('toán') || lower.contains('math')) {
      return const Color(0xFFFFFBEB);
    } else if (lower.contains('văn') || lower.contains('việt')) {
      return const Color(0xFFECFDF5);
    } else if (lower.contains('lý') || lower.contains('hóa') || lower.contains('sinh')) {
      return const Color(0xFFF5F3FF);
    }
    return const Color(0xFFF1F5F9);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.slate200),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.sky600),
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
            label: const Text('Soạn bài mới', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sky600,
              foregroundColor: Colors.white,
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.slate200)),
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
                        color: AppColors.slate900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sky50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Text(
                        '${filtered.length} bài',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sky600,
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
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.slate600),
                        isDense: true,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.slate900),
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
                        label: const Text('Soạn mới', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.sky600,
                          foregroundColor: Colors.white,
                          elevation: 1,
                          shadowColor: AppColors.sky600.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
              padding: const EdgeInsets.all(14),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final plan = filtered[index];
                final subjectColor = _getSubjectColor(plan.subject);
                final subjectBg = _getSubjectBg(plan.subject);

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.slate200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.015),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Subject icon or badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: subjectBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: subjectColor.withValues(alpha: 0.25)),
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
                                color: AppColors.slate900,
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
                                    const Icon(Icons.layers_outlined, size: 12, color: AppColors.slate500),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        '${plan.pageCount} trang',
                                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 12, color: AppColors.slate500),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        plan.formattedUpdatedAt,
                                        style: const TextStyle(fontSize: 11, color: AppColors.slate500),
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
                              icon: const Icon(Icons.edit_note_rounded, size: 20),
                              label: const Text('Soạn tiếp', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.slate700,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppColors.slate300, width: 1.2),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton.icon(
                              onPressed: () => onLaunch(plan),
                              icon: const Icon(Icons.videocam_rounded, size: 19),
                              label: const Text('Dạy ngay', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.sky600,
                                foregroundColor: Colors.white,
                                elevation: 1,
                                shadowColor: AppColors.sky600.withValues(alpha: 0.3),
                                padding: const EdgeInsets.symmetric(horizontal: 18),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 21, color: AppColors.slate400),
                              tooltip: 'Xóa kế hoạch bài giảng',
                              padding: EdgeInsets.zero,
                              hoverColor: const Color(0xFFFEE2E2),
                              style: IconButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
