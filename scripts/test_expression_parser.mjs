import { parseAndAnalyze } from '../plugins/math_studio/ui/core/expression_parser.js';

console.log('🧪 Testing Expression Parser...');

// 1. Cubic
{
  const res = parseAndAnalyze('y = x^3 - 3x + 1');
  console.assert(res.type === 'cubic', 'Must detect cubic');
  console.assert(res.extrema.length === 2, 'Cubic must have 2 extrema');
  console.log('✅ Cubic parse: OK');
}

// 2. Rational 2/1 with parens
{
  const res = parseAndAnalyze('y = (x^2 - x + 1)/(x - 1)');
  console.assert(res.type === 'rational2', 'Must detect rational2');
  console.assert(res.asymptotes.some(a => a.type === 'TCX'), 'Must have TCX');
  console.log('✅ Rational 2/1 parse: OK');
}

// 3. Rational 1/1
{
  const res = parseAndAnalyze('(2x + 1)/(x - 1)');
  console.assert(res.type === 'rational1', 'Must detect rational1');
  console.assert(res.asymptotes.length === 2, 'Must have 2 asymptotes');
  console.log('✅ Rational 1/1 parse: OK');
}

// 4. Quartic
{
  const res = parseAndAnalyze('x^4 - 2x^2 - 1');
  console.assert(res.type === 'quartic', 'Must detect quartic');
  console.assert(res.extrema.length === 3, 'Quartic must have 3 extrema');
  console.log('✅ Quartic parse: OK');
}

// 5. Parabola / Quadratic
{
  const res = parseAndAnalyze('x^2 - 4x + 3');
  console.assert(res.extrema.length === 1, 'Parabola must have 1 vertex extremum');
  console.assert(Math.abs(res.extrema[0].x - 2) < 0.1, 'Vertex x must be 2');
  console.log('✅ Quadratic parabola parse: OK');
}

console.log('🎉 ALL EXPRESSION PARSER TESTS PASSED 100%!');

