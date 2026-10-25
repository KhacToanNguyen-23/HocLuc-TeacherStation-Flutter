import 'package:flutter/material.dart';

abstract final class AppRadii {
  static const control = 8.0;
  static const toolbar = 10.0;
  static const panel = 12.0;
  static const badge = 6.0;
}

abstract final class AppMotion {
  /// Strong ease-out curve (Emil Kowalski / iOS spring-like deceleration): cubic-bezier(0.23, 1, 0.32, 1).
  /// Starts fast and provides crisp immediate feedback without feeling sluggish.
  static const Curve easeOut = Cubic(0.23, 1.0, 0.32, 1.0);

  /// Strong ease-in-out curve for on-screen movement / morphing: cubic-bezier(0.77, 0, 0.175, 1).
  static const Curve easeInOut = Cubic(0.77, 0.0, 0.175, 1.0);

  /// iOS drawer & sheet curve: cubic-bezier(0.32, 0.72, 0, 1).
  static const Curve drawerCurve = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Standard state transition curve.
  static const Curve stateCurve = easeOut;

  /// Entrance curve: starts fast, settles smoothly.
  static const Curve enterCurve = easeOut;

  /// Exit curve: fast snappy exit (never ease-in, which causes a sluggish delay at the start).
  static const Curve exitCurve = easeOut;

  /// Subtle horizontal route offset.
  static const Offset pageEnterOffset = Offset(0.015, 0);

  /// Tactile button press scale (subtle 0.965, never scale to 0).
  static const double pressScale = 0.965;

  /// Tactile button press duration (fast 100ms).
  static const Duration pressDuration = Duration(milliseconds: 100);

  /// Tactile button release duration (140ms snappy return).
  static const Duration releaseDuration = Duration(milliseconds: 140);

  /// Dialog & modal entrance duration (under 300ms budget).
  static const Duration modalDuration = Duration(milliseconds: 200);

  /// Dialog & modal exit duration (snappy 150ms).
  static const Duration modalExitDuration = Duration(milliseconds: 150);

  /// Popover & floating HUD card duration (160ms).
  static const Duration popoverDuration = Duration(milliseconds: 160);

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
