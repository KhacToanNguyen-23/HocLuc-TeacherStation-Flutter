/**
 * Zero-Dependency Symbolic CAS Engine
 * Parses mathematical expressions into AST, computes exact symbolic derivatives,
 * and performs algebraic simplification to generate clean textbook LaTeX/display formulas.
 */

// 1. Tokenizer
function tokenize(input) {
  let s = input.trim();
  // Strip leading y= or f(x)=
  s = s.replace(/^(?:y|f\(x\)|f)\s*=\s*/i, '');
  // Unicode exponents to ^
  s = s.replace(/²/g, '^2').replace(/³/g, '^3').replace(/⁴/g, '^4');
  
  const tokens = [];
  let i = 0;

  while (i < s.length) {
    const ch = s[i];

    if (/\s/.test(ch)) {
      i++;
      continue;
    }

    if (/[0-9]/.test(ch) || (ch === '.' && /[0-9]/.test(s[i + 1]))) {
      let numStr = '';
      while (i < s.length && (/[0-9]/.test(s[i]) || s[i] === '.')) {
        numStr += s[i];
        i++;
      }
      tokens.push({ type: 'NUM', val: parseFloat(numStr) });
      continue;
    }

    if (/[a-zA-Z]/.test(ch)) {
      let idStr = '';
      while (i < s.length && /[a-zA-Z0-9_]/.test(s[i])) {
        idStr += s[i];
        i++;
      }
      if (idStr.toLowerCase() === 'x') {
        tokens.push({ type: 'VAR', val: 'x' });
      } else if (idStr.toLowerCase() === 'e') {
        tokens.push({ type: 'CONST', val: 'e', num: Math.E });
      } else if (idStr.toLowerCase() === 'pi') {
        tokens.push({ type: 'CONST', val: 'pi', num: Math.PI });
      } else {
        tokens.push({ type: 'FN', val: idStr.toLowerCase() });
      }
      continue;
    }

    if ('+-*/^()'.includes(ch)) {
      tokens.push({ type: 'OP', val: ch });
      i++;
      continue;
    }

    i++;
  }

  // Insert implicit multiplications: e.g. 3x -> 3 * x, 2sin -> 2 * sin, x( -> x * (, )( -> ) * (
  const out = [];
  for (let k = 0; k < tokens.length; k++) {
    const cur = tokens[k];
    out.push(cur);
    if (k + 1 < tokens.length) {
      const next = tokens[k + 1];
      const curIsVal = cur.type === 'NUM' || cur.type === 'VAR' || cur.type === 'CONST' || (cur.type === 'OP' && cur.val === ')');
      const nextIsVal = next.type === 'VAR' || next.type === 'CONST' || next.type === 'FN' || (next.type === 'OP' && next.val === '(');
      if (curIsVal && nextIsVal) {
        out.push({ type: 'OP', val: '*' });
      }
    }
  }

  return out;
}

// 2. Recursive Descent Parser (AST)
export function parseExpressionToAST(exprStr) {
  const tokens = tokenize(exprStr);
  let pos = 0;

  function peek() {
    return tokens[pos];
  }

  function consume(expectedVal) {
    const t = tokens[pos];
    if (expectedVal && (!t || t.val !== expectedVal)) {
      throw new Error(`Kỳ vọng '${expectedVal}' nhưng gặp '${t ? t.val : 'EOF'}'`);
    }
    pos++;
    return t;
  }

  // Precedence: +, - < *, / < unary -, + < ^
  function parseAddSub() {
    let node = parseMulDiv();
    while (pos < tokens.length && (peek().val === '+' || peek().val === '-')) {
      const op = consume().val;
      const right = parseMulDiv();
      node = { type: 'op', op, left: node, right };
    }
    return node;
  }

  function parseMulDiv() {
    let node = parseUnary();
    while (pos < tokens.length && (peek().val === '*' || peek().val === '/')) {
      const op = consume().val;
      const right = parseUnary();
      node = { type: 'op', op, left: node, right };
    }
    return node;
  }

  function parseUnary() {
    if (pos < tokens.length && peek().val === '-') {
      consume('-');
      const expr = parsePower();
      return { type: 'neg', expr };
    }
    if (pos < tokens.length && peek().val === '+') {
      consume('+');
      return parsePower();
    }
    return parsePower();
  }

  function parsePower() {
    let node = parsePrimary();
    if (pos < tokens.length && peek().val === '^') {
      consume('^');
      const right = parseUnary(); // right-associative
      node = { type: 'op', op: '^', left: node, right };
    }
    return node;
  }

  function parsePrimary() {
    const t = peek();
    if (!t) throw new Error('Biểu thức kết thúc bất ngờ');

    if (t.type === 'NUM') {
      consume();
      return { type: 'num', value: t.val };
    }

    if (t.type === 'VAR') {
      consume();
      return { type: 'var', name: 'x' };
    }

    if (t.type === 'CONST') {
      consume();
      return { type: 'const', name: t.val, value: t.num };
    }

    if (t.type === 'FN') {
      const fnName = consume().val;
      if (peek() && peek().val === '(') {
        consume('(');
        const arg = parseAddSub();
        consume(')');
        return { type: 'call', name: fnName, arg };
      }
      throw new Error(`Hàm '${fnName}' thiếu dấu ngoặc mở ()`);
    }

    if (t.val === '(') {
      consume('(');
      const expr = parseAddSub();
      consume(')');
      return expr;
    }

    throw new Error(`Ký tự không hợp lệ: '${t.val}'`);
  }

  if (tokens.length === 0) {
    return { type: 'num', value: 0 };
  }

  const ast = parseAddSub();
  if (pos < tokens.length) {
    throw new Error(`Cú pháp dư thừa ở '${peek().val}'`);
  }
  return ast;
}

// 3. Symbolic Differentiator
export function differentiateAST(node, varName = 'x') {
  if (!node) return { type: 'num', value: 0 };

  switch (node.type) {
    case 'num':
    case 'const':
      return { type: 'num', value: 0 };

    case 'var':
      return node.name === varName ? { type: 'num', value: 1 } : { type: 'num', value: 0 };

    case 'neg':
      return { type: 'neg', expr: differentiateAST(node.expr, varName) };

    case 'op': {
      const { op, left, right } = node;
      if (op === '+') {
        return { type: 'op', op: '+', left: differentiateAST(left, varName), right: differentiateAST(right, varName) };
      }
      if (op === '-') {
        return { type: 'op', op: '-', left: differentiateAST(left, varName), right: differentiateAST(right, varName) };
      }
      if (op === '*') {
        // Product rule: (u*v)' = u'*v + u*v'
        const uPrime = differentiateAST(left, varName);
        const vPrime = differentiateAST(right, varName);
        return {
          type: 'op',
          op: '+',
          left: { type: 'op', op: '*', left: uPrime, right: left },
          right: { type: 'op', op: '*', left, right: vPrime }
        };
      }
      if (op === '/') {
        // Quotient rule: (u/v)' = (u'*v - u*v') / (v^2)
        const uPrime = differentiateAST(left, varName);
        const vPrime = differentiateAST(right, varName);
        return {
          type: 'op',
          op: '/',
          left: {
            type: 'op',
            op: '-',
            left: { type: 'op', op: '*', left: uPrime, right },
            right: { type: 'op', op: '*', left, right: vPrime }
          },
          right: { type: 'op', op: '^', left: right, right: { type: 'num', value: 2 } }
        };
      }
      if (op === '^') {
        // Power rule: (u^n)' = n * u^(n-1) * u' if n is constant number
        if (right.type === 'num') {
          const n = right.value;
          const uPrime = differentiateAST(left, varName);
          return {
            type: 'op',
            op: '*',
            left: {
              type: 'op',
              op: '*',
              left: { type: 'num', value: n },
              right: { type: 'op', op: '^', left, right: { type: 'num', value: n - 1 } }
            },
            right: uPrime
          };
        }
        // General (u^v)' = u^v * (v'*ln(u) + v*u'/u)
        const uPrime = differentiateAST(left, varName);
        const vPrime = differentiateAST(right, varName);
        return {
          type: 'op',
          op: '*',
          left: node,
          right: {
            type: 'op',
            op: '+',
            left: { type: 'op', op: '*', left: vPrime, right: { type: 'call', name: 'ln', arg: left } },
            right: {
              type: 'op',
              op: '/',
              left: { type: 'op', op: '*', left: right, right: uPrime },
              right: left
            }
          }
        };
      }
      break;
    }

    case 'call': {
      const { name, arg } = node;
      const uPrime = differentiateAST(arg, varName);

      if (name === 'sin') {
        // (sin(u))' = cos(u) * u'
        return {
          type: 'op',
          op: '*',
          left: { type: 'call', name: 'cos', arg },
          right: uPrime
        };
      }
      if (name === 'cos') {
        // (cos(u))' = -sin(u) * u'
        return {
          type: 'op',
          op: '*',
          left: { type: 'neg', expr: { type: 'call', name: 'sin', arg } },
          right: uPrime
        };
      }
      if (name === 'tan') {
        // (tan(u))' = (1 / cos(u)^2) * u'
        return {
          type: 'op',
          op: '/',
          left: uPrime,
          right: {
            type: 'op',
            op: '^',
            left: { type: 'call', name: 'cos', arg },
            right: { type: 'num', value: 2 }
          }
        };
      }
      if (name === 'exp') {
        // (exp(u))' = exp(u) * u'
        return {
          type: 'op',
          op: '*',
          left: node,
          right: uPrime
        };
      }
      if (name === 'ln') {
        // (ln(u))' = u' / u
        return {
          type: 'op',
          op: '/',
          left: uPrime,
          right: arg
        };
      }
      if (name === 'sqrt') {
        // (sqrt(u))' = u' / (2 * sqrt(u))
        return {
          type: 'op',
          op: '/',
          left: uPrime,
          right: {
            type: 'op',
            op: '*',
            left: { type: 'num', value: 2 },
            right: { type: 'call', name: 'sqrt', arg }
          }
        };
      }
      break;
    }
  }

  return { type: 'num', value: 0 };
}

// 4. Algebraic Simplifier
export function simplifyAST(node) {
  if (!node) return null;

  if (node.type === 'num' || node.type === 'var' || node.type === 'const') {
    return node;
  }

  if (node.type === 'neg') {
    const expr = simplifyAST(node.expr);
    if (expr.type === 'num') {
      return { type: 'num', value: -expr.value };
    }
    if (expr.type === 'neg') {
      return expr.expr;
    }
    return { type: 'neg', expr };
  }

  if (node.type === 'call') {
    const arg = simplifyAST(node.arg);
    return { type: 'call', name: node.name, arg };
  }

  if (node.type === 'op') {
    const left = simplifyAST(node.left);
    const right = simplifyAST(node.right);
    const { op } = node;

    // Constant evaluation
    if (left.type === 'num' && right.type === 'num') {
      if (op === '+') return { type: 'num', value: left.value + right.value };
      if (op === '-') return { type: 'num', value: left.value - right.value };
      if (op === '*') return { type: 'num', value: left.value * right.value };
      if (op === '/' && right.value !== 0) {
        if (left.value % right.value === 0) {
          return { type: 'num', value: left.value / right.value };
        }
      }
      if (op === '^') return { type: 'num', value: Math.pow(left.value, right.value) };
    }

    // Multiplication rules: 0 * u = 0, 1 * u = u
    if (op === '*') {
      if ((left.type === 'num' && left.value === 0) || (right.type === 'num' && right.value === 0)) {
        return { type: 'num', value: 0 };
      }
      if (left.type === 'num' && left.value === 1) return right;
      if (right.type === 'num' && right.value === 1) return left;
    }

    // Addition rules: 0 + u = u
    if (op === '+') {
      if (left.type === 'num' && left.value === 0) return right;
      if (right.type === 'num' && right.value === 0) return left;
    }

    // Subtraction rules: u - 0 = u, 0 - u = -u
    if (op === '-') {
      if (right.type === 'num' && right.value === 0) return left;
      if (left.type === 'num' && left.value === 0) return { type: 'neg', expr: right };
    }

    // Division rules: u / 1 = u, 0 / u = 0
    if (op === '/') {
      if (right.type === 'num' && right.value === 1) return left;
      if (left.type === 'num' && left.value === 0) return { type: 'num', value: 0 };
    }

    // Power rules: u ^ 1 = u, u ^ 0 = 1
    if (op === '^') {
      if (right.type === 'num' && right.value === 0) return { type: 'num', value: 1 };
      if (right.type === 'num' && right.value === 1) return left;
      if (left.type === 'num' && left.value === 0) return { type: 'num', value: 0 };
      if (left.type === 'num' && left.value === 1) return { type: 'num', value: 1 };
    }

    return { type: 'op', op, left, right };
  }

  return node;
}

// 5. AST to Mathematical String / LaTeX
export function formatAST(node, options = {}) {
  const { isLatex = false, parentPrecedence = 0 } = options;
  if (!node) return '0';

  const precedence = {
    '+': 1,
    '-': 1,
    '*': 2,
    '/': 2,
    '^': 3,
    'neg': 4,
    'call': 5,
    'primary': 6
  };

  switch (node.type) {
    case 'num':
      return `${Math.round(node.value * 1000) / 1000}`;

    case 'var':
      return node.name;

    case 'const':
      return node.name === 'pi' ? (isLatex ? '\\pi' : 'π') : node.name;

    case 'neg': {
      const inner = formatAST(node.expr, { isLatex, parentPrecedence: precedence.neg });
      return `-${inner}`;
    }

    case 'call': {
      const inner = formatAST(node.arg, { isLatex, parentPrecedence: 0 });
      return `${node.name}(${inner})`;
    }

    case 'op': {
      const curPrec = precedence[node.op] || 0;
      const leftStr = formatAST(node.left, { isLatex, parentPrecedence: curPrec });
      const rightStr = formatAST(node.right, { isLatex, parentPrecedence: curPrec + 0.1 });

      if (node.op === '/') {
        if (isLatex) {
          return `\\frac{${leftStr}}{${rightStr}}`;
        }
        return `(${leftStr}) / (${rightStr})`;
      }

      if (node.op === '^') {
        const base = formatAST(node.left, { isLatex, parentPrecedence: curPrec + 1 });
        if (isLatex) {
          return `${base}^{${rightStr}}`;
        }
        return `${base}^${rightStr}`;
      }

      let res = '';
      if (node.op === '*') {
        // e.g. 3 * x -> 3x, 3 * x^2 -> 3x^2, 2 * cos(x) -> 2cos(x)
        if (node.left.type === 'num' && (node.right.type === 'var' || node.right.type === 'call' || (node.right.type === 'op' && node.right.op === '^'))) {
          res = `${leftStr}${rightStr}`;
        } else if (node.right.type === 'num') {
          res = `${rightStr}${leftStr}`;
        } else {
          res = `${leftStr}${isLatex ? ' ' : ' * '}${rightStr}`;
        }
      } else {
        res = `${leftStr} ${node.op} ${rightStr}`;
      }

      if (curPrec < parentPrecedence) {
        return `(${res})`;
      }
      return res;
    }
  }

  return '0';
}

/**
 * High-level API: Computes exact symbolic derivative formula string
 */
export function computeSymbolicDerivative(rawFormula) {
  try {
    const ast = parseExpressionToAST(rawFormula);
    const derAst = differentiateAST(ast, 'x');
    const simplified = simplifyAST(derAst);
    const textFormula = formatAST(simplified, { isLatex: false });
    const latexFormula = formatAST(simplified, { isLatex: true });
    return {
      success: true,
      raw: textFormula,
      latex: `y' = ${latexFormula}`,
      display: `y' = ${textFormula}`
    };
  } catch (err) {
    return {
      success: false,
      raw: "f'(x)",
      latex: "y' = f'(x)",
      display: "y' = f'(x)",
      error: err.message
    };
  }
}
