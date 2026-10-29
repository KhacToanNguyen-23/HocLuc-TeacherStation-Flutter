# Implementation Plan: Zero-Hardcode Micro-CAS & Non-Intrusive Reactive Live Math Studio

```
Directory: plans/math-studio-cas-and-reactive-ux/
Spec:      plans/math-studio-cas-and-reactive-ux/spec.md
Mode:      hard (comprehensive core CAS refactor + reactive floating studio UX)
Risk:      normal — multi-file JS core refactor and CSS layout restructure, testable, no auth/data/infra risk
Test:      default + architecture/validator gates
Tasks:     default
```

---

## Scope Challenge & Spec Quality Check

```
# Scope Challenge:
#   Exists?     → Yes, `plugins/math_studio` exists but contains a 1030-line `symbolic_cas.js` with hardcoded type branches and a bulky 2-column accordion UI.
#   Minimum?    → 3 focused phases: (1) Zero-hardcode Micro-CAS (~200 LOC), (2) Non-intrusive floating studio window (820x540px) with reactive live plotting, (3) One-click chalk pinning & CI verification.
#   Complexity? → Hard (engine rewrite + reactive UI + host bridge integration).
#
# Spec Quality Check:
#   [NEEDS CLARIFICATION] remaining? → 0 remaining (all resolved in brainstorm)
#   Success criteria measurable?     → PASS (Code size <= 250 LOC, 0 hardcoded strings, <= 16ms draw latency, modal 820x540px)
#   User stories P1/P2/P3?           → PASS
#   Acceptance criteria testable?    → PASS
#   Verdict: PASS
```

---

## Research Synthesis

- **Researcher A (Primary — Pure Calculus Micro-CAS + In-Canvas Floating Formula Island)**:
  - **Approach**: Replace `symbolic_cas.js` (>1030 LOC) with a concise `micro_cas.js` (~220 LOC). Implement a single recursive-descent parser, universal AST differentiator (chain rule), and calculate all horizontal/oblique asymptotes using the analytical limit definition $a = \lim_{x \to \pm\infty} \frac{f(x)}{x}$ and $b = \lim_{x \to \pm\infty} [f(x) - ax]$. Remove all `'cubic'`, `'quartic'`, `'rational1'`, `'rational21'` strings. In UI, remove the rigid left sidebar completely; make the canvas 100% of the $820\text{px} \times 540\text{px}$ modal and float an acrylic glass formula bar at the top with live debounced typing ($80\text{ms}$).
  - **Verdict**: **Recommended** — solves both user requirements (eliminates code smell + enables live reactive plotting without occluding the blackboard).
- **Researcher B (Alternative — Heavy External Library + Dock Panel)**:
  - **Approach**: Import `nerdamer` (~70KB) or `mathjs` (~700KB) and dock the tool into a 400px side panel.
  - **Verdict**: **Rejected** — user explicitly stated "hướng nào chuẩn chuyên nghiệp mà nhẹ máy user" and "không che hết bảng viết". External libraries waste memory on low-spec teacher laptops, and side docking restricts graph aspect ratio.

---

## Phase Overview

| Phase | File | Summary | Stories Covered |
| :---: | :--- | :--- | :--- |
| **01** | [`phase-01-micro-cas-engine.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-cas-and-reactive-ux/phase-01-micro-cas-engine.md) | Replace 1030-line `symbolic_cas.js` with pure zero-hardcode `micro_cas.js` (<240 LOC). Implement universal limit asymptotes ($a = \lim f(x)/x, b = \lim [f(x) - ax]$) and adaptive domain extrema. | Story 1 (P1), Story 4 (P2) |
| **02** | [`phase-02-reactive-live-ui.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-cas-and-reactive-ux/phase-02-reactive-live-ui.md) | Rebuild `index.html` and `style.css` to an 820px × 540px non-intrusive floating canvas with a top-center Floating Formula Island. Implement zero-latency (<16ms) reactive live curve morphing. | Story 2 (P1), Story 3 (P1) |
| **03** | [`phase-03-host-integration-and-ci.md`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/plans/math-studio-cas-and-reactive-ux/phase-03-host-integration-and-ci.md) | Connect one-click "Ghim vào bảng" with auto-close via `HocLuc.close()`, repackage `math_studio.hlep`, and pass all verification gates. | Story 3 (P1), All Acceptance Criteria |

---

## Red-Team Review & Risk Adjudication

1. **[ACCEPTED] Risk: Non-polynomial rational functions or oscillatory functions (e.g. $\sin x$) when calculating $\lim_{x \to \infty} f(x)/x$.**
   - *Mitigation*: Test convergence at two sample points $x = 10^5$ and $x = 10^6$. If difference exceeds $0.05$, classify as having no horizontal/oblique asymptote gracefully without throwing errors.
2. **[ACCEPTED] Risk: Removing `classifyFunctionAST` could break existing calls in `bbt_generator.js` or `app.js`.**
   - *Mitigation*: `micro_cas.js` provides a uniform `tableData` interface (`points`, `intervals`, `limits`) so `bbt_generator.js` and `graph_board.js` consume the exact same data structure without caring about function family names.
3. **[ACCEPTED] Risk: Floating window dimensions in Flutter host.**
   - *Mitigation*: Set `"default_width": 820` and `"default_height": 540` in `manifest.json` and ensure `FloatingPluginWindow` centers it cleanly on the chalkboard.

---

## Checklist
- [x] Phase 01: Zero-Hardcode Micro-CAS Engine (< 240 LOC) & Universal Limit Asymptotes
- [x] Phase 02: Non-Intrusive Floating Studio Window (820x540px) & Reactive Live Plotting Bar
- [x] Phase 03: One-Click Chalk Pinning, Auto-Close & Full CI Gate Verification

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-10-27 13:29
**Phase in progress:** completed
**Status:** All 3 phases completed successfully. Full verification gates passed (12/12 architecture invariants, 0 analyze issues, 100% plugin sync).

