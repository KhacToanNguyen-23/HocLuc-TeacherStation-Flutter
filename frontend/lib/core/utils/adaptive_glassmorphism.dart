import 'dart:ui';

/// Theme variation for context-aware glassmorphism surfaces.
enum AdaptiveGlassTheme {
  /// Default translucent Liquid Glass appearance for chalkboard and neutral stages.
  liquidGlass,

  /// High-contrast frosted glass appearance optimized for readability over document text.
  pdfGlass;

  bool get isPdfGlass => this == AdaptiveGlassTheme.pdfGlass;
}

/// Computes the ratio of geometric overlap between a floating component bounds
/// and a target viewport bounds:
///   `overlapRatio = intersectionArea / componentVisibleArea`
///
/// Returns a value clamped to the range `[0.0, 1.0]`.
/// Returns `0.0` if either bounds is empty or null, or if they do not intersect.
double computeGeometricOverlapRatio(Rect componentBounds, Rect? viewportBounds) {
  if (viewportBounds == null ||
      viewportBounds.isEmpty ||
      componentBounds.isEmpty) {
    return 0.0;
  }

  final intersection = componentBounds.intersect(viewportBounds);
  if (intersection.width <= 0 || intersection.height <= 0) {
    return 0.0;
  }

  final componentArea = componentBounds.width * componentBounds.height;
  if (componentArea <= 0) return 0.0;

  final intersectionArea = intersection.width * intersection.height;
  return (intersectionArea / componentArea).clamp(0.0, 1.0);
}

/// State controller that manages adaptive glassmorphism theme transitions with
/// configurable enter/exit hysteresis thresholds to prevent flickering.
class AdaptiveGlassmorphismController {
  AdaptiveGlassmorphismController({
    this.enterPdfThreshold = 0.20,
    this.exitPdfThreshold = 0.05,
    AdaptiveGlassTheme initialTheme = AdaptiveGlassTheme.liquidGlass,
  })  : assert(
          exitPdfThreshold <= enterPdfThreshold,
          'exitPdfThreshold ($exitPdfThreshold) must be <= enterPdfThreshold ($enterPdfThreshold)',
        ),
        _theme = initialTheme;

  /// The overlap ratio required to transition from Liquid Glass to PDF Glass (default: 0.20 = 20%).
  final double enterPdfThreshold;

  /// The overlap ratio required to transition from PDF Glass to Liquid Glass (default: 0.05 = 5%).
  final double exitPdfThreshold;

  AdaptiveGlassTheme _theme;

  /// Current active adaptive theme state.
  AdaptiveGlassTheme get theme => _theme;

  /// Convenience getter for whether PDF Glass is active.
  bool get isPdfGlass => _theme == AdaptiveGlassTheme.pdfGlass;

  /// Updates the theme state based on the current [overlapRatio] using hysteresis.
  ///
  /// - When in `liquidGlass`: switches to `pdfGlass` if `overlapRatio >= enterPdfThreshold`.
  /// - When in `pdfGlass`: switches to `liquidGlass` if `overlapRatio <= exitPdfThreshold`.
  /// - Between `exitPdfThreshold` and `enterPdfThreshold`: retains prior state to avoid flickering.
  ///
  /// Returns `true` if the theme state actually changed, `false` otherwise.
  bool updateOverlap(double overlapRatio) {
    if (_theme == AdaptiveGlassTheme.pdfGlass) {
      if (overlapRatio <= exitPdfThreshold) {
        _theme = AdaptiveGlassTheme.liquidGlass;
        return true;
      }
    } else {
      if (overlapRatio >= enterPdfThreshold) {
        _theme = AdaptiveGlassTheme.pdfGlass;
        return true;
      }
    }
    return false;
  }

  /// Resets the controller to the given [theme].
  void reset({AdaptiveGlassTheme theme = AdaptiveGlassTheme.liquidGlass}) {
    _theme = theme;
  }
}

