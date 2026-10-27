import assert from 'assert';
import { parseAndAnalyze } from '../plugins/math_studio/ui/core/expression_parser.js';
import { computeFormulaFromDrag } from '../plugins/math_studio/ui/core/curve_manipulator.js';

console.log('🧪 Testing Curve Manipulator...');

// Test 1: Cubic Polynomial Extremum Drag
{
  const cubic = parseAndAnalyze('x^3 - 3*x');
  assert.strictEqual(cubic.type, 'cas_function');
  assert.strictEqual(cubic.extrema.length, 2);

  // Drag first extremum (-1, 2) to (-1, 4)
  const newExpr = computeFormulaFromDrag(cubic, { type: 'extremum', idx: 0 }, -1, 4);
  assert.ok(newExpr, 'Must produce a new expression string');
  console.log('✅ Cubic drag result:', newExpr);

  // Check that the new formula is valid and can be re-analyzed
  const reAnalyzed = parseAndAnalyze(newExpr);
  assert.strictEqual(reAnalyzed.type, 'cas_function');
}

// Test 2: Quadratic Parabola Vertex Drag
{
  const quad = parseAndAnalyze('x^2 - 4');
  assert.strictEqual(quad.type, 'cas_function');
  assert.strictEqual(quad.extrema.length, 1);

  // Drag extremum from (0, -4) to (0, -2)
  const newExpr = computeFormulaFromDrag(quad, { type: 'extremum', idx: 0 }, 0, -2);
  assert.ok(newExpr, 'Must produce a new quadratic formula');
  console.log('✅ Quadratic vertex drag result:', newExpr);
}

// Test 3: Trigonometric Function Extremum Drag (sin(x)^2 + 1)
{
  const trig = parseAndAnalyze('sin(x)^2 + 1');
  assert.strictEqual(trig.type, 'cas_function');
  assert.ok(trig.extrema.length > 0, 'Must detect extrema on trig curve');

  // Drag first extremum up by +1 (e.g. from y=2 to y=3)
  const ext0 = trig.extrema[0];
  const newExpr = computeFormulaFromDrag(trig, { type: 'extremum', idx: 0 }, ext0.x, ext0.y + 1);
  assert.ok(newExpr, 'Must produce a shifted expression for general function');
  assert.ok(newExpr.includes('sin(x)^2 + 2') || newExpr.includes('+ 2'), 'Must update vertical constant');
  console.log('✅ Trig extremum drag result:', newExpr);

  // Check that the new formula evaluates correctly
  const reAnalyzed = parseAndAnalyze(newExpr);
  assert.strictEqual(reAnalyzed.type, 'cas_function');
}

// Test 4: High-Degree Polynomial Extremum Drag (x^5 - 5x)
{
  const poly5 = parseAndAnalyze('x^5 - 5*x');
  assert.strictEqual(poly5.type, 'cas_function');
  assert.ok(poly5.extrema.length > 0);

  const ext0 = poly5.extrema[0];
  const newExpr = computeFormulaFromDrag(poly5, { type: 'extremum', idx: 0 }, ext0.x, ext0.y + 2);
  assert.ok(newExpr);
  assert.ok(newExpr.includes('+ 2'), 'Must append + 2');
  console.log('✅ x^5 extremum drag result:', newExpr);
}

console.log('🎉 ALL CURVE MANIPULATOR TESTS PASSED 100%!');
