import 'package:flutter/material.dart';
import '../../constants/theme.dart';

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
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (dropdownItems != null && dropdownItems!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue ?? dropdownItems!.first,
                        isDense: true,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF6B7280)),
                        style: TextStyle(fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                          fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
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
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildIllustration(illustrationType),
                    const SizedBox(height: 16),
                    Text(
                      emptyText,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    if (actionButton != null) ...[
                      const SizedBox(height: 16),
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
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: isPlanning ? const Color(0xFFF0FDF4) : AppColors.sky50, // Soft Mint or Sky
            shape: BoxShape.circle,
            border: Border.all(
              color: isPlanning ? const Color(0xFFBBF7D0) : const Color(0xFFBAE6FD),
              width: 1.5,
            ),
          ),
        ),
        // Central educational icon
        Icon(
          isRooms
              ? Icons.public_rounded
              : isPlanning
                  ? Icons.menu_book_rounded
                  : Icons.history_edu_rounded,
          size: 44,
          color: AppColors.slate900,
        ),
        // Floating decorative badge
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isPlanning ? const Color(0xFF16A34A) : AppColors.sky600,
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
