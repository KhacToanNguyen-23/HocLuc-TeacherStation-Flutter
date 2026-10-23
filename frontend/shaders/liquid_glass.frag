#version 320 es
#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform float u_refraction;
uniform float u_edge_strength;
uniform float u_specular_strength;
uniform float u_blur_sample_offset_pixels;
uniform float u_refraction_scale;
uniform float u_max_refraction_displacement_pixels;
uniform vec2 u_region_origin;
uniform vec2 u_region_size;

out vec4 frag_color;

vec3 sampleClamped(vec2 uv) {
  return texture(u_texture, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  // Convert to uniform top-down coordinates across all backends.
  vec2 topDownCoord = uv * u_size;
  bool hasRegion = (u_region_size.x > 1.0 && u_region_size.y > 1.0);
  vec2 regionOrigin = hasRegion ? u_region_origin : vec2(0.0);
  vec2 regionSize = hasRegion ? u_region_size : u_size;

  vec2 localCoord = topDownCoord - regionOrigin;
  vec2 localUv = clamp(localCoord / regionSize, vec2(0.0), vec2(1.0));
  vec2 centered = (localUv - vec2(0.5)) * 2.0;
  float radius = length(centered);
  vec2 direction = radius > 0.001 ? centered / radius : vec2(0.0);

  // Optical lens profile: stronger curvature towards edges of the glass pill
  float lens = (0.35 + 0.65 * smoothstep(0.25, 1.0, radius));
  float shortestSide = min(regionSize.x, regionSize.y);
  float refractionDistancePixels = min(
      u_refraction * u_refraction_scale * shortestSide,
      u_max_refraction_displacement_pixels);
  vec2 bend = direction * refractionDistancePixels * lens / u_size;
  vec2 refractedUv = clamp(uv + bend, vec2(0.001), vec2(0.999));

  // Normalized 3x3 binomial blur sampling
  vec2 blurOffset = vec2(u_blur_sample_offset_pixels) / u_size;
  vec2 diagonalOffset = blurOffset;
  vec3 sampledColor = sampleClamped(refractedUv) * 0.25;
  sampledColor += sampleClamped(refractedUv + vec2(blurOffset.x, 0.0)) * 0.125;
  sampledColor += sampleClamped(refractedUv - vec2(blurOffset.x, 0.0)) * 0.125;
  sampledColor += sampleClamped(refractedUv + vec2(0.0, blurOffset.y)) * 0.125;
  sampledColor += sampleClamped(refractedUv - vec2(0.0, blurOffset.y)) * 0.125;
  sampledColor += sampleClamped(refractedUv + vec2(diagonalOffset.x, diagonalOffset.y)) * 0.0625;
  sampledColor += sampleClamped(refractedUv + vec2(diagonalOffset.x, -diagonalOffset.y)) * 0.0625;
  sampledColor += sampleClamped(refractedUv + vec2(-diagonalOffset.x, diagonalOffset.y)) * 0.0625;
  sampledColor += sampleClamped(refractedUv - diagonalOffset) * 0.0625;

  // Localized edge rim and top-left specular highlight
  float edge = smoothstep(0.76, 1.0, max(abs(centered.x), abs(centered.y)));
  float highlight = pow(max(0.0, 1.0 - length(centered - vec2(-0.48, -0.58))), 10.0);
  vec3 glass = sampledColor * 0.96 + vec3(0.72, 0.86, 1.0) * edge * u_edge_strength;
  glass += vec3(1.0) * highlight * u_specular_strength;
  frag_color = vec4(glass, 1.0);
}
