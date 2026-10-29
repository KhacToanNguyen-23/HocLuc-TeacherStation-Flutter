import * as math from 'mathjs';
import { compileFastEvaluator } from './parse.js';

/**
 * Converts a math expression string into clean display format with superscripts.
 * @param {string} expr - expression string (e.g. "4 * x - 3", "3 * x ^ 2 - 3")
 * @returns {string} formatted display string (e.g. "4x - 3", "3x² - 3")
 */
export function formatMathDisplay(expr) {
  if (!expr || typeof expr !== 'string') return '';
  let s = expr;

  // Remove multiplication before variables: 4 * x -> 4x
  s = s.replace(/(\d+)\s*\*\s*([a-zA-Z])/g, '$1$2');
  s = s.replace(/\*\s*/g, '');

  // Convert ^n to unicode superscripts
  const supers = {
    '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴',
    '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹',
  };
  s = s.replace(/\^\s*([0-9]+)/g, (match, p1) => {
    return p1.split('').map((c) => supers[c] || c).join('');
  });

  // Clean spacing around + and -
  s = s.replace(/\s*\+\s*/g, ' + ');
  s = s.replace(/\s*-\s*/g, ' - ');
  s = s.replace(/\s*\/\s*/g, ' / ');

  return s.trim();
}

/**
 * Computes the symbolic derivative of a parsed mathematical node with respect to x.
 * @param {math.MathNode} node - AST node from mathjs
 * @returns {object} derivative result with node, compiled evaluate, and formatted display
 */
export function computeDerivative(node) {
  try {
    const derivNode = math.derivative(node, 'x');
    const simplified = math.simplify(derivNode);
    const fastEvaluator = compileFastEvaluator(simplified) || compileFastEvaluator(derivNode);
    const compiled = simplified.compile();

    const evaluate = (x) => {
      if (fastEvaluator) {
        return fastEvaluator(x);
      }
      try {
        const val = compiled.evaluate({ x, e: Math.E, pi: Math.PI });
        if (typeof val === 'number') {
          if (!Number.isFinite(val)) return null;
          return val;
        }
        if (typeof val === 'object' && val !== null && val.isComplex) {
          return null;
        }
        return null;
      } catch (_) {
        return null;
      }
    };

    const rawString = simplified.toString();
    const display = formatMathDisplay(rawString);

    return {
      success: true,
      node: simplified,
      display,
      rawString,
      evaluate,
      error: null,
    };
  } catch (err) {
    return {
      success: false,
      node: null,
      display: 'Không xác định',
      rawString: '',
      evaluate: () => null,
      error: err.message,
    };
  }
}

