/**
 * Symbolic & High-Precision Computer Algebra System (CAS) Engine
 * For Học Lực Math Studio - Pedagogical Mathematics Engine
 *
 * Provides analytical derivatives, high-precision root/extrema finding,
 * asymptotes, and numerical/analytical integrals for ANY mathematical function.
 */

import { computeSymbolicDerivative } from './symbolic_cas.js';

/**
 * Normalizes user-typed expression into standard JS math expression
 */
export function normalizeExpression(expr) {
  if (!expr) return '0';
  let s = expr.trim();

  // Strip leading "y =", "f(x) =", "f =", etc.
  s = s.replace(/^(?:y|f\(x\)|f)\s*=\s*/i, '');

  // Unicode superscripts
  s = s.replace(/⁰/g, '^0')
       .replace(/¹/g, '^1')
       .replace(/²/g, '^2')
       .replace(/³/g, '^3')
       .replace(/⁴/g, '^4')
       .replace(/⁵/g, '^5')
       .replace(/⁶/g, '^6')
       .replace(/⁷/g, '^7')
       .replace(/⁸/g, '^8')
       .replace(/⁹/g, '^9');

  // Implicit multiplication:
  // 3x -> 3*x
  s = s.replace(/(\d+)\s*([xX])/g, '$1*$2');
  // 3( -> 3*(
  s = s.replace(/(\d+)\s*\(/g, '$1*(');
  // )( -> )*(
  s = s.replace(/\)\s*\(/g, ')*(');
  // )x -> )*x
  s = s.replace(/\)\s*([xX])/g, ')*$1');
  // x( -> x*(
  s = s.replace(/([xX])\s*\(/g, '$1*(');
  // Number or x before math func: 3sin -> 3*sin, xsin -> x*sin
  s = s.replace(/(\d+|[xX])\s*(sin|cos|tan|cot|sqrt|abs|ln|log|exp)\b/gi, '$1*$2');

  // Math constants
  s = s.replace(/\bpi\b/gi, 'Math.PI');
  s = s.replace(/\be\b/g, 'Math.E');

  // Functions mapping
  s = s.replace(/\bsin\b/gi, 'Math.sin');
  s = s.replace(/\bcos\b/gi, 'Math.cos');
  s = s.replace(/\btan\b/gi, 'Math.tan');
  s = s.replace(/\bcot\b/gi, '(1/Math.tan');
  s = s.replace(/\bsqrt\b/gi, 'Math.sqrt');
  s = s.replace(/\babs\b/gi, 'Math.abs');
  s = s.replace(/\bln\b/gi, 'Math.log');
  s = s.replace(/\blog\b/gi, 'Math.log10');
  s = s.replace(/\bexp\b/gi, 'Math.exp');

  // Power operator ^ to **
  s = s.replace(/\^/g, '**');

  return s;
}

/**
 * Compiles a safe, high-performance evaluator: (x) => number
 */
export function compileFunction(rawExpr) {
  const norm = normalizeExpression(rawExpr);
  try {
    const fn = new Function('x', `"use strict"; return (${norm});`);
    return (x) => {
      try {
        const val = fn(x);
        return (typeof val === 'number' && isFinite(val)) ? val : NaN;
      } catch {
        return NaN;
      }
    };
  } catch (err) {
    throw new Error(`Cú pháp hàm số chưa hợp lệ: ${err.message}`);
  }
}

/**
 * High-Precision Numerical Derivative: f'(x)
 * Uses 5-point central stencil for O(h^4) accuracy.
 */
export function derivativeAt(f, x, h = 1e-5) {
  const f_p2 = f(x + 2 * h);
  const f_p1 = f(x + h);
  const f_m1 = f(x - h);
  const f_m2 = f(x - 2 * h);

  if (isNaN(f_p2) || isNaN(f_p1) || isNaN(f_m1) || isNaN(f_m2)) {
    // Fallback to 2-point central
    const y1 = f(x + h);
    const y2 = f(x - h);
    if (isNaN(y1) || isNaN(y2)) return NaN;
    return (y1 - y2) / (2 * h);
  }

  return (-f_p2 + 8 * f_p1 - 8 * f_m1 + f_m2) / (12 * h);
}

/**
 * Second Derivative: f''(x)
 */
export function secondDerivativeAt(f, x, h = 1e-4) {
  const yp = f(x + h);
  const y0 = f(x);
  const ym = f(x - h);
  if (isNaN(yp) || isNaN(y0) || isNaN(ym)) return NaN;
  return (yp - 2 * y0 + ym) / (h * h);
}

/**
 * Solves f(x) = target on [xMin, xMax] using hybrid Bisection + Newton-Raphson
 */
export function findRoots(f, xMin = -8, xMax = 8, step = 0.08, tol = 1e-7) {
  const roots = [];
  let prevX = xMin;
  let prevY = f(prevX);

  for (let x = xMin + step; x <= xMax; x += step) {
    const curY = f(x);

    if (isNaN(curY) || isNaN(prevY)) {
      prevX = x;
      prevY = curY;
      continue;
    }

    if (Math.abs(curY) <= 1e-5) {
      const isDupe = roots.some(r => Math.abs(r - x) < 0.05);
      if (!isDupe) roots.push(x);
    } else if (prevY * curY < 0) {
      // Root bracketed between prevX and x -> Bisection + Newton
      let lo = prevX, hi = x;
      let root = (lo + hi) / 2;

      for (let iter = 0; iter < 24; iter++) {
        const mid = (lo + hi) / 2;
        const fMid = f(mid);
        if (Math.abs(fMid) <= tol || (hi - lo) < tol) {
          root = mid;
          break;
        }

        const der = derivativeAt(f, mid);
        if (!isNaN(der) && Math.abs(der) > 1e-6) {
          const newtonX = mid - fMid / der;
          if (newtonX > lo && newtonX < hi) {
            root = newtonX;
            if (f(lo) * f(newtonX) <= 0) hi = newtonX;
            else lo = newtonX;
            continue;
          }
        }

        if (f(lo) * fMid <= 0) hi = mid;
        else lo = mid;
      }

      // Check if root is unique
      const isDupe = roots.some(r => Math.abs(r - root) < 0.05);
      if (!isDupe && isFinite(root)) {
        roots.push(root);
      }
    }

    prevX = x;
    prevY = curY;
  }

  return roots.sort((a, b) => a - b);
}

/**
 * Finds all critical points (Extrema: CĐ, CT) on [xMin, xMax]
 */
export function findExtrema(f, xMin = -7, xMax = 7) {
  const derFn = (x) => derivativeAt(f, x);
  const criticalXs = findRoots(derFn, xMin, xMax, 0.06);

  const extrema = [];
  for (const cx of criticalXs) {
    const yVal = f(cx);
    if (isNaN(yVal) || !isFinite(yVal)) continue;

    const d2 = secondDerivativeAt(f, cx);
    let type = 'CĐ';

    if (d2 < -1e-5) {
      type = 'CĐ';
    } else if (d2 > 1e-5) {
      type = 'CT';
    } else {
      // Check sign change of f' directly
      const dLeft = derFn(cx - 0.05);
      const dRight = derFn(cx + 0.05);
      if (dLeft > 0 && dRight < 0) type = 'CĐ';
      else if (dLeft < 0 && dRight > 0) type = 'CT';
      else continue; // Inflection point, not local extremum
    }

    extrema.push({
      type,
      x: cx,
      y: yVal,
      displayX: (Math.round(cx * 100) / 100).toFixed(2),
      displayY: (Math.round(yVal * 100) / 100).toFixed(2)
    });
  }

  return extrema;
}

/**
 * Adaptive Simpson's Rule for High-Precision Definite Integral
 */
export function calculateDefiniteIntegral(f, a, b, tol = 1e-6, maxDepth = 18) {
  const simpson = (fa, fb, fc, h) => (h / 6) * (fa + 4 * fc + fb);

  function recursiveSimpson(fn, x0, x1, f0, f1, fm, whole, depth) {
    const h = x1 - x0;
    const c = (x0 + x1) / 2;
    const d = (x0 + c) / 2;
    const e = (c + x1) / 2;
    const fd = fn(d);
    const fe = fn(e);

    if (isNaN(fd) || isNaN(fe)) return whole;

    const left = simpson(f0, fm, fd, h / 2);
    const right = simpson(fm, f1, fe, h / 2);
    const delta = left + right - whole;

    if (depth <= 0 || Math.abs(delta) <= 15 * tol) {
      return left + right + delta / 15;
    }

    return (
      recursiveSimpson(fn, x0, c, f0, fm, fd, left, depth - 1) +
      recursiveSimpson(fn, c, x1, fm, f1, fe, right, depth - 1)
    );
  }

  const fa = f(a);
  const fb = f(b);
  const fm = f((a + b) / 2);
  const initial = simpson(fa, fb, fm, b - a);
  const signedIntegral = recursiveSimpson(f, a, b, fa, fb, fm, initial, maxDepth);

  // Area under absolute curve: S = \int |f(x)|
  const absF = (x) => Math.abs(f(x) || 0);
  const absFa = absF(a);
  const absFb = absF(b);
  const absFm = absF((a + b) / 2);
  const initialAbs = simpson(absFa, absFb, absFm, b - a);
  const area = recursiveSimpson(absF, a, b, absFa, absFb, absFm, initialAbs, maxDepth);

  return {
    signedIntegral: Number(signedIntegral.toFixed(5)),
    area: Number(area.toFixed(5)),
    displayArea: (Math.round(area * 10000) / 10000).toFixed(4)
  };
}

/**
 * Complete CAS Analysis for any mathematical expression
 */
export function analyzeFunction(rawExpr, bounds = { xMin: -6, xMax: 6, yMin: -4.1, yMax: 4.1 }) {
  const cleanExpr = rawExpr.replace(/^(?:y|f\(x\))\s*=\s*/i, '').trim();
  const f = compileFunction(cleanExpr);

  const xMin = bounds.xMin ?? -6;
  const xMax = bounds.xMax ?? 6;

  // 1. Detect asymptotes / domain singularities
  const asymptotes = [];
  let singularX = null;
  let hasSingularity = false;

  // Check simple rational (px + q) denominator
  const denMatch = cleanExpr.match(/\/\s*\(\s*([+-]?\d*(?:\.\d+)?)\s*x\s*([+-]\s*\d+(?:\.\d+)?)\s*\)/i);
  if (denMatch) {
    const pStr = denMatch[1].replace(/\s+/g, '');
    const p = pStr === '' || pStr === '+' ? 1 : pStr === '-' ? -1 : parseFloat(pStr);
    const q = parseFloat(denMatch[2].replace(/\s+/g, ''));
    if (!isNaN(p) && p !== 0 && !isNaN(q)) {
      singularX = -q / p;
      hasSingularity = true;
      asymptotes.push({
        type: 'TCĐ',
        isVertical: true,
        val: singularX,
        eq: `x = ${singularX.toFixed(1)}`
      });

      // Check horizontal asymptote as x -> inf
      const yInf = f(1e6);
      if (!isNaN(yInf) && isFinite(yInf) && Math.abs(f(1e7) - yInf) < 0.05) {
        asymptotes.push({
          type: 'TCN',
          isHorizontal: true,
          val: yInf,
          eq: `y = ${yInf.toFixed(1)}`
        });
      }
    }
  }

  // 2. Extrema calculation via CAS
  const allExtrema = findExtrema(f, xMin - 0.2, xMax + 0.2);
  const extrema = allExtrema.filter(e => e.x >= xMin - 0.05 && e.x <= xMax + 0.05);

  // 3. Intercepts
  const y0 = f(0);
  const oyIntercept = (!isNaN(y0) && isFinite(y0)) ? { x: 0, y: y0, label: `(0; ${y0.toFixed(2)})` } : null;
  const oxRoots = findRoots(f, xMin, xMax);
  const oxIntercepts = oxRoots.map(rx => ({
    x: rx,
    y: 0,
    label: `(${rx.toFixed(2)}; 0)`
  }));

  // 4. Variation table data for BBT
  const points = [];
  for (const ext of extrema) {
    points.push({
      x: ext.x,
      displayX: ext.displayX,
      derVal: '0',
      yVal: ext.displayY,
      isExtremum: true,
      extremumType: ext.type
    });
  }

  if (hasSingularity && singularX !== null) {
    points.push({
      x: singularX,
      displayX: singularX.toFixed(1),
      derVal: '||',
      yVal: '||',
      isSingularity: true
    });
  }

  points.sort((a, b) => a.x - b.x);

  const intervals = [];
  if (points.length === 0) {
    const d0 = derivativeAt(f, 0);
    intervals.push({ sign: d0 >= 0 ? '+' : '-' });
  } else {
    for (let i = 0; i <= points.length; i++) {
      const midX = (i === 0) ? points[0].x - 1 :
                    (i === points.length) ? points[points.length - 1].x + 1 :
                    (points[i - 1].x + points[i].x) / 2;
      const dMid = derivativeAt(f, midX);
      intervals.push({ sign: dMid >= 0 ? '+' : '-' });
    }
  }

  const derSymbolic = computeSymbolicDerivative(cleanExpr);

  return {
    type: 'cas_function',
    rawInput: cleanExpr,
    formulaClean: cleanExpr,
    formulaLatex: `y = ${cleanExpr}`,
    derLatex: derSymbolic.latex,
    derDisplay: derSymbolic.display,
    derRaw: derSymbolic.raw,
    domain: hasSingularity ? `D = ℝ \\ {${singularX.toFixed(1)}}` : 'D = ℝ',
    bounds: {
      xMin,
      xMax,
      yMin: bounds.yMin ?? -4.1,
      yMax: bounds.yMax ?? 4.1
    },
    extrema,
    asymptotes,
    intercepts: {
      oy: oyIntercept,
      ox: oxIntercepts
    },
    tableData: {
      points,
      intervals,
      hasSingularity,
      singularX
    },
    eval: f,
    derEval: (x) => derivativeAt(f, x),
    der2Eval: (x) => secondDerivativeAt(f, x)
  };
}
