import { computeDefiniteIntegral } from './integrate.js';

/**
 * Computes the volume of revolution of f(x) revolved around the x-axis (Ox) on [a, b].
 * Formula: V = \pi \int_a^b [f(x)]^2 dx
 * @param {object} parsed - parsed function object
 * @param {number} a - interval start
 * @param {number} b - interval end
 * @returns {object} { volume, rawIntegral, a, b }
 */
export function computeRevolutionVolume(parsed, a, b) {
  // Wrap f(x)^2 for numerical integration
  const fSquared = {
    evaluate: (x) => {
      const y = parsed.evaluate(x);
      return y === null ? 0 : y * y;
    },
  };

  const integral = computeDefiniteIntegral(fSquared, a, b);
  const volume = Math.PI * integral.value;

  return {
    volume,
    rawIntegral: integral.value,
    a,
    b,
  };
}

