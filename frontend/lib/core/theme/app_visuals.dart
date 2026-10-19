import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const control = 8.0;
  static const toolbar = 10.0;
  static const panel = 12.0;
  static const badge = 6.0;
}

abstract final class AppMotion {
  static const Curve stateCurve = Curves.easeOutCubic;
  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Offset pageEnterOffset = Offset(0.015, 0);

  static Duration duration(BuildContext context, {int milliseconds = 180}) =>
      MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : Duration(milliseconds: milliseconds);
}

/// Subtle route motion for the desktop teaching workflow.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 165);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;

    final eased = CurvedAnimation(
      parent: animation,
      curve: AppMotion.enterCurve,
      reverseCurve: AppMotion.exitCurve,
    );
    final position = Tween<Offset>(
      begin: AppMotion.pageEnterOffset,
      end: Offset.zero,
    ).animate(eased);

    return FadeTransition(
      opacity: eased,
      child: SlideTransition(position: position, child: child),
    );
  }
}
