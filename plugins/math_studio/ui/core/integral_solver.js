/**
 * Integral & Area Solver
 * Computes definite integral and geometric area between f(x) and Ox on [a, b].
 */

export function solveIntegral(analysis, a, b) {
  if (a >= b) {
    throw new Error('Cận dưới a phải nhỏ hơn cận trên b (a < b).');
  }

  // Check if singular point falls inside [a, b]
  if (analysis.tableData?.hasSingularity) {
    const sX = analysis.tableData.singularX;
    if (sX >= a && sX <= b) {
      throw new Error(`Điểm gián đoạn x = ${sX.toFixed(2)} nằm trong đoạn lấy tích phân [${a}, ${b}]. Tích phân suy rộng không thuộc SGK cơ bản.`);
    }
  }

  const f = analysis.eval;

  // Numerical integration via Adaptive Simpson's Rule
  const signedIntegral = simpson(f, a, b, 200);
  const area = simpson((x) => Math.abs(f(x)), a, b, 200);

  // Antiderivative F(x) string
  const antiderivativeStr = getAntiderivativeString(analysis);

  return {
    a,
    b,
    signedIntegral,
    area,
    displayIntegral: signedIntegral.toFixed(4),
    displayArea: area.toFixed(4),
    antiderivative: antiderivativeStr,
    formulaLatex: `S = \\int_{${a}}^{${b}} |f(x)| dx \\approx ${area.toFixed(4)}`,
    formulaHtml: `S = <span style="font-size: 16px; font-family: 'Cambria Math', serif; font-weight: bold; margin: 0 1px;">∫</span><sup style="font-size: 10px; font-weight: 600; margin-left: -2px;">${b}</sup><sub style="font-size: 10px; font-weight: 600; margin-left: -5px;">${a}</sub> |f(x)| dx ≈ <span style="color: #0B3A82; font-weight: bold;">${area.toFixed(4)}</span>`,
    formulaDisplay: `S = ∫[${a} → ${b}] |f(x)| dx ≈ ${area.toFixed(4)}`
  };
}

function cleanDec(n) {
  const r = Math.round(n * 100) / 100;
  return r.toString();
}

/**
 * Symbolic antiderivative F(x) for standard high-school functions
 */
function getAntiderivativeString(analysis) {
  if (!analysis) return 'F(x)';
  const t = analysis.type;
  const c = analysis.coeffs;

  if (t === 'cubic' && c) {
    // f(x) = ax^3 + bx^2 + cx + d => F(x) = (a/4)x^4 + (b/3)x^3 + (c/2)x^2 + dx
    const a4 = cleanDec(c.a / 4);
    const b3 = cleanDec(c.b / 3);
    const c2 = cleanDec(c.c / 2);
    const d = cleanDec(c.d);
    return `${a4 === '1' ? '' : a4}x^4 ${parseFloat(b3) >= 0 ? '+ ' : ''}${b3}x^3 ${parseFloat(c2) >= 0 ? '+ ' : ''}${c2}x^2 ${parseFloat(d) >= 0 ? '+ ' : ''}${d}x + C`.replace(/\+\s*\-/g, '- ');
  }

  if (t === 'quadratic' && c) {
    // f(x) = ax^2 + bx + c => F(x) = (a/3)x^3 + (b/2)x^2 + cx
    const a3 = cleanDec(c.a / 3);
    const b2 = cleanDec(c.b / 2);
    const c1 = cleanDec(c.c);
    return `${a3 === '1' ? '' : a3}x^3 ${parseFloat(b2) >= 0 ? '+ ' : ''}${b2}x^2 ${parseFloat(c1) >= 0 ? '+ ' : ''}${c1}x + C`.replace(/\+\s*\-/g, '- ');
  }

  if (t === 'quartic' && c) {
    // f(x) = ax^4 + bx^2 + c => F(x) = (a/5)x^5 + (b/3)x^3 + cx
    const a5 = cleanDec(c.a / 5);
    const b3 = cleanDec(c.b / 3);
    const c1 = cleanDec(c.c);
    return `${a5 === '1' ? '' : a5}x^5 ${parseFloat(b3) >= 0 ? '+ ' : ''}${b3}x^3 ${parseFloat(c1) >= 0 ? '+ ' : ''}${c1}x + C`.replace(/\+\s*\-/g, '- ');
  }

  if (t === 'linear' && c) {
    const a2 = cleanDec(c.a / 2);
    const b = cleanDec(c.b);
    return `${a2 === '1' ? '' : a2}x^2 ${parseFloat(b) >= 0 ? '+ ' : ''}${b}x + C`.replace(/\+\s*\-/g, '- ');
  }

  if (t === 'rational1' && c) {
    // f(x) = (ax + b)/(cx + d) = a/c + k/(cx + d)
    const y0 = cleanDec(c.a / c.c);
    const k = cleanDec((c.b * c.c - c.a * c.d) / Math.pow(c.c, 2));
    return `${y0}x + ${k}·ln|${c.c === 1 ? '' : c.c}x ${c.d >= 0 ? '+ ' : ''}${c.d}| + C`;
  }

  return 'F(x) + C';
}

/**
 * Composite Simpson's Rule
 */
function simpson(f, a, b, n = 100) {
  if (n % 2 !== 0) n++;
  const h = (b - a) / n;
  let sum = f(a) + f(b);

  for (let i = 1; i < n; i++) {
    const x = a + i * h;
    sum += (i % 2 === 0 ? 2 : 4) * f(x);
  }

  return (h / 3) * sum;
}

