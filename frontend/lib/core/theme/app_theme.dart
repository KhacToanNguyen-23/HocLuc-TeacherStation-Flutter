import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';

/// Appearance only: local sizes, padding and navigation remain with the screens.
abstract final class AppTheme {
  static ThemeData light({bool reduceMotion = false}) {
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    Color fill(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
      if (states.contains(WidgetState.pressed)) return AppColors.primaryPressed;
      if (states.contains(WidgetState.hovered)) return AppColors.primaryHover;
      return AppColors.primary;
    }

    Color ink(Set<WidgetState> states) => AppColors.onPrimary;
    Color overlay(Set<WidgetState> states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) {
        return AppColors.primary.withValues(alpha: 0.12);
      }
      if (states.contains(WidgetState.focused) ||
          states.contains(WidgetState.hovered)) {
        return AppColors.primary.withValues(alpha: 0.06);
      }
      return Colors.transparent;
    }

    BorderSide outline(Set<WidgetState> states) => BorderSide(
      color: states.contains(WidgetState.disabled)
          ? AppColors.border
          : states.contains(WidgetState.focused)
          ? AppColors.sky
          : states.contains(WidgetState.hovered)
          ? AppColors.sky
          : AppColors.inputBorder,
      width: states.contains(WidgetState.focused) ? 2 : 1,
    );
    final primaryStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(fill),
      foregroundColor: WidgetStateProperty.resolveWith(ink),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(shape),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? AppColors.onPrimary
              : Colors.transparent,
          width: 2,
        ),
      ),
      animationDuration: duration,
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    );
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Manrope',
      scaffoldBackgroundColor: AppColors.background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: AppPageTransitionsBuilder(),
          TargetPlatform.windows: AppPageTransitionsBuilder(),
          TargetPlatform.linux: AppPageTransitionsBuilder(),
        },
      ),
      extensions: [AppColorTheme.light()],
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary).copyWith(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.selected,
        onPrimaryContainer: AppColors.onSelected,
        secondary: AppColors.primaryHover,
        onSecondary: AppColors.onPrimary,
        secondaryContainer: AppColors.selected,
        onSecondaryContainer: AppColors.onSelected,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        onSurfaceVariant: AppColors.textSecondary,
        surfaceContainerLowest: AppColors.surface,
        surfaceContainerLow: AppColors.background,
        surfaceContainer: AppColors.surfaceMuted,
        surfaceContainerHigh: AppColors.surfaceMuted,
        surfaceContainerHighest: AppColors.surfaceSoft,
        surfaceTint: Colors.transparent,
        outline: AppColors.inputBorder,
        outlineVariant: AppColors.border,
        error: AppColors.error,
        onError: AppColors.onPrimary,
        errorContainer: AppColors.errorSurface,
        onErrorContainer: AppColors.error,
        inverseSurface: AppColors.textPrimary,
        onInverseSurface: AppColors.surface,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        bodySmall: TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: primaryStyle),
      filledButtonTheme: FilledButtonThemeData(style: primaryStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textMuted
                : AppColors.textPrimary,
          ),
          backgroundColor: const WidgetStatePropertyAll(AppColors.surface),
          overlayColor: WidgetStateProperty.resolveWith(overlay),
          side: WidgetStateProperty.resolveWith(outline),
          shape: WidgetStatePropertyAll(shape),
          animationDuration: duration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textMuted
                : AppColors.primary,
          ),
          overlayColor: WidgetStateProperty.resolveWith(overlay),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? AppColors.primary
                  : Colors.transparent,
            ),
          ),
          shape: WidgetStatePropertyAll(shape),
          animationDuration: duration,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textMuted
                : states.contains(WidgetState.selected)
                ? AppColors.onSelected
                : AppColors.textSecondary,
          ),
          overlayColor: WidgetStateProperty.resolveWith(overlay),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? AppColors.primary
                  : Colors.transparent,
            ),
          ),
          animationDuration: duration,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.sky, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.border),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.selected,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.scrollbarThumb),
        trackColor: const WidgetStatePropertyAll(AppColors.scrollbarTrack),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(8),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        // PDF viewers paint this over glyphs, so an opaque surface hides text.
        selectionColor: AppColors.primary.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.primary,
      ),
      tooltipTheme: const TooltipThemeData(
        textStyle: TextStyle(fontFamily: 'Manrope', color: AppColors.onPrimary),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: 'Manrope',
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}
