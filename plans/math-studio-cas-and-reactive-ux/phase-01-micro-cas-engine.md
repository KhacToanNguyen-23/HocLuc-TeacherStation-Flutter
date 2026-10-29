# Phase 01: Zero-Hardcode Micro-CAS Engine (< 240 LOC) & Universal Limit Asymptotes

## Objective
Replace the monolithic, hardcoded 1030-line `symbolic_cas.js` and its brittle classification branches with a unified, lightweight, zero-dependency `micro_cas.js` (< 240 LOC). Eliminate all family strings (`cubic`, `quartic`, `rational1`, `rational21`) and implement universal mathematical limits for asymptotes and adaptive interval search.

## Files to Modify / Create
1. Create `plugins/math_studio/ui/core/micro_cas.js` (or replace `symbolic_cas.js`):
   - **Lexer & Recursive Descent AST Parser (~70 LOC)**:
     - Parses numbers, identifiers, variables ($x$), basic operators ($+, -, *, /, \wedge$, unary $-$), and elementary math functions ($\sin, \cos, \tan, \cot, \exp, \ln, \log, \sqrt{\cdot}, |\cdot|$).
     - Implicit multiplication handling ($2x \to 2*x$, $x(x+1) \to x*(x+1)$).
   - **Universal AST Differentiator (~60 LOC)**:
     - Direct chain rule: $\frac{d}{dx}[u \pm v] = u' \pm v'$, $\frac{d}{dx}[u \cdot v] = u'v + uv'$, $\frac{d}{dx}[u / v] = \frac{u'v - uv'}{v^2}$, $\frac{d}{dx}[u^n] = n u^{n-1} u'$, $\frac{d}{dx}[e^u] = u' e^u$, $\frac{d}{dx}[\ln u] = \frac{u'}{u}$, $\frac{d}{dx}[\sin u] = u' \cos u$, $\frac{d}{dx}[\cos u] = -u' \sin u$, $\frac{d}{dx}[\tan u] = \frac{u'}{\cos^2 u}$, $\frac{d}{dx}[\sqrt{u}] = \frac{u'}{2\sqrt{u}}$.
   - **Pure Limit & Asymptote Solver (~50 LOC)**:
     - Universal Horizontal & Oblique Asymptotes via the calculus definition:
       $$a = \lim_{x \to \pm\infty} \frac{f(x)}{x}, \quad b = \lim_{x \to \pm\infty} [f(x) - a \cdot x]$$
       Computed via two-point numerical Richardson extrapolation ($x = 10^5, 10^6$).
       - If $a = 0$ and $b$ is finite: Horizontal asymptote $y = b$.
       - If $a \neq 0$ and $b$ is finite: Oblique asymptote $y = ax + b$.
     - Vertical Asymptotes (Poles): Scan division denominator subnodes and non-differentiable singularity points; verify $|f(x_0 \pm \varepsilon)| > 20$.
   - **Adaptive Interval Critical Point Scanner (~50 LOC)**:
     - Scans $f'(x) = 0$ using hybrid bisection + Newton-Raphson.
     - Automatically expands domain dynamically if roots approach the search boundaries.
2. Update `plugins/math_studio/ui/core/math_cas.js`:
   - Import parser, differentiator, and limit solver from `micro_cas.js`.
   - Re-export `analyzeFunction(exprStr)` conforming to the uniform API.
   - Delete all hardcoded references to `cls.type === 'rational1'`, `rational21`, and static `[-9, 9]` bounds.

## Verification
- Test with diverse mathematical functions:
  1. $y = x^3 - 3x$ $\to$ 2 extrema, no asymptotes.
  2. $y = \frac{2x + 1}{x - 1}$ $\to$ TCN $y = 2$, TCĐ $x = 1$.
  3. $y = \frac{x^2 - x + 1}{x - 1}$ $\to$ TCX $y = x$, TCĐ $x = 1$.
  4. $y = \sqrt{x^2 + 1}$ $\to$ TCX $y = x$ ($x \to +\infty$) and $y = -x$ ($x \to -\infty$).
  5. $y = \sin x$ $\to$ bounded oscillating extrema, no asymptotes.
- Run `node scripts/validate_plugins.mjs`.

