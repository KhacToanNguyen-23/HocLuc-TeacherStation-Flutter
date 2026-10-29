# Phase 1: Zero-Dependency Dynamic Math Evaluator

## Objective
Implement a lightweight, generic, zero-dependency mathematical expression evaluator that compiles user math strings into safe, high-speed JavaScript numeric functions.

## Implementation Details
1. File: `plugins/math_studio/src/engine/evaluator.js`
   - Transform user math syntax into safe JavaScript math expressions:
     - Powers: `x^2` $\to$ `Math.pow(x, 2)`, `x^n` $\to$ `Math.pow(x, n)`
     - Implicit multiplication: `2x` $\to$ `2*x`, `3(x+1)` $\to$ `3*(x+1)`, `x(x-1)` $\to$ `x*(x-1)`
     - Mathematical constants: `pi` $\to$ `Math.PI`, `e` $\to$ `Math.E`
     - Built-in math functions: `sin`, `cos`, `tan`, `sqrt`, `abs`, `exp`, `ln` $\to$ `Math.log`
   - Compile into native closure `(x) => ...` wrapped in safety checks (`Number.isFinite(v) ? v : null`).
2. Unit Tests:
   - File: `plugins/math_studio/engine/tests/evaluator.test.mjs`
   - Test benchmark functions:
     - $2x^2 - 3x + 1$
     - $x^3 - 3x$
     - $(2x+1)/(x-1)$
     - $\sin(x)$
     - $\sqrt{4-x^2}$
     - $e^{-x^2}$
     - $\ln(x)$

## Acceptance Criteria
- 100% dynamic (0 hardcoded formulas).
- 0 external dependencies (0 KB from mathjs or nerdamer).
- Evaluates $> 1,000,000$ points/sec.

