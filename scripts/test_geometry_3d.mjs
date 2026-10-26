import assert from 'node:assert';
import { Geometry3DEngine } from '../plugins/math_studio/ui/render/geometry_3d_engine.js';

console.log('🧪 Testing NoteRenderer 3D Pedagogical Geometry Engine...');

const presets = ['pyramid_tri', 'pyramid_quad', 'prism_tri', 'cuboid', 'cone', 'cylinder'];
const engine = new Geometry3DEngine({ width: 500, height: 400 });

for (const preset of presets) {
  engine.setPreset(preset);
  const start = performance.now();
  const svg = engine.generateSvg({ theme: 'chalkboard' });
  const duration = performance.now() - start;

  assert(svg.includes('<svg'), `Must produce valid SVG tag for ${preset}`);
  assert(svg.includes('stroke-dasharray'), `Must contain SGK hidden dashed lines for ${preset}`);
  assert(duration < 25, `Rendering must complete in under 25ms (Actual: ${duration.toFixed(2)}ms)`);

  console.log(`✅ Preset "${preset}" rendered in ${duration.toFixed(2)}ms with SGK dashed hidden lines`);
}

// Test SGK presets and rotation
engine.resetToSgkView();
assert(Math.abs(engine.yaw - (-0.48)) < 1e-3, 'Must restore SGK yaw');
assert(Math.abs(engine.pitch - 0.38) < 1e-3, 'Must restore SGK pitch');

engine.rotateBy(0.2, -0.1);
const rotatedSvg = engine.generateSvg({ theme: 'paper' });
assert(rotatedSvg.includes('stroke='), 'Rotated view must render successfully');

console.log('🎉 ALL 3D GEOMETRY PEDAGOGICAL TESTS PASSED 100%!');

