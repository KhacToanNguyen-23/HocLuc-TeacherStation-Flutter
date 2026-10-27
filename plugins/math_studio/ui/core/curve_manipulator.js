/**
 * Inverse Curve Manipulator (Direct Manipulation Engine)
 * Translates direct handle drag events on SVG curves back into mathematical formulas in real-time.
 */

/**
 * Magnetic snap helper: Snaps continuous mouse coordinates to clean integers (e.g. -2, 1, 3)
 * or neat halves (e.g. 0.5, 1.5) so teachers can easily land on exact textbook points.
 */
export function magneticSnap(val, threshold = 0.22) {
  const roundInt = Math.round(val);
  if (Math.abs(val - roundInt) <= threshold) {
    return roundInt;
  }
  const roundHalf = Math.round(val * 2) / 2;
  if (Math.abs(val - roundHalf) <= threshold * 0.75) {
    return roundHalf;
  }
  return Math.round(val * 10) / 10;
}

/**
 * Format a float number into clean decimal representation.
 * Keeps up to 2 decimal places, removes trailing zeroes.
 */
function cleanNum(num) {
  if (Math.abs(num) < 1e-6) return '0';
  const rounded = Math.round(num * 100) / 100;
  return Number(rounded.toFixed(2)).toString();
}

/**
 * Format linear polynomial: y = ax + b
 */
function formatPoly1(a, b) {
  let str = '';
  const aStr = cleanNum(a);
  const bStr = cleanNum(b);

  if (aStr === '1') str += 'x';
  else if (aStr === '-1') str += '-x';
  else if (aStr !== '0') str += `${aStr}x`;

  const bVal = parseFloat(bStr);
  if (bVal > 0) {
    str += (str ? ' + ' : '') + bStr;
  } else if (bVal < 0) {
    str += (str ? ' - ' : '-') + cleanNum(Math.abs(bVal));
  }

  return str || '0';
}

/**
 * Format quadratic polynomial: y = ax^2 + bx + c
 */
function formatPoly2(a, b, c) {
  let str = '';
  const aStr = cleanNum(a);
  const bStr = cleanNum(b);
  const cStr = cleanNum(c);

  if (aStr === '1') str += 'x^2';
  else if (aStr === '-1') str += '-x^2';
  else if (aStr !== '0') str += `${aStr}x^2`;

  const bVal = parseFloat(bStr);
  if (bVal > 0) {
    str += (str ? ' + ' : '') + (bStr === '1' ? 'x' : `${bStr}x`);
  } else if (bVal < 0) {
    str += (str ? ' - ' : '-') + (bStr === '-1' ? 'x' : `${cleanNum(Math.abs(bVal))}x`);
  }

  const cVal = parseFloat(cStr);
  if (cVal > 0) {
    str += (str ? ' + ' : '') + cStr;
  } else if (cVal < 0) {
    str += (str ? ' - ' : '-') + cleanNum(Math.abs(cVal));
  }

  return str || '0';
}

/**
 * Format cubic polynomial: y = ax^3 + bx^2 + cx + d
 */
function formatPoly3(a, b, c, d) {
  let str = '';
  const aStr = cleanNum(a);
  const bStr = cleanNum(b);
  const cStr = cleanNum(c);
  const dStr = cleanNum(d);

  if (aStr === '1') str += 'x^3';
  else if (aStr === '-1') str += '-x^3';
  else if (aStr !== '0') str += `${aStr}x^3`;

  const bVal = parseFloat(bStr);
  if (bVal > 0) {
    str += (str ? ' + ' : '') + (bStr === '1' ? 'x^2' : `${bStr}x^2`);
  } else if (bVal < 0) {
    str += (str ? ' - ' : '-') + (bStr === '-1' ? 'x^2' : `${cleanNum(Math.abs(bVal))}x^2`);
  }

  const cVal = parseFloat(cStr);
  if (cVal > 0) {
    str += (str ? ' + ' : '') + (cVal === '1' ? 'x' : `${cStr}x`);
  } else if (cVal < 0) {
    str += (str ? ' - ' : '-') + (cVal === '-1' ? 'x' : `${cleanNum(Math.abs(cVal))}x`);
  }

  const dVal = parseFloat(dStr);
  if (dVal > 0) {
    str += (str ? ' + ' : '') + dStr;
  } else if (dVal < 0) {
    str += (str ? ' - ' : '-') + cleanNum(Math.abs(dVal));
  }

  return str || '0';
}

/**
 * Format rational 1/1: y = (ax + b)/(cx + d)
 */
function formatRational11(a, b, c, d) {
  const numStr = formatPoly1(a, b);
  const denStr = formatPoly1(c, d);
  return `(${numStr})/(${denStr})`;
}

/**
 * Format quartic polynomial: y = ax^4 + bx^2 + c
 */
function formatQuartic(a, b, c) {
  let str = '';
  const aStr = cleanNum(a);
  const bStr = cleanNum(b);
  const cStr = cleanNum(c);

  if (aStr === '1') str += 'x^4';
  else if (aStr === '-1') str += '-x^4';
  else if (aStr !== '0') str += `${aStr}x^4`;

  const bVal = parseFloat(bStr);
  if (bVal > 0) {
    str += (str ? ' + ' : '') + (bStr === '1' ? 'x^2' : `${bStr}x^2`);
  } else if (bVal < 0) {
    str += (str ? ' - ' : '-') + (bStr === '-1' ? 'x^2' : `${cleanNum(Math.abs(bVal))}x^2`);
  }

  const cVal = parseFloat(cStr);
  if (cVal > 0) {
    str += (str ? ' + ' : '') + cStr;
  } else if (cVal < 0) {
    str += (str ? ' - ' : '-') + cleanNum(Math.abs(cVal));
  }

  return str || '0';
}

export function computeFormulaFromExactExtrema(analysis, x1, y1, x2, y2) {
  if (!analysis) return null;
  if (analysis.type === 'cubic') {
    if (Math.abs(x1 - x2) < 0.2) return null;
    const dx = x2 - x1;
    const a = (2 * (y1 - y2)) / Math.pow(dx, 3);
    if (Math.abs(a) < 1e-4) return null;

    const b = (-3 * a * (x1 + x2)) / 2;
    const c = 3 * a * x1 * x2;
    const d = y1 - (a * Math.pow(x1, 3) + b * Math.pow(x1, 2) + c * x1);
    return formatPoly3(a, b, c, d);
  } else if (analysis.type === 'quadratic') {
    const a = analysis.coeffs?.a || 1;
    const b = -2 * a * x1;
    const c = a * Math.pow(x1, 2) + y1;
    return formatPoly2(a, b, c);
  }
  return null;
}

/**
 * Compute inverse formula when user drags a control handle.
 * @param {Object} analysis - The current analysis object
 * @param {Object} handle - { type: 'extremum' | 'vertex' | 'asymptote_v' | 'asymptote_h', idx: number }
 * @param {number} rawX - New math X coordinate
 * @param {number} rawY - New math Y coordinate
 * @returns {string|null} - The reconstructed free-form formula string or null if unhandled
 */
export function computeFormulaFromDrag(analysis, handle, rawX, rawY) {
  if (!analysis) return null;

  // Snapping to clean integer / half-step grid so user can hit exact points easily
  const newX = magneticSnap(rawX);
  const newY = magneticSnap(rawY);

  const fnType = analysis.type;

  // 1. CUBIC POLYNOMIAL (BẬC 3)
  if (fnType === 'cubic') {
    const extrema = analysis.extrema || [];
    if (extrema.length >= 2 && handle.type === 'extremum') {
      const dragIdx = handle.idx ?? 0;
      const otherIdx = dragIdx === 0 ? 1 : 0;

      let x1 = newX;
      let y1 = newY;
      let x2 = magneticSnap(extrema[otherIdx].x);
      let y2 = magneticSnap(extrema[otherIdx].y);

      // Avoid singularity when x1 == x2
      if (Math.abs(x1 - x2) < 0.2) {
        x1 = x2 + (x1 >= x2 ? 0.2 : -0.2);
      }

      return computeFormulaFromExactExtrema(analysis, x1, y1, x2, y2);
    }
  }

  // 2. QUADRATIC PARABOLA (BẬC 2)
  if (fnType === 'quadratic') {
    const a = analysis.coeffs?.a || 1;
    // Vertex is at (newX, newY)
    // y = a*(x - newX)^2 + newY = a*x^2 - 2*a*newX*x + (a*newX^2 + newY)
    const b = -2 * a * newX;
    const c = a * Math.pow(newX, 2) + newY;
    return formatPoly2(a, b, c);
  }

  // 3. RATIONAL 1/1 (BẬC 1/1)
  if (fnType === 'rational1' || fnType === 'rational_1_1') {
    const coeffs = analysis.coeffs || { a: 1, b: 0, c: 1, d: 0 };
    // Current asymptotes: x0 = -d/c, y0 = a/c
    // If dragging vertical asymptote:
    if (handle.type === 'asymptote_v') {
      // New vertical asymptote is at newX => denominator is (x - newX)
      // Keep y0 = a/c and numerator stretch k = b - a*d/c
      const x0Old = -coeffs.d / coeffs.c;
      const y0 = coeffs.a / coeffs.c;
      const k = (coeffs.b * coeffs.c - coeffs.a * coeffs.d) / Math.pow(coeffs.c, 2);
      // y = y0 + k/(x - newX) = (y0*x - y0*newX + k) / (x - newX)
      const aNew = y0;
      const bNew = -y0 * newX + k;
      return formatRational11(aNew, bNew, 1, -newX);
    }
    if (handle.type === 'asymptote_h') {
      // New horizontal asymptote is at newY
      const x0 = -coeffs.d / coeffs.c;
      const k = (coeffs.b * coeffs.c - coeffs.a * coeffs.d) / Math.pow(coeffs.c, 2);
      // y = newY + k/(x - x0) = (newY*x - newY*x0 + k) / (x - x0)
      const aNew = newY;
      const bNew = -newY * x0 + k;
      return formatRational11(aNew, bNew, 1, -x0);
    }
  }

  // 4. QUARTIC (TRÙNG PHƯƠNG)
  if (fnType === 'quartic') {
    const extrema = analysis.extrema || [];
    if (extrema.length === 3 && handle.type === 'extremum') {
      const dragIdx = handle.idx ?? 0;
      const ext = extrema[dragIdx];
      // If dragging center extremum (at x=0):
      if (Math.abs(ext.x) < 0.1) {
        // Change c = newY
        const a = analysis.coeffs.a;
        const b = analysis.coeffs.b;
        return formatQuartic(a, b, newY);
      } else {
        // Dragging side extremum at x1
        const c = analysis.coeffs.c;
        const x1 = Math.abs(newX) > 0.3 ? Math.abs(newX) : 0.5;
        // y(x1) = -a*x1^4 + c = newY => a = (c - newY) / x1^4
        const a = (c - newY) / Math.pow(x1, 4);
        const b = -2 * a * Math.pow(x1, 2);
        return formatQuartic(a, b, c);
      }
    }
  }

  // 5. LINEAR (BẬC 1)
  if (fnType === 'linear') {
    const a = analysis.coeffs?.a || 1;
    // Keep slope, adjust intercept so line passes through (newX, newY) => b = newY - a*newX
    const b = newY - a * newX;
    return formatPoly1(a, b);
  }

  // 6. GENERAL / CAS / COMPLEX / HIGH-DEGREE FUNCTIONS (Trigonometric, x^5, etc.)
  if (fnType === 'general' || fnType === 'cas_function' || !fnType) {
    const extrema = analysis.extrema || [];
    if (handle.type === 'extremum' && extrema.length > 0) {
      const dragIdx = handle.idx ?? 0;
      const ext = extrema[dragIdx];
      if (!ext) return null;

      const deltaX = newX - ext.x;
      const deltaY = newY - ext.y;

      let rawFormula = (analysis.rawInput || analysis.formulaClean || analysis.formulaLatex || '')
        .replace(/^(?:y|f\(x\))\s*=\s*/i, '')
        .trim();

      return shiftGeneralFormula(rawFormula, deltaX, deltaY);
    }
  }

  return null;
}

/**
 * Shift general math formula vertically by deltaY and optionally horizontally by deltaX
 */
export function shiftGeneralFormula(rawFormula, deltaX = 0, deltaY = 0) {
  let result = rawFormula.trim();

  // 1. Vertical shift
  if (Math.abs(deltaY) >= 0.05) {
    const constantMatch = result.match(/\s*([+-])\s*(\d+(?:\.\d+)?)\s*$/);
    if (constantMatch) {
      const sign = constantMatch[1] === '-' ? -1 : 1;
      const oldVal = parseFloat(constantMatch[2]) * sign;
      const newVal = oldVal + deltaY;
      const prefix = result.substring(0, constantMatch.index).trim();
      if (Math.abs(newVal) < 1e-4) {
        result = prefix;
      } else {
        const newSign = newVal >= 0 ? '+' : '-';
        result = `${prefix} ${newSign} ${cleanNum(Math.abs(newVal))}`;
      }
    } else {
      const newSign = deltaY >= 0 ? '+' : '-';
      result = `${result} ${newSign} ${cleanNum(Math.abs(deltaY))}`;
    }
  }

  // 2. Horizontal phase shift (if deltaX is prominent and user dragged horizontally)
  if (Math.abs(deltaX) >= 0.25) {
    const shiftVal = cleanNum(deltaX);
    const shiftNum = parseFloat(shiftVal);
    if (Math.abs(shiftNum) > 0.05) {
      const existingShift = result.match(/\(\s*x\s*([+-])\s*(\d+(?:\.\d+)?)\s*\)/);
      if (existingShift) {
        const sign = existingShift[1] === '-' ? -1 : 1;
        const oldH = parseFloat(existingShift[2]) * sign;
        const newH = oldH - shiftNum;
        const replacement = Math.abs(newH) < 1e-4 ? 'x' : `(x ${newH >= 0 ? '+' : '-'} ${cleanNum(Math.abs(newH))})`;
        result = result.replace(existingShift[0], replacement);
      } else {
        const sign = shiftNum > 0 ? '-' : '+';
        result = result.replace(/\bx\b/g, `(x ${sign} ${cleanNum(Math.abs(shiftNum))})`);
      }
    }
  }

  return result;
}
