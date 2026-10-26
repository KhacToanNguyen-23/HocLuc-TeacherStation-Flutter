import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/widgets/glass_shader_parameters.dart';

void main() {
  group('GlassShaderParameters', () {
    test('converts preset blur sigma from logical pixels to device pixels', () {
      final parameters = GlassShaderParameters.fromPreset(
        GlassPreset.frosted,
        devicePixelRatio: 1.25,
      );

      expect(parameters.blurSigmaPixels, 25);
      expect(
        parameters.blurSampleOffsetPixels,
        closeTo(25 * 1.41421356, 0.0001),
      );
      expect(parameters.refraction, GlassPreset.frosted.refraction);
      expect(parameters.refractionScale, 4);
      expect(parameters.refractionDistancePixels(75), 8);
      expect(parameters.refractionDistancePixels(1080), 8);
      expect(parameters.rimIntensity, GlassPreset.frosted.rimIntensity);
      expect(
        parameters.specularIntensity,
        GlassPreset.frosted.specularIntensity,
      );
    });

    test('keeps clear and solid presets on their own shader settings', () {
      final clear = GlassShaderParameters.fromPreset(
        GlassPreset.clear,
        devicePixelRatio: 1,
      );
      final solid = GlassShaderParameters.fromPreset(
        GlassPreset.solid,
        devicePixelRatio: 2,
      );

      expect(clear.blurSigmaPixels, 10);
      expect(clear.blurSampleOffsetPixels, closeTo(10 * 1.41421356, 0.0001));
      expect(clear.refraction, GlassPreset.clear.refraction);
      expect(clear.refractionScale, 4);
      expect(clear.refractionDistancePixels(75), closeTo(6.6, 0.0001));
      expect(solid.blurSigmaPixels, 56);
      expect(solid.refraction, GlassPreset.solid.refraction);
    });

    test('rejects non-finite and non-positive device pixel ratios', () {
      expect(
        () => GlassShaderParameters.fromPreset(
          GlassPreset.frosted,
          devicePixelRatio: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => GlassShaderParameters.fromPreset(
          GlassPreset.frosted,
          devicePixelRatio: double.infinity,
        ),
        throwsArgumentError,
      );
    });

    test('exposes optional regional origin and size uniforms slot mapping', () {
      final parameters = GlassShaderParameters.fromPreset(
        GlassPreset.frosted,
        devicePixelRatio: 1.0,
      );
      expect(parameters.refractionScale, 4.0);
      expect(parameters.refractionDistancePixels(75), 8.0);
    });
  });
}
