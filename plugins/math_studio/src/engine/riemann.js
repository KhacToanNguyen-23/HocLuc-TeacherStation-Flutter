/**
 * Computes Riemann sum and column rectangles for f(x) on [a, b].
 * @param {object} parsed - parsed function object
 * @param {number} a - interval start
 * @param {number} b - interval end
 * @param {number} n - number of rectangles (4 to 50)
 * @param {'left' | 'right' | 'midpoint'} mode - sampling mode
 * @returns {object} Riemann sum result and rectangle geometric specifications
 */
export function computeRiemannSum(parsed, a, b, n = 10, mode = 'midpoint') {
  const dx = (b - a) / n;
  const rectangles = [];
  let sum = 0;

  for (let i = 0; i < n; i++) {
    const xLeft = a + i * dx;
    const xRight = a + (i + 1) * dx;

    let sampleX = xLeft;
    if (mode === 'right') {
      sampleX = xRight;
    } else if (mode === 'midpoint') {
      sampleX = (xLeft + xRight) / 2;
    }

    const sampleY = parsed.evaluate(sampleX) ?? 0;
    const colSum = sampleY * dx;
    sum += colSum;

    rectangles.push({
      index: i,
      x: xLeft,
      y: sampleY >= 0 ? 0 : sampleY,
      width: dx,
      height: Math.abs(sampleY),
      sampleX,
      sampleY,
      area: colSum,
    });
  }

  return {
    sum,
    rectangles,
    n,
    mode,
    a,
    b,
    dx,
  };
}

