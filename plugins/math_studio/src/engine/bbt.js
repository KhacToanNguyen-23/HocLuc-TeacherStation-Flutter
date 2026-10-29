import { computeDerivative } from './derivative.js';
import { analyzeFunction } from './analyze.js';

/**
 * Builds the mathematical model of the Bảng Biến Thiên (BBT) following Vietnamese THPT standards.
 * @param {object} parsed - parsed function
 * @param {number} minX - domain lower bound
 * @param {number} maxX - domain upper bound
 * @returns {object} BBT structure with columns and variation arrows
 */
export function buildBBT(parsed, minX = -6, maxX = 6) {
  try {
    const analysis = analyzeFunction(parsed, { domainMin: minX, domainMax: maxX });
    const deriv = computeDerivative(parsed.node);

    // Collect all key x points (extrema + vertical asymptotes)
    const keyXSet = new Set();
    for (const ext of (analysis.extrema || [])) {
      keyXSet.add(ext.x);
    }
    for (const vert of (analysis.asymptotes?.vertical || [])) {
      keyXSet.add(vert);
    }

    const sortedKeyX = Array.from(keyXSet).sort((a, b) => a - b);

    // Build ordered column definitions:
    // [ -∞, ...inter-intervals and key points..., +∞ ]
    const columns = [];

    // Left limit (-∞)
    let yNegInf;
    if (analysis.asymptotes?.horizontal?.length > 0) {
      yNegInf = Number(analysis.asymptotes.horizontal[0].toFixed(2));
    } else {
      const valNeg = parsed.evaluate(-500);
      if (valNeg === null || Math.abs(valNeg) > 30) {
        yNegInf = (valNeg !== null && valNeg > 0) ? '+∞' : '-∞';
      } else {
        yNegInf = Number(valNeg.toFixed(1));
      }
    }

    columns.push({
      type: 'limit',
      x: -Infinity,
      labelX: '-∞',
      derivSign: null,
      yVal: yNegInf,
    });

    for (let i = 0; i < sortedKeyX.length; i++) {
      const kx = sortedKeyX[i];
      const isVerticalAsymptote = (analysis.asymptotes?.vertical || []).some((v) => Math.abs(v - kx) < 0.05);

      if (isVerticalAsymptote) {
        columns.push({
          type: 'asymptote',
          x: kx,
          labelX: Number(kx.toFixed(2)),
          derivSign: '||',
          yVal: '||',
        });
      } else {
        const yVal = parsed.evaluate(kx);
        columns.push({
          type: 'extremum',
          x: kx,
          labelX: Number(kx.toFixed(2)),
          derivSign: 0,
          yVal: yVal !== null ? Number(yVal.toFixed(2)) : 'ND',
        });
      }
    }

    // Right limit (+∞)
    let yPosInf;
    if (analysis.asymptotes?.horizontal?.length > 0) {
      yPosInf = Number(analysis.asymptotes.horizontal[0].toFixed(2));
    } else {
      const valPos = parsed.evaluate(500);
      if (valPos === null || Math.abs(valPos) > 30) {
        yPosInf = (valPos !== null && valPos > 0) ? '+∞' : '-∞';
      } else {
        yPosInf = Number(valPos.toFixed(1));
      }
    }

    columns.push({
      type: 'limit',
      x: Infinity,
      labelX: '+∞',
      derivSign: null,
      yVal: yPosInf,
    });

    // Build interval segments between consecutive columns
    const intervals = [];
    for (let i = 0; i < columns.length - 1; i++) {
      const c1 = columns[i];
      const c2 = columns[i + 1];

      let testX = 0;
      if (c1.x === -Infinity && c2.x === Infinity) {
        testX = 0;
      } else if (c1.x === -Infinity) {
        testX = c2.x - 1;
      } else if (c2.x === Infinity) {
        testX = c1.x + 1;
      } else {
        testX = (c1.x + c2.x) / 2;
      }

      const dVal = deriv.evaluate(testX);
      const sign = dVal !== null ? (dVal > 0 ? '+' : '-') : '?';

      // Determine variation direction (up or down)
      let direction = 'flat';
      if (sign === '+') direction = 'up';
      else if (sign === '-') direction = 'down';

      intervals.push({
        fromX: c1.x,
        toX: c2.x,
        sign,
        direction,
      });
    }

    return {
      success: true,
      columns,
      intervals,
    };
  } catch (err) {
    return {
      success: false,
      error: err.message,
    };
  }
}
