/// Visual glass strength shared by the host surface and plugin UI contract.
enum GlassPreset {
  clear(
    label: 'Clear',
    opacity: 0.15,
    blurSigma: 10,
    refraction: 0.022,
    rimIntensity: 0.42,
    specularIntensity: 0.14,
  ),
  frosted(
    label: 'Frosted',
    opacity: 0.28,
    blurSigma: 20,
    refraction: 0.035,
    rimIntensity: 0.68,
    specularIntensity: 0.22,
  ),
  solid(
    label: 'Solid',
    opacity: 0.85,
    blurSigma: 28,
    refraction: 0.014,
    rimIntensity: 0.86,
    specularIntensity: 0.32,
  );

  const GlassPreset({
    required this.label,
    required this.opacity,
    required this.blurSigma,
    required this.refraction,
    required this.rimIntensity,
    required this.specularIntensity,
  });

  final String label;
  final double opacity;
  final double blurSigma;
  final double refraction;
  final double rimIntensity;
  final double specularIntensity;

  GlassPreset get next => switch (this) {
    GlassPreset.clear => GlassPreset.frosted,
    GlassPreset.frosted => GlassPreset.solid,
    GlassPreset.solid => GlassPreset.clear,
  };
}
