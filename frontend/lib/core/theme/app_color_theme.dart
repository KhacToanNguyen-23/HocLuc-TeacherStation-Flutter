import 'package:flutter/material.dart';
import 'app_palette.dart';

/// Flutter ThemeExtension implementing the Nordic Sky & Slate Blue color system.
///
/// Provides semantic tokens for light and dark environments with smooth interpolation.
class AppColorTheme extends ThemeExtension<AppColorTheme> {
  const AppColorTheme({
    required this.slatePrimary,
    required this.slateSurface,
    required this.slateBorder,
    required this.slateMuted,
    required this.skyAccent,
    required this.skyLight,
    required this.skySurface,
    required this.skyHover,
    required this.background,
    required this.surface,
    required this.amber,
    required this.emerald,
    required this.rose,
  });

  /// Deep slate brand color used for top navigation, primary headings, hero base.
  final Color slatePrimary;

  /// Secondary slate surface for cards, panels, and elevated containers.
  final Color slateSurface;

  /// Slate border color for cards, dividers, and outlined inputs.
  final Color slateBorder;

  /// Muted slate text and inactive icon color.
  final Color slateMuted;

  /// Nordic Sky blue interactive accent for primary buttons (Begin/CTA) and active tabs.
  final Color skyAccent;

  /// Bright sky blue for text badges, secondary highlights, and vibrant indicators.
  final Color skyLight;

  /// Tinted sky surface for badge backgrounds, chip selections, and hover tints.
  final Color skySurface;

  /// Darkened sky blue for button hover and pressed states.
  final Color skyHover;

  /// Main application background canvas (Nordic mist, eye-friendly off-white).
  final Color background;

  /// White surface for high-contrast content cards.
  final Color surface;

  /// Warm amber for scheduled classes, deadlines, and time badges.
  final Color amber;

  /// Soft emerald for online indicators and success feedback.
  final Color emerald;

  /// Soft rose for logout, destructive actions, and errors.
  final Color rose;

  /// Standard Light Mode preset (Nordic Mist & Deep Slate).
  factory AppColorTheme.light() {
    return const AppColorTheme(
      slatePrimary: AppPalette.textPrimary,
      slateSurface: AppPalette.surfaceMuted,
      slateBorder: AppPalette.border,
      slateMuted: AppPalette.textMuted,
      skyAccent: AppPalette.primary,
      skyLight: AppPalette.primary,
      skySurface: AppPalette.selected,
      skyHover: AppPalette.primaryHover,
      background: AppPalette.background,
      surface: AppPalette.surface,
      amber: AppPalette.warning,
      emerald: AppPalette.success,
      rose: AppPalette.error,
    );
  }

  /// Dark Mode preset (Slate Night).
  factory AppColorTheme.dark() {
    return const AppColorTheme(
      slatePrimary: Colors.white,
      slateSurface: Color(0xFF1E293B),
      slateBorder: Color(0xFF334155),
      slateMuted: Color(0xFF94A3B8),
      skyAccent: Color(0xFF38BDF8),
      skyLight: Color(0xFF7DD3FC),
      skySurface: Color(0xFF0C4A6E),
      skyHover: Color(0xFF0284C7),
      background: Color(0xFF0F172A),
      surface: Color(0xFF1E293B),
      amber: Color(0xFFFBBF24),
      emerald: Color(0xFF34D399),
      rose: Color(0xFFFB7185),
    );
  }

  @override
  AppColorTheme copyWith({
    Color? slatePrimary,
    Color? slateSurface,
    Color? slateBorder,
    Color? slateMuted,
    Color? skyAccent,
    Color? skyLight,
    Color? skySurface,
    Color? skyHover,
    Color? background,
    Color? surface,
    Color? amber,
    Color? emerald,
    Color? rose,
  }) {
    return AppColorTheme(
      slatePrimary: slatePrimary ?? this.slatePrimary,
      slateSurface: slateSurface ?? this.slateSurface,
      slateBorder: slateBorder ?? this.slateBorder,
      slateMuted: slateMuted ?? this.slateMuted,
      skyAccent: skyAccent ?? this.skyAccent,
      skyLight: skyLight ?? this.skyLight,
      skySurface: skySurface ?? this.skySurface,
      skyHover: skyHover ?? this.skyHover,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      amber: amber ?? this.amber,
      emerald: emerald ?? this.emerald,
      rose: rose ?? this.rose,
    );
  }

  @override
  AppColorTheme lerp(ThemeExtension<AppColorTheme>? other, double t) {
    if (other is! AppColorTheme) return this;
    return AppColorTheme(
      slatePrimary: Color.lerp(slatePrimary, other.slatePrimary, t)!,
      slateSurface: Color.lerp(slateSurface, other.slateSurface, t)!,
      slateBorder: Color.lerp(slateBorder, other.slateBorder, t)!,
      slateMuted: Color.lerp(slateMuted, other.slateMuted, t)!,
      skyAccent: Color.lerp(skyAccent, other.skyAccent, t)!,
      skyLight: Color.lerp(skyLight, other.skyLight, t)!,
      skySurface: Color.lerp(skySurface, other.skySurface, t)!,
      skyHover: Color.lerp(skyHover, other.skyHover, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
    );
  }
}

/// Convenience extension on [BuildContext] to access [AppColorTheme] cleanly.
extension AppColorThemeX on BuildContext {
  AppColorTheme get colorTheme =>
      Theme.of(this).extension<AppColorTheme>() ?? AppColorTheme.light();
}
