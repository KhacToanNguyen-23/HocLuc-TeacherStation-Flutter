import { parseAndAnalyze } from '../plugins/math_studio/ui/core/expression_parser.js';
import { generateGraphSvg } from '../plugins/math_studio/ui/render/graph_plotter.js';
import assert from 'assert';

console.log('🧪 Testing NoteRenderer 2.5D Solid of Revolution Engine...');

// Test 1: y = 1.5 + sin(x) rotated around Ox (The Vase model in the user video)
const analysisSin = parseAndAnalyze('1.5 + sin(x)');
const intResultSin = { a: 0, b: 6, displayArea: '10.5' };

const t0 = performance.now();
const svgSin = generateGraphSvg(analysisSin, intResultSin, {
  isRevolved: true,
  theme: 'chalkboard'
});
const dtSin = performance.now() - t0;

assert(svgSin.includes('revolution-solid-group'), 'Must contain revolution-solid-group');
assert(svgSin.includes('cross-section-ellipse'), 'Must contain cross-section ellipses');
assert(svgSin.includes('stroke-dasharray'), 'Must contain dashed hidden back arcs for 3D depth');
assert(dtSin < 30, `Generation must be under 30ms, took ${dtSin.toFixed(2)}ms`);
console.log(`✅ Test 1: y = 1.5 + sin(x) vase revolution generated in ${dtSin.toFixed(2)}ms`);

// Test 2: Parabola y = x^2 on [0, 2] (Cone-like solid)
const analysisParabola = parseAndAnalyze('x^2');
const intResultParabola = { a: 0, b: 2, displayArea: '2.67' };

const svgParabola = generateGraphSvg(analysisParabola, intResultParabola, {
  isRevolved: true,
  theme: 'light'
});

assert(svgParabola.includes('revolution-solid-group'), 'Parabola must have revolution solid');
assert(svgParabola.includes('cross-section-ellipse'), 'Parabola must have cross-section ellipse');
console.log('✅ Test 2: y = x^2 revolution solid generated successfully');

// Test 3: Normal 2D mode without isRevolved
const svg2D = generateGraphSvg(analysisSin, intResultSin, { isRevolved: false });
assert(!svg2D.includes('revolution-solid-group'), 'Standard 2D mode must not have 3D revolution solid');
console.log('✅ Test 3: Standard 2D mode unaffected by revolution engine');

console.log('🎉 ALL REVOLUTION SOLID ENGINE TESTS PASSED 100%!');

