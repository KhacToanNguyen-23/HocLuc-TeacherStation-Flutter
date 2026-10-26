import 'dart:ui' as ui;

import 'package:teaching_companion/core/theme/glass_preset.dart';

/// Device-pixel shader uniforms shared by host-owned glass surfaces.
class GlassShaderParameters {
  static const double refractionScaleFactor = 4;
  static const double maxRefractionDisplacementPixels = 8;

  const GlassShaderParameters({
    required this.refraction,
    required this.refractionScale,
    required this.rimIntensity,
    required this.specularIntensity,
    required this.blurSigmaPixels,
    required this.blurSampleOffsetPixels,
  });

  factory GlassShaderParameters.fromPreset(
    GlassPreset preset, {
    required double devicePixelRatio,
  }) {
    if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) {
      throw ArgumentError.value(
        devicePixelRatio,
        'devicePixelRatio',
        'Must be a finite positive number.',
      );
    }

    return GlassShaderParameters(
      refraction: preset.refraction,
      refractionScale: refractionScaleFactor,
      rimIntensity: preset.rimIntensity,
      specularIntensity: preset.specularIntensity,
      blurSigmaPixels: preset.blurSigma * devicePixelRatio,
      blurSampleOffsetPixels:
          preset.blurSigma * devicePixelRatio * 1.4142135623730951,
    );
  }

  final double refraction;
  final double refractionScale;
  final double rimIntensity;
  final double specularIntensity;
  final double blurSigmaPixels;
  final double blurSampleOffsetPixels;

  double refractionDistancePixels(double shortestSidePixels) {
    final distance = refraction * refractionScale * shortestSidePixels;
    return distance < maxRefractionDisplacementPixels
        ? distance
        : maxRefractionDisplacementPixels;
  }

  /// The filter reserves float slots 0 and 1 for the input texture size.
  /// Float slots 8..11 pass the physical pixel bounds of the glass container
  /// (regionOrigin.x, regionOrigin.y, regionSize.width, regionSize.height)
  /// so refraction and specular highlights center on this specific element.
  void applyTo(
    ui.FragmentShader shader, {
    ui.Offset? regionOrigin,
    ui.Size? regionSize,
  }) {
    shader
      ..setFloat(2, refraction)
      ..setFloat(3, rimIntensity)
      ..setFloat(4, specularIntensity)
      ..setFloat(5, blurSampleOffsetPixels)
      ..setFloat(6, refractionScale)
      ..setFloat(7, maxRefractionDisplacementPixels)
      ..setFloat(8, regionOrigin?.dx ?? 0.0)
      ..setFloat(9, regionOrigin?.dy ?? 0.0)
      ..setFloat(10, regionSize?.width ?? 0.0)
      ..setFloat(11, regionSize?.height ?? 0.0);
  }
}
