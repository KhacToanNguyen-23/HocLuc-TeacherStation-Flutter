# Phase 01: JIT Fast Mathematical Function Compiler

**Goal:** Eliminate tree-walking AST evaluation from the 60 FPS curve sampling loop by compiling mathematical expressions directly into native V8 JIT-optimized JavaScript closures.

**Target Files:**
- [`plugins/math_studio/ui/core/micro_cas.js`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/core/micro_cas.js)
- [`plugins/math_studio/ui/core/math_cas.js`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plugins/math_studio/ui/core/math_cas.js)

---

## Detailed Tasks

1. **Implement `astToJsExpression(ast)` in `micro_cas.js`**:
   - Recursively serialize AST nodes into safe native JS arithmetic strings:
     - `NUM`: format numeric literal.
     - `VAR`: `'x'`.
     - `BINOP`:
       - `+`, `-`, `*`, `/`: `(left op right)`.
       - `^`: `Math.pow(left, right)`.
     - `UNARY`: `-`, `+`: `(-operand)`.
     - `CALL`:
       - `sin`, `cos`, `tan`, `sqrt`, `exp`, `abs` $\to$ `Math.<fn>(arg)`.
       - `cot` $\to$ `(1 / Math.tan(arg))`.
       - `ln`, `log` $\to$ `Math.log(arg)`.
       - `asin`, `acos`, `atan` $\to$ `Math.<fn>(arg)`.

2. **Implement `compileFastEvaluator(ast)` in `micro_cas.js`**:
   - Construct native function: `new Function('x', '"use strict"; try { const v = (' + jsExpr + '); return Number.isFinite(v) ? v : NaN; } catch (_) { return NaN; }')`.
   - Pre-validate with test inputs ($x = 0, 1, -1$) to verify sanity.
   - If validation passes, return this closure. If invalid or unknown symbol, fall back safely to `(x) => evaluateAST(ast, x)`.

3. **Wire JIT Fast Evaluator into `math_cas.js`**:
   - In `compileFunction(rawExpr)`: compile AST using `compileFastEvaluator(ast)`.
   - In `analyzeFunction(expr, bounds)`:
     - Set `analysis.eval = compileFastEvaluator(ast)`.
     - Set `analysis.derEval = compileFastEvaluator(dAst)`.

---

## Acceptance Criteria
- [ ] Throughput of `analysis.eval(x)` exceeds $1,000,000$ evaluations/second.
- [ ] Curve sampling during mouse dragging runs with zero AST tree traversal.
- [ ] Handles division by zero and logarithmic poles without uncaught exceptions (returns `NaN`).

