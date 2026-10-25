import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

/// Emil Kowalski Design Engineering: Physical Modal Dialog Transition.
///
/// Animates modals smoothly from `scale(0.95) + opacity(0)` to `scale(1.0) + opacity(1)`
/// using a strong ease-out curve (`Cubic(0.23, 1, 0.32, 1)`) within a crisp 200ms budget.
/// Never scales from 0 and stays centered with GPU-accelerated compositing.
class AppModalTransition extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  final Alignment alignment;

  const AppModalTransition({
    super.key,
    required this.animation,
    required this.child,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }

    final curved = CurvedAnimation(
      parent: animation,
      curve: AppMotion.easeOut,
      reverseCurve: AppMotion.easeOut,
    );

    final scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(curved);

    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: scaleAnimation,
        alignment: alignment,
        child: child,
      ),
    );
  }
}

/// Helper function to display dialogs with Emil Kowalski standard modal entrance.
Future<T?> showAppModalDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x99000000),
  Duration duration = AppMotion.modalDuration,
  Alignment alignment = Alignment.center,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'Dismiss',
    barrierColor: barrierColor,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration,
    pageBuilder: (ctx, anim1, anim2) => builder(ctx),
    transitionBuilder: (ctx, anim1, anim2, child) => AppModalTransition(
      animation: anim1,
      alignment: alignment,
      child: child,
    ),
  );
}

