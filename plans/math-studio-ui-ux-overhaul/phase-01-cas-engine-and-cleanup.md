# Phase 01: Zero-Hardcode AST CAS Engine, Integral Root-Splitting & Dead Code Cleanup

## Objective
Eliminate all ~970 lines of dead/orphaned code and replace hardcoded math assumptions (`type: 'cas_function'`, regex asymptotes, un-simplified quotient derivatives, inaccurate Simpson integration on $|f(x)|$, and hardcoded `x^3 - 3*x` store boot) with a clean, single-AST mathematical pipeline.

## Files to Delete
1. `plugins/math_studio/ui/core/expression_parser.js`
2. `plugins/math_studio/ui/core/curve_manipulator.js`
3. `plugins/math_studio/ui/render/graph_plotter.js`
4. `plugins/math_studio/ui/render/revolution_solid_plotter.js`
5. `plugins/math_studio/ui/sdk.js`

## Files to Modify
1. `plugins/math_studio/ui/core/symbolic_cas.js`
   - **Fix Critical Product Rule Bug (`symbolic_cas.js:224`)**: Fix `left: { type: 'op', op: '*', left: uPrime, right: left }` ($u' \cdot u$) $\to$ `left: { type: 'op', op: '*', left: uPrime, right }` ($u' \cdot v$).
   - **Add Missing Elementary Derivatives**: Support `cot(u)` $\to -\frac{u'}{\sin^2(u)}$, `abs(u)`, and `log(u)` in `differentiateAST`.
   - **Compile AST Directly to Evaluator (`compileAST(ast)`)**: Avoid JavaScript `new Function` `-x**2` SyntaxError when evaluating unary minus before exponentiation (`-x^2`, `-x^3 + 3x`, `-x^4 + 2x^2`), and fix `cot(x)` missing closing parenthesis in `normalizeExpression`.
   - Add polynomial coefficient extractor (`extractPolynomialCoeffs(ast)`) and rational classifier (`classifyFunctionAST(ast)`):
     - Identifies `linear` ($ax+b$), `quadratic` ($ax^2+bx+c$), `cubic` ($ax^3+bx^2+cx+d$), `quartic` ($ax^4+bx^2+c$ or general degree 4), `rational_1_1` ($\frac{ax+b}{cx+d}$), `rational_2_1` ($\frac{ax^2+bx+c}{dx+e}$), or `general`.
   - Upgrade `computeSymbolicDerivative(rawExpr)` to simplify polynomial and rational derivatives algebraically:
     - For $\frac{ax+b}{cx+d}$, compute exact numerator $ad - bc$ so $\left(\frac{2x+1}{x-1}\right)' = \frac{-3}{(x-1)^2}$.
     - For $\frac{ax^2+bx+c}{dx+e}$, simplify numerator to $adx^2 + 2aex + (be - cd)$.
   - Add `formatAcademicMathHtml(exprStr)` and `formatDerivativeHtml(derInfo)` to render clean textbook HTML (`.math-frac` stacked fractions, `<sup>` exponents, `√` radicals, italic math variable `<var>x</var>`, mathematical minus `−`, and stripped `*`).
2. `plugins/math_studio/ui/core/math_cas.js`
   - Remove duplicate `calculateDefiniteIntegral`.
   - Fix `normalizeExpression` for unary minus before power (`-x^2` $\to$ `-(x**2)`) and `cot(...)` (`(1/Math.tan(...))`), or evaluate via AST compiler.
   - Use `classifyFunctionAST` to populate `analysis.type`, `analysis.familyLabel`, and `analysis.coeffs`.
   - Replace fragile regex asymptote check with general AST denominator analysis + numerical pole verification:
     - Find all roots of denominator $Q(x) = 0$ on $[xMin - 4, xMax + 4]$ where $|P(x)| > 10^{-5}$ to detect all vertical asymptotes (`TCĐ`), and compute exact one-sided limits `leftLimit` and `rightLimit` (`+∞` / `−∞`) at each pole $x_0^\mp$.
     - Evaluate $a = \lim_{x \to \pm\infty} \frac{f(x)}{x}$ and $b = \lim_{x \to \pm\infty} (f(x) - ax)$ to detect both horizontal (`TCN`, $a = 0$) and oblique (`TCX`, $a \ne 0$) asymptotes, and populate `analysis.limits = { left, right }` so BBT shows exact horizontal asymptote limits (e.g., `2` instead of `±∞` for $y = \frac{2x-1}{x+1}$).
   - Add `computeAutoFitBounds(extrema, intercepts, asymptotes)` returning clean SGK viewport bounds and optimal `tickSteps`.
3. `plugins/math_studio/ui/core/integral_solver.js`
   - Split $[a, b]$ at all roots of $f(x) = 0$ inside $(a, b)$ using `findRoots(f, a, b, 0.02)` before integrating $|f(x)|$ on each smooth sub-interval via high-precision Adaptive Simpson.
   - Add rational fraction recovery (`toFractionBadge(val)`) so values like `-0.75`, `3.75`, `5.25`, `1.333333` display both exact decimal and fraction (`-3/4`, `15/4`, `21/4`, `4/3`).
   - Return structured non-throwing result `{ valid, warning, a, b, signedIntegral, area, displayIntegral, displayArea, fractionIntegral, fractionArea, antiderivativeHtml }` so $a \ge b$ never crashes `store.recomputeAnalysis`.
4. `plugins/math_studio/ui/core/store.js`
   - Remove import of `curve_manipulator.js` and `UPDATE_DRAG_EXTREMUM`.
   - Parse `window.location.search` (`editId`, `formula`, `view`, `a`, `b`, `preset`, `problem`, `color`) before running initial analysis so sticker editing loads the target formula directly.
   - Add `curveColor` (`'#1D4ED8'` default), `geom3dPreset: 'pyramid_quad'`, `geom3dProblemText: ''`, and `REMOVE_MARKED_POINT` / `CLEAR_MARKED_POINTS` actions.

## Verification
- Unit/node check that `analyzeFunction('x^3 - 3*x')`, `analyzeFunction('(2x+1)/(x-1)')`, `analyzeFunction('1/x')`, and `solveIntegral` produce exact types, asymptotes, derivatives, and integral values (`-0.75` / `3.75` and `0.75` / `5.25`).

