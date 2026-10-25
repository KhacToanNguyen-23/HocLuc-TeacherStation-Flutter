# Plan: Plugin architecture hardening and Smart Pen migration

**Date:** 2026-10-20  
**Mode:** Standard; inline plan because repository instructions disallow subagent delegation in this session.  
**Risk:** high-risk — multi-component plugin runtime, persisted annotation format, CI, and package contract changes.  
**Status:** In progress

## Scope Challenge

- Exists? Smart Pen recognition exists in core; plugin runtime, SDK, manifests, and CI already exist but accept legacy behavior.
- Minimum? Fix the prioritized runtime violations, define a generic PDF plugin bridge, then migrate Smart Pen end-to-end and package it.
- Complexity? High-risk, split into verifiable phases.

## Phases

- [x] Phase 1: Canonical manifests and safe sidecar lifecycle
- [x] Phase 2: SDK-only English Assistant, dynamic ports, dependency contract
- [x] Phase 3: Generic PDF interaction and grouped annotation Host Bridge APIs (Host stores plugin-supplied closed paths, scopes groups by owner, and handles persistence, temporary overrides, rekey, undo/redo without generating shapes or delegating to Smart Pen)
- [ ] Phase 4: Smart Pen standalone plugin and removal of core-specific behavior (plugin owns detection, linking, hit testing, ellipse geometry and UI; legacy core classifier/fallback and compatibility APIs still need removal)
- [x] Phase 5: Persistent permission-gated plugin storage
- [ ] Phase 6: Validator, plugin tests, CI path/build gates, package verification (validator 3/3, Node 7/7, Flutter targeted tests including architecture 12/12 pass; full analyzer is clean and Windows build succeeded; repeat final gates after legacy classifier removal)

## Verification

- `node scripts/validate_plugins.mjs`
- `flutter test test/architecture_test.dart`
- `flutter analyze --no-fatal-infos`
- Flutter plugin/bridge/widget tests under `frontend/test/features/plugin_engine/` and `frontend/test/features/studio_board/`
- Node tests for Smart Pen plugin logic; Python sidecar tests if a sidecar remains part of the design
- `flutter build windows --debug`
- Confirm every `.hlep` archive exactly matches its source directory.

## Risks

- Existing saved lesson JSON uses Smart Pen-specific stroke metadata; migration must preserve rendering and undo semantics.
- PDF text extraction is currently coupled to `pdfrx` in `PdfStage`; the Host Bridge must expose generic text geometry without putting plugin-specific classification back in core.
- Concurrent plugin WebViews need isolated storage and sidecar ports.
- The current branch contains unrelated modified files; changes must stay scoped to this task.

## Current State

Smart Pen is packaged as `.hlep`; its JavaScript owns marker classification, adjacent-page linking, hit testing, ellipse points and tool UI. Generic Host APIs deliver PDF text/taps and store plugin-provided normalized closed paths. BoardStroke now serializes owner/group/item metadata while retaining legacy saved-stroke decoding. Shared annotation storage, rendering, export, temporary overrides, undo/redo and group rekey use generic metadata. The plugin serializes indexing/tap events, retains raw page results and rekeys provisional groups before publishing linked results. Core still contains the former classifier/fallback and legacy compatibility APIs; those remain the ownership gap for Phase 4.

## Session Notes

**Last active:** 2026-10-20
**Phase in progress:** Phase 4 — Remove legacy core classification
**Status:** Generic annotation path implemented and reviewed; cross-page rekey undo now rebases both merge directions and redo history. Targeted suites passed (83 before latest history correction; 78 for architecture/HostBridge/generic+legacy annotation regressions after it). Node 7/7 and plugin validator 3/3 pass. Full frontend analyzer reports no issues. Current-state Windows debug build passed in 69.4 seconds, producing `frontend/build/windows/x64/runner/Debug/teaching_companion.exe`.

### Decisions made this session

- Store arbitrary plugin-supplied closed paths with generic owner/group/item metadata; preserve legacy fields only for saved lesson compatibility.
- Plugin owns geometry/style. Host validates 3–512 normalized points, ARGB color and width, and namespaces group IDs.
- Generic group migration rebases applied and redo history in user action order, including temporary overrides. Legacy caller compatibility remains isolated.
- Fall back to ordinary PDF ink when a queued plugin tap times out or the plugin tool is disabled.
- Reject region results from a different PDF content generation.

### Next immediate action

Remove legacy Smart Pen classifier/fallback from PdfStage and move generic PDF extraction/scheduling into a subject-neutral Host service. Migrate the old gesture/index tests to real plugin behavior coverage and verify old saved annotations through the new plugin path. Then audit the full spec and rerun final gates.
