import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

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
                  color: widget.primary
                      ? (_isPressed
                          ? AppColors.primaryPressed
                          : (_isHovered
                              ? AppColors.primaryHover
                              : AppColors.primary))
                      : (_isPressed
                          ? AppColors.selected
                          : _isHovered
                          ? AppColors.sky50
                          : AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(AppRadii.panel),
                  border: Border.all(
                    color: widget.primary
                        ? (_isFocused ? AppColors.sky : AppColors.primary)
                        : (_isFocused
                            ? AppColors.primary
                            : _isHovered
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : AppColors.surfaceBorder),
                    width: 1,
                  ),
                  boxShadow: widget.primary
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(
                              alpha: _isHovered ? 0.35 : 0.22,
                            ),
                            blurRadius: _isHovered ? 12 : 8,
                            offset: Offset(0, _isHovered ? 4 : 2),
                          ),
                          if (_isFocused)
                            BoxShadow(
                              color: AppColors.sky.withValues(alpha: 0.5),
                              spreadRadius: 2,
                            ),
                        ]
                      : _isFocused
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            spreadRadius: 1,
                          ),
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
                        color: widget.primary
                            ? Colors.white.withValues(alpha: 0.20)
                            : AppColors.selected,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Center(
                        child: Icon(
                          widget.icon,
                          size: 24,
                          color: widget.primary ? Colors.white : sky,
                        ),
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
                                    color: widget.primary
                                        ? Colors.white
                                        : (_isHovered ? sky : slate),
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
                                    color: widget.primary
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : AppColors.selected,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.badgeText!,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: widget.primary
                                          ? Colors.white
                                          : AppColors.primary,
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
                      color: widget.primary
                          ? Colors.white.withValues(alpha: 0.85)
                          : (_isHovered ? sky : AppColors.textMuted),
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

