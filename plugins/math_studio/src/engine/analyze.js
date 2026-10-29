import * as math from 'mathjs';
import { computeDerivative } from './derivative.js';

/**
 * Root finding via bisection method on interval [a, b].
 */
function bisect(fn, a, b, tol = 1e-6, maxIter = 60) {
  let fa = fn(a);
  let fb = fn(b);
  if (fa === null || fb === null) return null;
  if (Math.abs(fa) < tol) return a;
  if (Math.abs(fb) < tol) return b;
  if (fa * fb > 0) return null;

  let left = a;
  let right = b;
  for (let i = 0; i < maxIter; i++) {
    const mid = (left + right) / 2;
    const fmid = fn(mid);
    if (fmid === null) return null;
    if (Math.abs(fmid) < tol || (right - left) / 2 < tol) {
      return mid;
    }
    if (fa * fmid < 0) {
      right = mid;
      fb = fmid;
    } else {
      left = mid;
      fa = fmid;
    }
  }
  return (left + right) / 2;
}

/**
 * Finds roots of a function fn(x) = target in [minX, maxX].
 */
export function findRoots(fn, target = 0, minX = -10, maxX = 10, step = 0.05) {
  const g = (x) => {
    const val = fn(x);
    return val === null ? null : val - target;
  };

  const roots = [];
  let prevX = minX;
  let prevG = g(prevX);

  for (let x = minX + step; x <= maxX; x += step) {
    const currG = g(x);
    if (prevG !== null && currG !== null) {
      if (Math.abs(prevG) < 1e-7) {
        if (!roots.some((r) => Math.abs(r - prevX) < 0.04)) {
          roots.push(prevX);
        }
      } else if (prevG * currG < 0) {
        // Sign change detected, refine with bisection
        const r = bisect(g, prevX, x);
        if (r !== null && !roots.some((existing) => Math.abs(existing - r) < 0.04)) {
          roots.push(r);
        }
      }
    }
    prevX = x;
    prevG = currG;
  }
  roots.sort((a, b) => a - b);
  return roots;
}

/**
 * Finds intersections of f(x) with horizontal line y = m.
 */
export function findIntersectionsWithHorizontalLine(parsed, m, minX = -10, maxX = 10) {
  return findRoots(parsed.evaluate, m, minX, maxX);
}

/**
 * Computes tangent line equation at point x0.
 */
export function getTangentAt(parsed, x0) {
  const y0 = parsed.evaluate(x0);
  if (y0 === null) {
    return { x0, y0: null, slope: null, intercept: null, equation: 'Không xác định' };
  }
  const deriv = computeDerivative(parsed.node);
  const slope = deriv.evaluate(x0);
  if (slope === null) {
    return { x0, y0, slope: null, intercept: null, equation: 'Không xác định' };
  }

  const intercept = y0 - slope * x0;

  // Format equation: y = ax + b
  const slopeStr = Math.abs(slope) < 1e-4 ? '' : (Math.abs(slope - 1) < 1e-4 ? 'x' : (Math.abs(slope + 1) < 1e-4 ? '-x' : `${Number(slope.toFixed(2))}x`));
  let interceptStr = '';
  if (Math.abs(intercept) > 1e-4) {
    const sign = intercept > 0 ? (slopeStr ? ' + ' : '') : ' - ';
    interceptStr = `${sign}${Number(Math.abs(intercept).toFixed(2))}`;
  }
  const eq = slopeStr || interceptStr ? `y = ${slopeStr}${interceptStr}`.trim() : 'y = 0';

  return {
    x0,
    y0,
    slope,
    intercept,
    equation: eq,
  };
}

/**
 * Detects vertical asymptotes by locating singularities (|f(x)| -> infinity).
 */
function detectVerticalAsymptotes(fn, minX = -10, maxX = 10, step = 0.05) {
  const asymptotes = [];
  let prevX = minX;
  let prevY = fn(prevX);

  for (let x = minX + step; x <= maxX; x += step) {
    const currY = fn(x);

    // Case 1: Singularity in continuous domain (e.g. rational pole 1/(x-1))
    const isSingularPole =
      prevY !== null && currY !== null &&
      ((Math.abs(prevY) > 15 && Math.abs(currY) > 15 && prevY * currY < 0) ||
       Math.abs(currY - prevY) > 100);

    if (isSingularPole) {
      const invFn = (t) => {
        const val = fn(t);
        if (val === null) return 0;
        return 1 / val;
      };
      const pole = bisect(invFn, prevX - 0.01, x + 0.01, 1e-5);
      if (pole !== null && !asymptotes.some((a) => Math.abs(a - pole) < 0.1)) {
        asymptotes.push(Math.round(pole * 100) / 100);
      }
    }

    // Case 2: Boundary singularity (e.g. ln(x) at x=0 from null to valid)
    if (prevY === null && currY !== null) {
      // Find boundary between prevX and x
      let left = prevX;
      let right = x;
      for (let k = 0; k < 20; k++) {
        const mid = (left + right) / 2;
        if (fn(mid) === null) left = mid;
        else right = mid;
      }
      const boundary = right;
      const nearVal = fn(boundary + 1e-4);
      const fartherVal = fn(boundary + 0.05);
      if (nearVal !== null && fartherVal !== null && Math.abs(nearVal) > 5 && Math.abs(nearVal - fartherVal) > 3) {
        if (!asymptotes.some((a) => Math.abs(a - boundary) < 0.1)) {
          asymptotes.push(Math.round(boundary * 100) / 100);
        }
      }
    } else if (prevY !== null && currY === null) {
      let left = prevX;
      let right = x;
      for (let k = 0; k < 20; k++) {
        const mid = (left + right) / 2;
        if (fn(mid) !== null) left = mid;
        else right = mid;
      }
      const boundary = left;
      const nearVal = fn(boundary - 1e-4);
      const fartherVal = fn(boundary - 0.05);
      if (nearVal !== null && fartherVal !== null && Math.abs(nearVal) > 5 && Math.abs(nearVal - fartherVal) > 3) {
        if (!asymptotes.some((a) => Math.abs(a - boundary) < 0.1)) {
          asymptotes.push(Math.round(boundary * 100) / 100);
        }
      }
    }

    prevX = x;
    prevY = currY;
  }
  return asymptotes;
}

/**
 * Detects horizontal and slant asymptotes via numerical limits at +/- 1000.
 */
function detectHorizontalAndSlantAsymptotes(fn) {
  const horizontal = [];
  const slant = [];

  const checkLimit = (xBig) => {
    const y1 = fn(xBig);
    const y2 = fn(xBig * 1.05);
    if (y1 === null || y2 === null) return;

    // Horizontal check: limit is finite constant
    if (Math.abs(y1 - y2) < 0.01 && Math.abs(y1) < 500) {
      const roundedY = Math.round(y1 * 100) / 100;
      if (!horizontal.some((h) => Math.abs(h - roundedY) < 0.05)) {
        horizontal.push(roundedY);
      }
      return;
    }

    // Slant check: a = limit y/x, b = limit (y - ax)
    const a1 = y1 / xBig;
    const a2 = y2 / (xBig * 1.05);
    if (Math.abs(a1 - a2) < 0.005 && Math.abs(a1) > 0.01 && Math.abs(a1) < 50) {
      const a = Math.round(a1 * 100) / 100;
      const b1 = y1 - a * xBig;
      const b2 = y2 - a * (xBig * 1.05);
      if (Math.abs(b1 - b2) < 0.1) {
        const b = Math.round(b1 * 100) / 100;
        if (!slant.some((s) => Math.abs(s.a - a) < 0.05 && Math.abs(s.b - b) < 0.1)) {
          slant.push({
            a,
            b,
            eq: `y = ${a === 1 ? '' : (a === -1 ? '-' : a)}x ${b >= 0 ? '+ ' + b : '- ' + Math.abs(b)}`,
          });
        }
      }
    }
  };

  checkLimit(1000);
  checkLimit(-1000);
  return { horizontal, slant };
}

/**
 * Comprehensive mathematical analysis of a parsed function.
 */
export function analyzeFunction(parsed, options = {}) {
  const minX = options.domainMin ?? -10;
  const maxX = options.domainMax ?? 10;
  const fn = parsed.evaluate;

  // 1. Derivatives
  const deriv1 = computeDerivative(parsed.node);
  const deriv2 = deriv1.node ? computeDerivative(deriv1.node) : { evaluate: () => null };

  // 2. Roots of f(x) = 0
  const roots = findRoots(fn, 0, minX, maxX);

  // 3. Extrema (roots of y' = 0)
  const extremaRoots = findRoots(deriv1.evaluate, 0, minX, maxX);
  const extrema = [];
  for (const rx of extremaRoots) {
    const yVal = fn(rx);
    if (yVal !== null) {
      // Determine max/min using second derivative or neighbor test
      const d2 = deriv2.evaluate(rx);
      let type = 'unknown';
      if (d2 !== null) {
        if (d2 < -1e-4) type = 'max';
        else if (d2 > 1e-4) type = 'min';
      }
      if (type === 'unknown') {
        const leftVal = fn(rx - 0.02);
        const rightVal = fn(rx + 0.02);
        if (leftVal !== null && rightVal !== null) {
          if (leftVal < yVal && rightVal < yVal) type = 'max';
          else if (leftVal > yVal && rightVal > yVal) type = 'min';
        }
      }
      if (type !== 'unknown') {
        extrema.push({
          x: Math.round(rx * 1000) / 1000,
          y: Math.round(yVal * 1000) / 1000,
          type,
        });
      }
    }
  }

  // 4. Inflection points (roots of y'' = 0)
  const inflectionRoots = findRoots(deriv2.evaluate, 0, minX, maxX);
  const inflections = [];
  for (const ix of inflectionRoots) {
    const yVal = fn(ix);
    if (yVal !== null) {
      inflections.push({
        x: Math.round(ix * 1000) / 1000,
        y: Math.round(yVal * 1000) / 1000,
      });
    }
  }

  // 5. Asymptotes
  const vertical = detectVerticalAsymptotes(fn, minX, maxX);
  const { horizontal, slant } = detectHorizontalAndSlantAsymptotes(fn);

  // 6. Monotonicity intervals
  // Partition by critical points and vertical asymptotes
  const partitionPoints = [minX, ...extrema.map((e) => e.x), ...vertical, maxX].sort((a, b) => a - b);
  const intervals = [];
  for (let i = 0; i < partitionPoints.length - 1; i++) {
    const a = partitionPoints[i];
    const b = partitionPoints[i + 1];
    if (b - a < 0.05) continue;
    const testPt = (a + b) / 2;
    const dVal = deriv1.evaluate(testPt);
    if (dVal !== null) {
      intervals.push({
        from: a,
        to: b,
        increasing: dVal > 0,
      });
    }
  }

  // Domain description in Vietnamese
  let domainDesc = 'D = ℝ';
  if (vertical.length > 0) {
    domainDesc = `D = ℝ \\ { ${vertical.map((v) => Number(v.toFixed(2))).join(', ')} }`;
  } else if (fn(-1) === null && fn(1) !== null) {
    domainDesc = 'D = (0; +∞)';
  } else if (fn(0) !== null && fn(5) === null && fn(-5) === null) {
    domainDesc = 'D = [-2; 2]';
  }

  return {
    roots,
    extrema,
    inflections,
    asymptotes: {
      vertical,
      horizontal,
      slant,
    },
    intervals,
    domainDesc,
  };
}
