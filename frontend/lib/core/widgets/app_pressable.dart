import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

/// Emil Kowalski Design Engineering: Tactile pressable primitive.
///
/// Provides subtle, physical scale-down feedback (`scale(0.965)`) on press down,
/// and snappy spring-like return on release, giving interactive UI elements
/// an immediate, responsive feel without triggering layout passes.
class AppPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final MouseCursor cursor;
  final HitTestBehavior behavior;
  final String? tooltip;
  final BorderRadius? borderRadius;

  const AppPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = AppMotion.pressScale,
    this.cursor = SystemMouseCursors.click,
    this.behavior = HitTestBehavior.opaque,
    this.tooltip,
    this.borderRadius,
  });

  @override
  State<AppPressable> createState() => _AppPressableState();
}

class _AppPressableState extends State<AppPressable> {
  bool _isPressed = false;
  bool _isFocused = false;

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (!_isPressed) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null && widget.onLongPress == null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final effectiveScale = (disabled || reduceMotion || !_isPressed)
        ? 1.0
        : widget.scaleDown;

    final duration = _isPressed
        ? AppMotion.pressDuration
        : AppMotion.releaseDuration;

    Widget content = AnimatedScale(
      scale: effectiveScale,
      duration: duration,
      curve: AppMotion.easeOut,
      child: widget.child,
    );

    if (_isFocused && !disabled) {
      content = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(AppRadii.control),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              spreadRadius: 1.5,
              blurRadius: 1.0,
            ),
          ],
        ),
        position: DecorationPosition.foreground,
        child: content,
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    Widget interactive = FocusableActionDetector(
      enabled: !disabled,
      mouseCursor: disabled ? SystemMouseCursors.basic : widget.cursor,
      onShowFocusHighlight: (val) {
        if (_isFocused != val) {
          setState(() => _isFocused = val);
        }
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            if (widget.onTap != null) {
              widget.onTap!();
            }
            return null;
          },
        ),
      },
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: content,
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        child: interactive,
      );
    }

    return interactive;
  }
}

