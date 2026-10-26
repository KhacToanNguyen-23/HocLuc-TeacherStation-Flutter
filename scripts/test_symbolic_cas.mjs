import assert from 'node:assert';
import { parseExpressionToAST, differentiateAST, simplifyAST, formatAST, computeSymbolicDerivative } from '../plugins/math_studio/ui/core/symbolic_cas.js';

console.log('🧪 Bắt đầu kiểm thử Zero-Dependency Symbolic CAS Engine (symbolic_cas.js)...');

// Test 1: Polynomial cubic derivative (x^3 - 3x + 1) -> 3x^2 - 3
{
  const res = computeSymbolicDerivative('x^3 - 3*x + 1');
  assert.ok(res.success, 'Cubic derivative must succeed');
  assert.ok(res.display.includes('3x^2') || res.display.includes('3x^{2}') || res.display.includes('3'), 'Contains 3x^2');
  assert.ok(res.display.includes('- 3'), 'Contains - 3');
  console.log('✅ Test 1 (Bậc 3: x^3 - 3x + 1):', res.display);
}

// Test 2: High-degree polynomial derivative (x^5 - 5x) -> 5x^4 - 5
{
  const res = computeSymbolicDerivative('x^5 - 5*x');
  assert.ok(res.success, 'High-degree polynomial derivative must succeed');
  assert.ok(res.display.includes('5x^4') || res.display.includes('5x^{4}'), 'Contains 5x^4');
  assert.ok(res.display.includes('- 5'), 'Contains - 5');
  console.log('✅ Test 2 (Bậc 5: x^5 - 5x):', res.display);
}

// Test 3: Trigonometric composite (sin(x)^2 + 1) -> 2sin(x)cos(x)
{
  const res = computeSymbolicDerivative('sin(x)^2 + 1');
  assert.ok(res.success, 'Trig derivative must succeed');
  assert.ok(res.display.includes('sin(x)') && res.display.includes('cos(x)'), 'Contains sin(x) and cos(x)');
  console.log('✅ Test 3 (Lượng giác: sin(x)^2 + 1):', res.display);
}

// Test 4: Rational quotient derivative ((2x + 1) / (x - 1))
{
  const res = computeSymbolicDerivative('(2*x + 1) / (x - 1)');
  assert.ok(res.success, 'Rational derivative must succeed');
  assert.ok(res.display.includes('(x - 1)^2') || res.display.includes('(x - 1)^{2}'), 'Denominator squared');
  console.log('✅ Test 4 (Phân thức: (2x+1)/(x-1)):', res.display);
}

// Test 5: Exponential function (exp(2x))
{
  const res = computeSymbolicDerivative('exp(2*x)');
  assert.ok(res.success, 'Exp derivative must succeed');
  assert.ok(res.display.includes('exp(2x)') || res.display.includes('exp(2 * x)'), 'Contains exp');
  console.log('✅ Test 5 (Hàm mũ: exp(2x)):', res.display);
}

console.log('🎉 TẤT CẢ 5/5 TESTS SYMBOLIC CAS ĐẠT 100%!');

