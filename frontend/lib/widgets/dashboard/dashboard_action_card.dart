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
  bool _isFocused = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final sky = AppColors.primary;
    final slate = AppColors.textPrimary;
    final slateBorder = AppColors.border;

    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: (value) => setState(() => _isHovered = value),
      onShowFocusHighlight: (value) => setState(() => _isFocused = value),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 220;
              return AnimatedContainer(
                duration: AppMotion.duration(context),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? AppSpacing.md : AppSpacing.xxl,
                  vertical: compact ? AppSpacing.lg : AppSpacing.xl,
                ),
                decoration: BoxDecoration(
                  color: _isPressed
                      ? AppColors.selected
                      : _isHovered
                      ? AppColors.sky50
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(
                    color: _isFocused
                        ? AppColors.primaryPressed
                        : _isHovered
                        ? sky
                        : slateBorder,
                    width: 1.2,
                  ),
                  boxShadow: _isFocused
                      ? const [
                          BoxShadow(color: AppColors.primary, spreadRadius: 1),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Icon container
                    AnimatedContainer(
                      duration: AppMotion.duration(context),
                      curve: AppMotion.stateCurve,
                      width: compact ? 40 : 48,
                      height: compact ? 40 : 48,
                      decoration: BoxDecoration(
                        color: _isHovered
                            ? AppColors.selected
                            : AppColors.sky50,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        border: Border.all(
                          color: _isHovered ? sky : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(widget.icon, size: 24, color: sky),
                      ),
                    ),
                    SizedBox(width: compact ? AppSpacing.sm : AppSpacing.md),
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
                                    fontSize: compact ? 14 : 16,
                                    fontWeight: FontWeight.w700,
                                    color: _isHovered ? sky : slate,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (widget.badgeText != null) ...[
                                const SizedBox(width: AppSpacing.xs),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.selected,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.badgeText!,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: _isHovered ? sky : AppColors.textMuted,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
