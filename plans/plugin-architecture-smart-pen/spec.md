# Spec: Align plugin architecture and migrate Smart Pen to a plugin

**Date:** 2026-10-20  
**Status:** Draft

## Problem Statement

The plugin system accepts legacy manifests and currently misses several declared v2.1 invariants at runtime and in CI. Smart Pen's PDF recognition and answer-marking behavior is implemented in the Flutter core, so it cannot be installed, updated, or removed independently like other plugins.

## User Stories

- **[P1]** As a teacher, I want Smart Pen installed and activated as a regular plugin so its PDF answer detection is available through the plugin marketplace and tool palette.
  Accepted when: Smart Pen has a standalone manifest and `.hlep`, uses only the Host Bridge SDK, and no Smart Pen algorithm or plugin ID remains hardcoded in `frontend/lib/`.
- **[P1]** As a teacher, I want existing PDF answer recognition, linked-page grouping, answer-circle toggling, persistence, and undo/redo to continue working after migration.
  Accepted when: plugin-specific automated tests cover each behavior and lesson save/reload retains persisted answer annotations.
- **[P1]** As a plugin author, I want manifests, sidecars, and UI messaging to follow one enforced v2.1 contract.
  Accepted when: the validator rejects legacy/invalid manifests, fixed sidecar ports, and direct WebView messaging outside the SDK; the current plugin packages pass.
- **[P1]** As a teacher, I want sidecar startup failures reported as failures and plugin preferences stored persistently with permission checks.
  Accepted when: an unhealthy or prematurely exited sidecar is not registered as running, and storage is denied without permission and survives app restart when granted.
- **[P1]** As a maintainer, I want CI to exercise plugin contracts on pull requests.
  Accepted when: changes to plugin tooling/docs trigger plugin checks, PRs run a Windows build, and plugin UI/engine tests run in CI.

## Functional Requirements

1. Define and enforce the canonical Schema v2.1 manifest shape while retaining an explicit, testable migration path for existing packages.
2. Remove static port defaults from English Assistant; Host allocated ports must be the only runtime source and health responses must report actual runtime state.
3. Make English Assistant communicate only through `window.HocLuc`; package sidecar dependencies and fail non-zero when required dependencies are missing.
4. Make the Host reject unhealthy sidecars and stop them instead of registering them as running.
5. Add a generic Host Bridge API for PDF text fragments, PDF pointer taps, and grouped annotations. The API must not contain Smart Pen IDs or behavior.
6. Move Smart Pen classification, candidate grouping, and activation UI into `plugins/smart_pen/`; preserve saved annotations and user workflows through generic host annotation APIs.
7. Persist plugin storage on disk and enforce the `storage` permission for every storage RPC.
8. Strengthen validator and CI to check schema, package content integrity, fixed ports, direct bridge calls, sidecar health/dependencies, and plugin-specific tests.

## Non-Functional Requirements

- Security: sidecars bind to loopback and require a Host assigned port; plugin RPC actions enforce declared permissions.
- Compatibility: existing saved PDF annotations load without losing strokes or answer labels.
- Performance: PDF text indexing remains incremental and must not block normal PDF navigation or drawing.

## Success Criteria

- [ ] All shipped manifests use the documented v2.1 schema and the validator rejects legacy shapes.
- [ ] No fixed port literal or raw WebView bridge call remains in plugin application code; SDK implementation is the only allowed bridge call site.
- [ ] Smart Pen operates from its `.hlep` package; `frontend/lib/` contains no Smart Pen-specific names or algorithm branches.
- [ ] Existing Smart Pen behavior and persisted PDF annotations are covered by passing plugin/bridge tests.
- [ ] A sidecar that fails health checks is reported as not running and is terminated.
- [ ] Plugin storage permission is enforced and stored values survive a process restart.
- [ ] Plugin validation, architecture tests, Flutter analysis/tests, plugin JS/Python tests, and Windows PR build pass.

## Out of Scope

- Redesigning plugin marketplace UX or changing unrelated classroom workflows.
- Rewriting the existing plugin catalog beyond bringing the two shipped plugins to the canonical contract.

## Assumptions

- Smart Pen means the existing PDF answer recognition, linked answer groups, circles, and save/undo behavior in `studio_board`.
- `plugins/smart_pen/` is the standalone source directory and `plugins/smart_pen.hlep` is its distributable package.
- Legacy saved lesson JSON must remain readable during the migration.

## [NEEDS CLARIFICATION]

- [ ] None; proceed with the behavior already present in the core as the compatibility target.
