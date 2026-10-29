import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';

// Import modules to test
import { parseFunction } from '../../src/engine/parse.js';
import { computeDerivative } from '../../src/engine/derivative.js';
import { analyzeFunction, findIntersectionsWithHorizontalLine, getTangentAt } from '../../src/engine/analyze.js';
import { computeAntiderivative, computeDefiniteIntegral } from '../../src/engine/integrate.js';
import { computeRiemannSum } from '../../src/engine/riemann.js';
import { computeRevolutionVolume } from '../../src/engine/revolution.js';
import { buildBBT } from '../../src/engine/bbt.js';

describe('Math Engine - 8 Benchmark Functions', () => {

  test('Benchmark 1: f(x) = 2x^2 - 3x + 1 (Critical fix for old bug)', () => {
    const parsed = parseFunction('2x^2 - 3x + 1');
    assert.equal(parsed.success, true);

    const deriv = computeDerivative(parsed.node);
    // Derivative must be 4x - 3 (or simplified form), NOT 3x^2 - 3
    assert.equal(deriv.evaluate(0), -3);
    assert.equal(deriv.evaluate(1), 1);
    assert.match(deriv.display, /4.*x.*3/);

    const analysis = analyzeFunction(parsed, { domainMin: -5, domainMax: 5 });
    // Root of y' = 0 is at x = 0.75
    assert.equal(analysis.extrema.length, 1);
    const min = analysis.extrema[0];
    assert.equal(min.type, 'min');
    assert.ok(Math.abs(min.x - 0.75) < 0.01);
    assert.ok(Math.abs(min.y - (-0.125)) < 0.01);

    // Roots of f(x) = 0: x = 0.5 and x = 1.0
    const roots = analysis.roots;
    assert.equal(roots.length, 2);
    assert.ok(Math.abs(roots[0] - 0.5) < 0.02 || Math.abs(roots[1] - 0.5) < 0.02);
    assert.ok(Math.abs(roots[0] - 1.0) < 0.02 || Math.abs(roots[1] - 1.0) < 0.02);
  });

  test('Benchmark 2: f(x) = x^3 - 3x', () => {
    const parsed = parseFunction('x^3 - 3x');
    assert.equal(parsed.success, true);

    const deriv = computeDerivative(parsed.node);
    assert.equal(deriv.evaluate(0), -3);
    assert.equal(deriv.evaluate(2), 9);

    const analysis = analyzeFunction(parsed, { domainMin: -4, domainMax: 4 });
    // Local max at (-1, 2), Local min at (1, -2)
    assert.equal(analysis.extrema.length, 2);
    const max = analysis.extrema.find((e) => e.type === 'max');
    const min = analysis.extrema.find((e) => e.type === 'min');
    assert.ok(max && Math.abs(max.x - (-1)) < 0.02 && Math.abs(max.y - 2) < 0.02);
    assert.ok(min && Math.abs(min.x - 1) < 0.02 && Math.abs(min.y - (-2)) < 0.02);

    // Inflection point at (0, 0)
    assert.ok(analysis.inflections.some((p) => Math.abs(p.x) < 0.02 && Math.abs(p.y) < 0.02));

    // Tangent at x0 = 2: slope = 9, y = 9x - 16
    const tangent = getTangentAt(parsed, 2);
    assert.ok(Math.abs(tangent.slope - 9) < 0.01);
    assert.ok(Math.abs(tangent.y0 - 2) < 0.01);
    assert.ok(Math.abs(tangent.intercept - (-16)) < 0.02);

    // Roots of y = m:
    // m = 0 -> 3 roots
    const roots0 = findIntersectionsWithHorizontalLine(parsed, 0, -4, 4);
    assert.equal(roots0.length, 3);
    // m = 2 -> 2 roots
    const roots2 = findIntersectionsWithHorizontalLine(parsed, 2, -4, 4);
    assert.equal(roots2.length, 2);
    // m = 3 -> 1 root
    const roots3 = findIntersectionsWithHorizontalLine(parsed, 3, -4, 4);
    assert.equal(roots3.length, 1);
    // m = -0.5 -> 3 roots
    const rootsNegHalf = findIntersectionsWithHorizontalLine(parsed, -0.5, -4, 4);
    assert.equal(rootsNegHalf.length, 3);

    // Indefinite integral: x^4/4 - 1.5x^2
    const anti = computeAntiderivative(parsed.raw);
    assert.equal(anti.success, true);
    assert.ok(anti.display.includes('x') || anti.display.includes('C'));
  });

  test('Benchmark 3: f(x) = (2x+1)/(x-1)', () => {
    const parsed = parseFunction('(2x+1)/(x-1)');
    assert.equal(parsed.success, true);

    const analysis = analyzeFunction(parsed, { domainMin: -8, domainMax: 8 });
    // Vertical asymptote at x = 1
    assert.ok(analysis.asymptotes.vertical.some((x) => Math.abs(x - 1) < 0.05));
    // Horizontal asymptote at y = 2
    assert.ok(analysis.asymptotes.horizontal.some((y) => Math.abs(y - 2) < 0.05));
    // No extrema
    assert.equal(analysis.extrema.length, 0);
  });

  test('Benchmark 4: f(x) = (x^2+x+1)/(x-1)', () => {
    const parsed = parseFunction('(x^2+x+1)/(x-1)');
    assert.equal(parsed.success, true);

    const analysis = analyzeFunction(parsed, { domainMin: -8, domainMax: 8 });
    // Vertical asymptote at x = 1
    assert.ok(analysis.asymptotes.vertical.some((x) => Math.abs(x - 1) < 0.05));
    // Slant asymptote y = x + 2 (slope a = 1, intercept b = 2)
    assert.ok(analysis.asymptotes.slant.some((s) => Math.abs(s.a - 1) < 0.05 && Math.abs(s.b - 2) < 0.1));
    // Extrema at 1 - sqrt(3) ~ -0.732 and 1 + sqrt(3) ~ 2.732
    assert.equal(analysis.extrema.length, 2);
    const max = analysis.extrema.find((e) => e.type === 'max');
    const min = analysis.extrema.find((e) => e.type === 'min');
    assert.ok(max && Math.abs(max.x - (1 - Math.sqrt(3))) < 0.05);
    assert.ok(min && Math.abs(min.x - (1 + Math.sqrt(3))) < 0.05);
  });

  test('Benchmark 5: f(x) = sin(x)', () => {
    const parsed = parseFunction('sin(x)');
    assert.equal(parsed.success, true);

    const deriv = computeDerivative(parsed.node);
    assert.ok(Math.abs(deriv.evaluate(0) - 1) < 0.01); // cos(0) = 1
    assert.ok(Math.abs(deriv.evaluate(Math.PI / 2)) < 0.01); // cos(pi/2) = 0

    const analysis = analyzeFunction(parsed, { domainMin: 0, domainMax: 2 * Math.PI });
    // Local max around pi/2 (~1.57), local min around 3pi/2 (~4.71)
    const max = analysis.extrema.find((e) => e.type === 'max');
    const min = analysis.extrema.find((e) => e.type === 'min');
    assert.ok(max && Math.abs(max.x - Math.PI / 2) < 0.05);
    assert.ok(min && Math.abs(min.x - 3 * Math.PI / 2) < 0.05);
  });

  test('Benchmark 6: f(x) = e^(-x^2)', () => {
    const parsed = parseFunction('e^(-x^2)');
    assert.equal(parsed.success, true);

    const analysis = analyzeFunction(parsed, { domainMin: -4, domainMax: 4 });
    // Max at (0, 1)
    const max = analysis.extrema.find((e) => e.type === 'max');
    assert.ok(max && Math.abs(max.x) < 0.02 && Math.abs(max.y - 1) < 0.02);
    // Horizontal asymptote y = 0
    assert.ok(analysis.asymptotes.horizontal.some((y) => Math.abs(y) < 0.02));
  });

  test('Benchmark 7: f(x) = sqrt(4-x^2)', () => {
    const parsed = parseFunction('sqrt(4-x^2)');
    assert.equal(parsed.success, true);

    // Defined on [-2, 2]
    assert.ok(!Number.isNaN(parsed.evaluate(0)));
    assert.ok(Number.isNaN(parsed.evaluate(3)) || parsed.evaluate(3) === null);

    const analysis = analyzeFunction(parsed, { domainMin: -3, domainMax: 3 });
    // Max at (0, 2)
    const max = analysis.extrema.find((e) => e.type === 'max');
    assert.ok(max && Math.abs(max.x) < 0.02 && Math.abs(max.y - 2) < 0.02);
  });

  test('Benchmark 8: f(x) = ln(x)', () => {
    const parsed = parseFunction('ln(x)');
    assert.equal(parsed.success, true);

    // Undefined at x <= 0
    assert.ok(Number.isNaN(parsed.evaluate(-1)) || parsed.evaluate(-1) === null);
    assert.ok(Math.abs(parsed.evaluate(1)) < 0.01);

    const analysis = analyzeFunction(parsed, { domainMin: -2, domainMax: 5 });
    // Vertical asymptote at x = 0
    assert.ok(analysis.asymptotes.vertical.some((x) => Math.abs(x) < 0.05));

    // Antiderivative of ln(x) is x*ln(x) - x
    const anti = computeAntiderivative('log(x)');
    assert.equal(anti.success, true);
  });

  test('Riemann Sums for sqrt(x) on [0, 4]', () => {
    const parsed = parseFunction('sqrt(x)');
    const exact = 16 / 3; // 5.33333

    // Midpoint rule n=50: error <= 1%
    const mid50 = computeRiemannSum(parsed, 0, 4, 50, 'midpoint');
    const midError = Math.abs(mid50.sum - exact) / exact;
    assert.ok(midError <= 0.01, `Midpoint error ${midError} must be <= 1%`);

    // Left/Right rule n=50: error <= 3%
    const left50 = computeRiemannSum(parsed, 0, 4, 50, 'left');
    const leftError = Math.abs(left50.sum - exact) / exact;
    assert.ok(leftError <= 0.03, `Left error ${leftError} must be <= 3%`);

    assert.equal(mid50.rectangles.length, 50);
  });

  test('Revolution Volume for sqrt(x) on [0, 4] around Ox', () => {
    const parsed = parseFunction('sqrt(x)');
    // V = pi * integral_0^4 (sqrt(x))^2 dx = pi * [x^2/2]_0^4 = 8*pi ~ 25.13274
    const res = computeRevolutionVolume(parsed, 0, 4);
    assert.ok(Math.abs(res.volume - 8 * Math.PI) < 0.01, `V=${res.volume} expected ${8 * Math.PI}`);
  });

  test('Property Test: No Hardcoded Table Lookup in Engine Sources', () => {
    const engineDir = path.resolve('plugins/math_studio/src/engine');
    const files = fs.readdirSync(engineDir).filter((f) => f.endsWith('.js'));
    for (const f of files) {
      const content = fs.readFileSync(path.join(engineDir, f), 'utf8');
      // Must not hardcode specific benchmark function formulas as cases/keys
      assert.ok(!content.includes("'2x^2-3x+1'"), `File ${f} contains hardcoded function string`);
      assert.ok(!content.includes("'x^3-3x'"), `File ${f} contains hardcoded function string`);
      assert.ok(!content.includes("'4x-3'"), `File ${f} contains hardcoded derivative string`);
    }

    // Dynamic test: test 5 random quadratic polynomials
    for (let i = 0; i < 5; i++) {
      const a = (Math.floor(Math.random() * 5) + 1) * (Math.random() > 0.5 ? 1 : -1);
      const b = (Math.floor(Math.random() * 10) - 5);
      const expr = `${a}x^2 + ${b}x`;
      const p = parseFunction(expr);
      assert.equal(p.success, true);
      const d = computeDerivative(p.node);
      const testX = 2.5;
      const numDeriv = (p.evaluate(testX + 0.0001) - p.evaluate(testX - 0.0001)) / 0.0002;
      assert.ok(Math.abs(d.evaluate(testX) - numDeriv) < 0.01);
    }
  });

  test('Error Handling: Syntax and Invalid Expressions', () => {
    const bad1 = parseFunction('x^^2');
    assert.equal(bad1.success, false);
    assert.ok(bad1.error.length > 0);

    const bad2 = parseFunction('((x+1)');
    assert.equal(bad2.success, false);
    assert.ok(bad2.error.length > 0);
  });

  test('Bảng Biến Thiên (BBT) Model Generation', () => {
    const parsed = parseFunction('x^3 - 3x');
    const bbt = buildBBT(parsed, -5, 5);
    assert.equal(bbt.success, true);
    // Columns should include -infinity, -1, 1, +infinity
    assert.ok(bbt.columns.length >= 4);
    assert.equal(bbt.columns[0].yVal, '-∞', 'Left limit of x^3-3x must be -∞');
    assert.equal(bbt.columns[bbt.columns.length - 1].yVal, '+∞', 'Right limit of x^3-3x must be +∞');
    const colNeg1 = bbt.columns.find((c) => Math.abs(c.x - (-1)) < 0.01);
    const col1 = bbt.columns.find((c) => Math.abs(c.x - 1) < 0.01);
    assert.ok(colNeg1 && colNeg1.derivSign === 0 && colNeg1.yVal === 2);
    assert.ok(col1 && col1.derivSign === 0 && col1.yVal === -2);
  });

});

