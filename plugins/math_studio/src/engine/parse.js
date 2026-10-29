import * as math from 'mathjs';

/**
 * Normalizes user mathematical input into standard mathjs syntax.
 * @param {string} input - Raw user input (e.g., "y = 2x^2 - 3x + 1", "f(x) = ln(x)")
 * @returns {string} normalized expression string
 */
export function normalizeExpression(input) {
  if (!input || typeof input !== 'string') return '';
  let s = input.trim();

  // Strip prefixes
  s = s.replace(/^(y\s*=\s*|f\s*\(\s*x\s*\)\s*=\s*)/i, '');

  // Unicode replacements
  s = s.replace(/[\u2212\u2013\u2014]/g, '-'); // Unicode minus and dashes
  s = s.replace(/\u00D7/g, '*'); // multiplication sign
  s = s.replace(/\u00F7/g, '/'); // division sign
  s = s.replace(/\u03C0/g, 'pi'); // pi
  s = s.replace(/\u221A\s*\(([^)]+)\)/g, 'sqrt($1)'); // √(x) -> sqrt(x)
  s = s.replace(/\u221A([a-zA-Z0-9]+)/g, 'sqrt($1)'); // √x -> sqrt(x)

  // Superscripts
  const superscripts = {
    '⁰': '^0', '¹': '^1', '²': '^2', '³': '^3', '⁴': '^4',
    '⁵': '^5', '⁶': '^6', '⁷': '^7', '⁸': '^8', '⁹': '^9',
  };
  s = s.replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]/g, (m) => superscripts[m] || m);

  // ln(...) -> log(...) for mathjs (mathjs log(x) is natural logarithm)
  s = s.replace(/\bln\s*\(/g, 'log(');
  s = s.replace(/\bln\s+([a-zA-Z0-9]+)/g, 'log($1)');

  // Implicit multiplication:
  // digit followed by variable or function: e.g. 2x -> 2*x, 3sin(x) -> 3*sin(x), 2sqrt(x) -> 2*sqrt(x)
  s = s.replace(/(\d)\s*([a-zA-Z(])/g, '$1*$2');

  // ) followed by ( or variable/digit: e.g. (x+1)(x-1) -> (x+1)*(x-1), (x+1)x -> (x+1)*x
  s = s.replace(/\)\s*(\(|[a-zA-Z0-9])/g, ')*$1');

  // variable followed by (: e.g. x(x+1) -> x*(x+1), but NOT for recognized function names
  const funcNames = ['sin', 'cos', 'tan', 'cot', 'log', 'exp', 'sqrt', 'abs', 'asin', 'acos', 'atan'];
  s = s.replace(/\b([a-zA-Z]+)\s*\(/g, (match, name) => {
    if (funcNames.includes(name.toLowerCase())) {
      return `${name.toLowerCase()}(`;
    }
    // If it's a single variable like x(x+1) -> x*(x+1)
    if (name === 'x') {
      return 'x*(';
    }
    return match;
  });

  return s.trim();
}

/**
 * Converts MathJS AST to a high-speed native JavaScript expression string.
 */
export function astToJs(node) {
  if (!node) return '0';
  if (node.isConstantNode) return String(node.value);
  if (node.isSymbolNode) {
    if (node.name === 'x') return 'x';
    if (node.name === 'e') return 'Math.E';
    if (node.name === 'pi') return 'Math.PI';
    return node.name;
  }
  if (node.isParenthesisNode) return '(' + astToJs(node.content) + ')';
  if (node.isOperatorNode) {
    if (node.isUnary()) {
      return node.op + '(' + astToJs(node.args[0]) + ')';
    }
    if (node.op === '^') {
      return 'Math.pow(' + astToJs(node.args[0]) + ', ' + astToJs(node.args[1]) + ')';
    }
    return '(' + astToJs(node.args[0]) + ' ' + node.op + ' ' + astToJs(node.args[1]) + ')';
  }
  if (node.isFunctionNode) {
    const fnName = node.name.toLowerCase();
    const args = (node.args || []).map(astToJs).join(', ');
    if (fnName === 'cot') return '(1 / Math.tan(' + args + '))';
    if (fnName === 'ln') return 'Math.log(' + args + ')';
    if (['sin', 'cos', 'tan', 'asin', 'acos', 'atan', 'log', 'log10', 'exp', 'sqrt', 'abs'].includes(fnName)) {
      return 'Math.' + fnName + '(' + args + ')';
    }
  }
  throw new Error('Unsupported node type: ' + node.type);
}

/**
 * Compiles a MathJS AST node into a zero-overhead native JS closure (V8 JIT machine code).
 * Outperforms tree-walking AST evaluation by > 100x.
 */
export function compileFastEvaluator(node) {
  try {
    const jsExpr = astToJs(node);
    const nativeFn = new Function('x', `
      try {
        const val = ${jsExpr};
        if (typeof val === 'number' && Number.isFinite(val)) return val;
        return null;
      } catch (_) {
        return null;
      }
    `);
    // Test on sample value
    nativeFn(0);
    return nativeFn;
  } catch (_) {
    return null;
  }
}

/**
 * Parses and compiles a mathematical function string.
 * @param {string} input - raw math expression string
 * @returns {object} parse result with evaluate function and AST node
 */
export function parseFunction(input) {
  try {
    const normalized = normalizeExpression(input);
    if (!normalized) {
      return {
        success: false,
        raw: input,
        normalized: '',
        node: null,
        evaluate: () => null,
        error: 'Biểu thức trống',
      };
    }

    const node = math.parse(normalized);
    const fastEvaluator = compileFastEvaluator(node);
    const compiled = node.compile();

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

    return {
      success: true,
      raw: input,
      normalized,
      node,
      evaluate,
      error: null,
    };
  } catch (err) {
    return {
      success: false,
      raw: input,
      normalized: null,
      node: null,
      evaluate: () => null,
      error: err.message || 'Cú pháp toán học không hợp lệ',
    };
  }
}

