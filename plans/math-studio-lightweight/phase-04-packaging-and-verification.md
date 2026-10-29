# Phase 4: Production Packaging & Verification

## Objective
Bundle the ultra-lightweight plugin, purge unused dependencies, package into `.hlep`, and verify all CI architecture invariants.

## Implementation Details
1. Pruning dependencies:
   - Remove `mathjs`, `nerdamer`, `@excalidraw/excalidraw` from `package.json`.
   - Ensure bundle output is < 100 KB.
2. Build script:
   - `build.mjs`: bundle `main.jsx` into `ui/dist/app.js`.
3. Packaging:
   - Package via `node scripts/package_plugin.mjs math_studio`.
   - Verify archive size is < 200 KB.
4. Verification:
   - Plugin validator: `node scripts/validate_plugins.mjs` (0 errors).
   - Architecture test: `flutter test test/architecture_test.dart` (12/12 passing).

## Acceptance Criteria
- Bundle size < 100 KB.
- Plugin validator passes with 0 errors.
- 100% adherence to AGENTS.md rules.

