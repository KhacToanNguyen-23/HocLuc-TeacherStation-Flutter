/**
 * Free-form Math Expression Parser & Normalizer
 * Bridges user-typed expressions with the Universal CAS Engine
 */

import { analyzeFunction, normalizeExpression, compileFunction } from './math_cas.js';

export { normalizeExpression, compileFunction };

/**
 * Main Entrypoint: Parses free-form user string and returns complete analysis
 */
export function parseAndAnalyze(rawExpr, bounds = { xMin: -6, xMax: 6, yMin: -4.1, yMax: 4.1 }) {
  if (!rawExpr || !rawExpr.trim()) {
    throw new Error('Vui lòng nhập hàm số.');
  }
  return analyzeFunction(rawExpr, bounds);
}
