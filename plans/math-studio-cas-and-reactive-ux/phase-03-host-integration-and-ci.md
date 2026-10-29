# Phase 03: One-Click Chalk Pinning, Auto-Close & Full CI Gate Verification

## Objective
Harmonize the plugin manifest with the new 820px × 540px footprint, verify the host bridge RPC for one-click pin & dismiss, repackage `math_studio.hlep`, and run the mandatory verification gates.

## Files to Modify
1. `plugins/math_studio/manifest.json`:
   - Set `"default_width": 820`, `"default_height": 540`.
   - Ensure `"inject_sdk": true`.
2. `frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart`:
   - Verify integer pixel snapping on dialog dimensions: `dialogW = 820.0`, `dialogH = 540.0`.
   - Ensure modal center coordinates keep ample chalkboard margin visible (> 200px on all sides).
3. Packaging & CI:
   - Run `node scripts/package_plugin.mjs math_studio`.
   - Run `node scripts/validate_plugins.mjs`.
   - Run `flutter test test/architecture_test.dart`.
   - Run `flutter analyze --no-fatal-infos`.

## Verification
- `node scripts/validate_plugins.mjs` passes 100% with 0 errors.
- `flutter test test/architecture_test.dart` passes 12/12 invariants.
- `flutter analyze --no-fatal-infos` outputs "No issues found!".

