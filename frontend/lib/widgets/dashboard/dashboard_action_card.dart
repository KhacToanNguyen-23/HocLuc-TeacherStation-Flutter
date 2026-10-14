import 'package:flutter/material.dart';
import '../../constants/theme.dart';

/// Action card for top dashboard row (Join, Begin, Schedule).
class DashboardActionCard extends StatefulWidget {
  const DashboardActionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.onTap,
    this.badgeText,
    this.primary = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final String? badgeText;
  final bool primary;

  @override
  State<DashboardActionCard> createState() => _DashboardActionCardState();
}

class _DashboardActionCardState extends State<DashboardActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final sky = AppColors.sky600;
    final slate = AppColors.slate900;
    final slateBorder = AppColors.slate200;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          // Hover hiện lên (nhấc nhẹ 3px lên trên)
          transform: Matrix4.translationValues(0, _isHovered ? -3 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered ? sky : slateBorder,
              width: _isHovered ? 1.5 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? sky.withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: _isHovered ? 18 : 6,
                spreadRadius: _isHovered ? 1 : 0,
                offset: Offset(0, _isHovered ? 7 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon container
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isHovered ? AppColors.sky100 : AppColors.sky50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isHovered ? sky : const Color(0xFFBAE6FD),
                    width: _isHovered ? 1.4 : 1.0,
                  ),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    size: 24,
                    color: sky,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Labels
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _isHovered ? sky : slate,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (widget.badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.sky100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.sky600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                transform: Matrix4.translationValues(_isHovered ? 2 : 0, 0, 0),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: _isHovered ? sky : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
