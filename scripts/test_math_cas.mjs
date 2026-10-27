import assert from 'assert';
import {
  compileFunction,
  derivativeAt,
  findRoots,
  findExtrema,
  calculateDefiniteIntegral,
  analyzeFunction
} from '../plugins/math_studio/ui/core/math_cas.js';

console.log('🧪 Bắt đầu kiểm thử Symbolic Math CAS Engine (math_cas.js)...');

// 1. Cubic Polynomial: y = x^3 - 3x^2 + 2
{
  const res = analyzeFunction('x^3 - 3x^2 + 2');
  assert.strictEqual(res.extrema.length, 2, 'Bậc 3 phải có 2 cực trị');
  const cd = res.extrema.find(e => e.type === 'CĐ');
  const ct = res.extrema.find(e => e.type === 'CT');
  assert.ok(cd && Math.abs(cd.x - 0) < 0.05 && Math.abs(cd.y - 2) < 0.05, `CĐ tại (0, 2), got (${cd?.x}, ${cd?.y})`);
  assert.ok(ct && Math.abs(ct.x - 2) < 0.05 && Math.abs(ct.y - (-2)) < 0.05, `CT tại (2, -2), got (${ct?.x}, ${ct?.y})`);
  console.log('✅ Test 1: Bậc 3 (x^3 - 3x^2 + 2) tìm cực trị chính xác');
}

// 2. High-Degree Polynomial: y = x^5 - 5x
{
  const res = analyzeFunction('x^5 - 5x');
  // f'(x) = 5x^4 - 5 = 0 => x = +-1
  // x = -1: f(-1) = 4 (CĐ), x = 1: f(1) = -4 (CT)
  assert.strictEqual(res.extrema.length, 2, 'x^5 - 5x phải có 2 cực trị');
  const cd = res.extrema.find(e => e.type === 'CĐ');
  const ct = res.extrema.find(e => e.type === 'CT');
  assert.ok(cd && Math.abs(cd.x - (-1)) < 0.05 && Math.abs(cd.y - 4) < 0.05, `CĐ tại (-1, 4)`);
  assert.ok(ct && Math.abs(ct.x - 1) < 0.05 && Math.abs(ct.y - (-4)) < 0.05, `CT tại (1, -4)`);
  console.log('✅ Test 2: Bậc cao (x^5 - 5x) tìm cực trị chính xác');
}

// 3. Trigonometric Function: y = sin(x)^2 + 1
{
  const res = analyzeFunction('sin(x)^2 + 1');
  // Peaks at x = pi/2 + k*pi (y = 2), Troughs at x = k*pi (y = 1)
  assert.ok(res.extrema.length >= 4, 'Hàm lượng giác tuần hoàn có nhiều cực trị trên [-7, 7]');
  const cd = res.extrema.find(e => e.type === 'CĐ');
  const ct = res.extrema.find(e => e.type === 'CT');
  assert.ok(cd && Math.abs(cd.y - 2) < 0.05, `Giá trị CĐ phải bằng 2, got ${cd?.y}`);
  assert.ok(ct && Math.abs(ct.y - 1) < 0.05, `Giá trị CT phải bằng 1, got ${ct?.y}`);
  console.log('✅ Test 3: Lượng giác (sin(x)^2 + 1) cực đại = 2, cực tiểu = 1');
}

// 4. Rational Function with Vertical Asymptote: y = (2x + 1)/(x - 1)
{
  const res = analyzeFunction('(2x + 1)/(x - 1)');
  assert.strictEqual(res.asymptotes.length >= 1, true, 'Phải phát hiện tiệm cận đứng');
  const tcd = res.asymptotes.find(a => a.type === 'TCĐ');
  assert.ok(tcd && Math.abs(tcd.val - 1) < 0.05, 'TCĐ tại x = 1');
  console.log('✅ Test 4: Hữu tỉ ((2x+1)/(x-1)) phát hiện tiệm cận đứng x = 1');
}

// 5. High-Precision Definite Integral
{
  const f = compileFunction('x^2 - 2');
  // \int_{-1}^2 (x^2 - 2) dx = [x^3/3 - 2x]_{-1}^2 = (8/3 - 4) - (-1/3 + 2) = -4/3 - 5/3 = -3.0
  const integ = calculateDefiniteIntegral(f, -1, 2);
  assert.ok(Math.abs(integ.signedIntegral - (-3.0)) < 0.01, `Tích phân đại số phải bằng -3, got ${integ.signedIntegral}`);
  assert.ok(integ.area > 0, `Diện tích hình phẳng S phải dương, got ${integ.area}`);
  console.log('✅ Test 5: Tích phân định tích Adaptive Simpson chính xác: S =', integ.area);
}

console.log('🎉 TẤT CẢ 5/5 TESTS SYMBOLIC MATH CAS ENGINE ĐẠT 100%!');

