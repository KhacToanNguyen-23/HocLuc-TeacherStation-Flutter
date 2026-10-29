# Phase 03: Host Pre-warming & Verification Gates

**Goal:** Eliminate cold startup delay and the spinning loader when reopening Math Studio by caching/pre-warming the WebView instance in the Flutter Host, followed by 100% CI gate verification.

**Target Files:**
- [`frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/features/plugin_engine/presentation/floating_plugin_window.dart)
- [`frontend/lib/features/plugin_engine/presentation/flat_host_native.dart`](file:///d:/Project/FptProject/HocLuc-TeacherStation-Flutter/frontend/lib/features/plugin_engine/presentation/flat_host_native.dart)
- Packaging and validation scripts

---

## Detailed Tasks

1. **Host Warm Keep-Alive in `floating_plugin_window.dart`**:
   - Maintain a retained reference or offstage keep-alive for the active plugin's `FlatHost` when closed via the modal `✕` button or Pin action.
   - When the user taps the tool again (`open_math_studio`), reuse the existing warm WebView2 instance without triggering a cold navigation loop.

2. **Suppress Redundant Navigation in `flat_host_native.dart`**:
   - Ensure minor query parameter changes or visibility toggles do not reset `ready = false` and cause a spurious `CircularProgressIndicator` flash.

3. **Package & Validate Math Studio Plugin**:
   - Run `node scripts/package_plugin.mjs math_studio`.
   - Run `node scripts/validate_plugins.mjs`.

4. **CI & Architecture Invariant Verification**:
   - Run `flutter test test/architecture_test.dart` (ensure 12/12 passing).
   - Run `flutter analyze --no-fatal-infos` (ensure 0 issues).

---

## Acceptance Criteria
- [ ] Warm modal launch time $< 100\text{ms}$ with 0 visible loading spinner.
- [ ] `node scripts/validate_plugins.mjs` passes 100% with 0 errors.
- [ ] `flutter test test/architecture_test.dart` passes 12/12 invariants.
- [ ] `flutter analyze --no-fatal-infos` outputs "No issues found!".

