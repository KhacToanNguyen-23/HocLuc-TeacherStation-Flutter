import * as math from 'mathjs';
import { formatMathDisplay } from './derivative.js';

/**
 * Elementary symbolic antiderivative solver for standard THPT functions.
 * Eliminates heavy 1MB nerdamer bundle completely while covering all standard high school curricula.
 */
function integrateNode(node) {
  if (!node) return null;
  // Constant c -> c * x
  if (node.isConstantNode) {
    if (node.value === 0) return math.parse('0');
    return math.parse(`${node.value} * x`);
  }
  // Variable x -> x^2 / 2
  if (node.isSymbolNode && node.name === 'x') {
    return math.parse('(x^2) / 2');
  }
  // Constant symbol (e, pi) -> c * x
  if (node.isSymbolNode && node.name !== 'x') {
    return math.parse(`${node.name} * x`);
  }
  // Parenthesis (u) -> integrate(u)
  if (node.isParenthesisNode) {
    const inner = integrateNode(node.content);
    return inner ? math.parse(`(${inner.toString()})`) : null;
  }
  // Unary -u -> -integrate(u)
  if (node.isOperatorNode && typeof node.isUnary === 'function' && node.isUnary() && node.op === '-') {
    const inner = integrateNode(node.args[0]);
    return inner ? math.parse(`-(${inner.toString()})`) : null;
  }
  // Addition / Subtraction: int(u +/- v) = int(u) +/- int(v)
  if (node.isOperatorNode && (node.op === '+' || node.op === '-')) {
    const left = integrateNode(node.args[0]);
    const right = integrateNode(node.args[1]);
    if (left && right) {
      return math.parse(`(${left.toString()}) ${node.op} (${right.toString()})`);
    }
  }
  // Multiplication by constant: c * u -> c * int(u)
  if (node.isOperatorNode && node.op === '*') {
    const [a, b] = node.args;
    if (a.isConstantNode) {
      const intB = integrateNode(b);
      if (intB) return math.parse(`${a.value} * (${intB.toString()})`);
    }
    if (b.isConstantNode) {
      const intA = integrateNode(a);
      if (intA) return math.parse(`${b.value} * (${intA.toString()})`);
    }
  }
  // Power: x^n -> x^(n+1) / (n+1)
  if (node.isOperatorNode && node.op === '^') {
    const [base, exp] = node.args;
    if (base.isSymbolNode && base.name === 'x' && exp.isConstantNode) {
      const n = exp.value;
      if (n !== -1) {
        return math.parse(`(x^${n + 1}) / ${n + 1}`);
      }
      return math.parse('log(abs(x))');
    }
  }
  // Division: c / x -> c * log(abs(x))
  if (node.isOperatorNode && node.op === '/') {
    const [num, den] = node.args;
    if (num.isConstantNode && den.isSymbolNode && den.name === 'x') {
      return math.parse(`${num.value} * log(abs(x))`);
    }
    if (num.isConstantNode && den.isOperatorNode && den.op === '^' && den.args[0].isSymbolNode && den.args[0].name === 'x' && den.args[1].isConstantNode) {
      const n = den.args[1].value;
      if (n !== 1) {
        return math.parse(`(${num.value} * (x^${-n + 1})) / ${-n + 1}`);
      }
    }
  }
  // Elementary trig & exp functions
  if (node.isFunctionNode) {
    const fn = node.name.toLowerCase();
    const arg = node.args[0];
    if (arg && arg.isSymbolNode && arg.name === 'x') {
      if (fn === 'sin') return math.parse('-cos(x)');
      if (fn === 'cos') return math.parse('sin(x)');
      if (fn === 'exp') return math.parse('exp(x)');
      if (fn === 'log' || fn === 'ln') return math.parse('x * log(x) - x');
    }
  }
  return null;
}

/**
 * Computes symbolic antiderivative (indefinite integral) of standard THPT functions.
 * @param {string} rawExpr - Expression string (e.g. "x^3 - 3x", "log(x)")
 * @returns {object} result with display string
 */
export function computeAntiderivative(rawExpr) {
  try {
    if (!rawExpr || typeof rawExpr !== 'string') {
      return { success: false, display: 'Không xác định' };
    }

    let expr = rawExpr.trim();
    expr = expr.replace(/^(y\s*=\s*|f\s*\(\s*x\s*\)\s*=\s*)/i, '');
    expr = expr.replace(/\bln\b/g, 'log');

    const node = math.parse(expr);
    const intNode = integrateNode(node);
    if (!intNode) {
      return { success: false, display: 'Không có nguyên hàm sơ cấp' };
    }

    const simplified = math.simplify(intNode);
    const cleanDisplay = formatMathDisplay(simplified.toString());
    return {
      success: true,
      raw: simplified.toString(),
      display: `${cleanDisplay} + C`,
    };
  } catch (err) {
    return {
      success: false,
      display: 'Không có nguyên hàm sơ cấp',
      error: err.message,
    };
  }
}

/**
 * Adaptive Simpson's numerical quadrature for definite integrals \int_a^b f(x) dx.
 */
function simpsonRule(fn, a, b) {
  const fa = fn(a) ?? 0;
  const fb = fn(b) ?? 0;
  const c = (a + b) / 2;
  const fc = fn(c) ?? 0;
  return ((b - a) / 6) * (fa + 4 * fc + fb);
}

function adaptiveSimpson(fn, a, b, eps, whole, depth = 0, maxDepth = 20) {
  const c = (a + b) / 2;
  const left = simpsonRule(fn, a, c);
  const right = simpsonRule(fn, c, b);
  const delta = left + right - whole;

  if (depth >= maxDepth || Math.abs(delta) <= 15 * eps) {
    return left + right + delta / 15;
  }
  return (
    adaptiveSimpson(fn, a, c, eps / 2, left, depth + 1, maxDepth) +
    adaptiveSimpson(fn, c, b, eps / 2, right, depth + 1, maxDepth)
  );
}

/**
 * Computes definite integral of a parsed function from a to b.
 */
export function computeDefiniteIntegral(parsed, a, b, eps = 1e-6) {
  const fn = parsed.evaluate;
  const whole = simpsonRule(fn, a, b);
  const val = adaptiveSimpson(fn, a, b, eps, whole);
  return {
    value: val,
    a,
    b,
  };
}

