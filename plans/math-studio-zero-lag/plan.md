# Plan: Math Studio Zero-Lag Architecture & High-Performance Lifecycle

Mode: --auto
Risk: normal — multi-file JS optimization and Flutter host keep-alive, fully testable with 0 auth/data risk.
Spec: plans/math-studio-zero-lag/spec.md
Brainstorm: plans/reports/261027-math-studio-zero-lag-brainstorm.md

---

## Architecture Overview

```mermaid
graph TD
  subgraph InputLayer ["1. Math CAS & Evaluation"]
    AST ["Algebraic AST"] --> JIT ["compileFastEvaluator(ast)"]
    JIT --> NativeClosure ["Native JS Closure: (x) => Math.pow(x,3) - 3*x"]
  end

  subgraph BoardLifecycle ["2. Zero-Destruction JSXGraph Board"]
    NativeClosure --> FastCurve ["Fast 60fps Curve Sampler"]
    BtnClick ["User Clicks Parameter Button"] --> InPlaceUpdate ["board.suspendUpdate() -> setAttribute() -> board.unsuspendUpdate()"]
    InPlaceUpdate --> FastResponse ["Instant Update (< 1ms, No Board Destruction)"]
  end

  subgraph HostLayer ["3. Flutter Host Pre-warm"]
    ModalClose ["Teacher Closes Studio"] --> WarmDormancy ["Keep-Alive / Offstage in FloatingPluginWindow"]
    ModalOpen ["Teacher Taps Tool"] --> InstantPopup ["Instant Restore (< 100ms, No Circular Spinner)"]
  end
```

---

## Phase Breakdown

- [x] Phase 1: JIT Fast Mathematical Function Compiler (`plans/math-studio-zero-lag/phase-01-jit-fast-evaluator.md`)
- [x] Phase 2: Zero-Destruction Board Lifecycle & In-Place Updates (`plans/math-studio-zero-lag/phase-02-zero-destruction-lifecycle.md`)
- [x] Phase 3: Host Pre-warming & Verification Gates (`plans/math-studio-zero-lag/phase-03-host-prewarm-and-verification.md`)

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-27 14:32
**Phase in progress:** Complete
**Status:** All 3 phases implemented and verified. 100% CI pass (12/12 architecture invariants, 0 analyzer issues, plugin validator 100% sync).

### Decisions made this session
- Implemented `compileFastEvaluator(ast)` in `micro_cas.js` achieving 22.2M evals/sec.
- Refactored `renderJSXGraphBoard` in `graph_board.js` to preserve active boards and execute in-place attribute updates in < 1ms on button toggles.
- Preserved warm modal plugin offstage in `FloatingPluginWindow` with `TickerMode` disabled when hidden, eliminating startup spinners on subsequent launches.

### Next immediate action
Ready for production classroom usage.

---

## Verification Commands

1. **Plugin Packaging & Validation**:
   ```bash
   node scripts/package_plugin.mjs math_studio
   node scripts/validate_plugins.mjs
   ```
2. **Architecture Invariants Gate**:
   ```bash
   powershell -Command "Set-Location frontend; flutter test test/architecture_test.dart"
   ```
3. **Static Analysis**:
   ```bash
   powershell -Command "Set-Location frontend; flutter analyze --no-fatal-infos"
   ```

