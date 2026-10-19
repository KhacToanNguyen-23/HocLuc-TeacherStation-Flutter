import 'package:flutter/material.dart';
import 'package:teaching_companion/constants/theme.dart';

/// Card container for Room List and History columns with educational illustrations.
class DashboardEmptyCard extends StatelessWidget {
  const DashboardEmptyCard({
    super.key,
    required this.title,
    this.dropdownValue,
    this.dropdownItems,
    this.onDropdownChanged,
    required this.illustrationType, // 'rooms' or 'history'
    required this.emptyText,
    this.subtitle,
    this.actionButton,
  });

  final String title;
  final String? dropdownValue;
  final List<String>? dropdownItems;
  final ValueChanged<String?>? onDropdownChanged;
  final String illustrationType;
  final String emptyText;
  final String? subtitle;
  final Widget? actionButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.panel),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (dropdownItems != null && dropdownItems!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue ?? dropdownItems!.first,
                        isDense: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        style: TextStyle(
                          fontFamily: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.fontFamily,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        items: dropdownItems!.map((item) {
                          return DropdownMenuItem<String>(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: onDropdownChanged,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Body: Empty state illustration
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIllustration(illustrationType),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      emptyText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      actionButton!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIllustration(String type) {
    final isRooms = type == 'rooms';
    final isPlanning = type == 'planning';

    return Stack(
      alignment: Alignment.center,
      children: [
        // Decorative background cloud/blob
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: isPlanning
                ? AppColors.successSurface
                : AppColors.sky50, // Soft Mint or Sky
            shape: BoxShape.circle,
          ),
        ),
        // Central educational icon
        Icon(
          isRooms
              ? Icons.public_rounded
              : isPlanning
              ? Icons.menu_book_rounded
              : Icons.history_edu_rounded,
          size: 36,
          color: AppColors.textPrimary,
        ),
        // Floating decorative badge
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isPlanning ? AppColors.success : AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(
              isRooms
                  ? Icons.send_rounded
                  : isPlanning
                  ? Icons.add_rounded
                  : Icons.search_rounded,
              size: 13,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

