# Agent Guidelines & Repository Architecture Invariants

> **Notice to all AI Coding Agents (Antigravity, Cursor, Windsurf, Claude Code, Copilot):**  
> This file defines the mandatory engineering practices, architecture boundaries, and hard prohibitions for this repository. You MUST adhere to these rules without exception.

---

## 1. Project Overview & Boundaries

- **`frontend/`**: Flutter Desktop & Web application for Teachers (Teacher Station).
- **`backend/api/`**: Spring Boot backend services.
- **`plugins/`**: Isolated subject-specific extension packages (`.hlep` format / independent folders).
- **`docs/`**: Official architectural & domain documentation.

---

## 2. Hard Invariants for Plugin Development (BẮT BUỘC — Schema v2.1)

When working on any plugin or extending the Teacher Station plugin system:

1. **Zero Hardcoded Names**: NEVER hardcode plugin IDs (e.g., `'english_assistant'`, `'com.hocluc.plugin.english'`, `'casio_calculator'`) or specific subject names inside `frontend/lib/`. The Core Flutter App is a pure Microkernel Host.
2. **No Direct Plugin Imports**: NEVER import files across `frontend/lib/` and `plugins/`. All interactions must go through abstract interfaces and the Host Bridge.
3. **Dynamic Port Allocation**: NEVER hardcode port numbers (e.g., `18888`). Sidecar engines (Python/Binary) must accept dynamic ports passed via the `--port <port>` CLI argument or `HOCLUC_PLUGIN_PORT` environment variable.
4. **On-Demand Memory / Disk Cache**: NEVER unpack raw file bytes into RAM (`filesMap` in memory). Plugins downloaded from the Cloud Marketplace must be extracted to `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/` and loaded on demand (Lazy Loading).
5. **Enforce SDK Bridge & Auto-Injection**: Webview UI must NEVER call `window.chrome.webview.postMessage` directly with arbitrary payloads. All UI communication MUST use `hocluc-plugin-sdk.js` (`window.HocLuc`) or set `"inject_sdk": true` in `manifest.json` so `PluginWebServer` auto-injects the SDK.
6. **Declarative Manifest Schema v2.1**:
   - **In-Board Tool Contributions**: Declare board tools in `manifest.json` under `contributes.tools` (`snip_region`, `toggle_tool`, `quick_input`) — NEVER hardcode tool buttons in `SubjectToolPalette`.
   - **Frameless Bare-Device Mode**: For physical device simulators (e.g., calculators, rulers), set `"placement": "floating_window"`, `"frameless": true`, `"resizable": false`, and exact `default_width` / `default_height` in `manifest.json`.
   - **Packaging**: Always package modified plugins into `.hlep` via `node scripts/package_plugin.mjs <plugin_folder>` so Backend Marketplace (`GET /api/marketplace/plugins`) serves the updated archive.
7. **Detailed Developer Reference**: Always refer to [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md) and [`.agents/rules/plugin_development_rules.md`](.agents/rules/plugin_development_rules.md) for full manifest schema and copy-paste templates.

---

## 3. Hard Invariants for Frontend Clean Architecture (Feature-First)

1. **Zero Loose Files in Services / Widgets**: NEVER create files directly inside `lib/services/` or `lib/widgets/`. Code must reside in `lib/core/<layer>/` (for cross-cutting utilities/theme) or `lib/features/<module>/{services,presentation}/`.
2. **Hierarchical Test Structure**: NEVER place test files flat at the root of `frontend/test/`. Only `architecture_test.dart` is permitted at root. All other tests must reside in `test/features/<module>/` or `test/e2e_browser/`.
3. **No Ghost Dependencies**: All `path:` dependencies in `frontend/pubspec.yaml` must point to existing directories on disk.

---

## 4. Git Commit Rules

- **Only commit source code**: NEVER commit environment configs, personal setup scripts (such as `setup_flutter.ps1`), secrets, or `.env` files.
- All downloaded SDKs (e.g. `.sdk/`) must remain ignored.
- **Git Hooks Enforced**: Git hooks are configured in `.githooks/` (`core.hooksPath`). Ensure hooks are active by running `node scripts/setup_hooks.mjs`.

---

## 5. Verification Before Completion (CI Gate)

Before declaring any task or implementation complete:
- Run the fast plugin validator: `node scripts/validate_plugins.mjs` (or `node scripts/validate_plugins.mjs --fix` to auto-repackage out-of-sync plugins).
- Run the architecture gate: `flutter test test/architecture_test.dart` (enforced as a dedicated step in GitHub Actions CI with 10 passing invariants).
- Run the analyzer: `flutter analyze --no-fatal-infos` (0 errors, 0 warnings).
- If any plugin in `plugins/<name>/` was added or modified, run `node scripts/package_plugin.mjs <name>` to keep `plugins/<name>.hlep` in sync.
- Ensure no unintended files or temporary artifacts were created.

### Mandatory Pull Request Checklist
- [ ] **Zero Hardcoded Names**: No plugin IDs or subject names hardcoded in `frontend/lib/`.
- [ ] **No Direct Plugin Imports**: Zero cross-imports between `frontend/lib/` and `plugins/`.
- [ ] **Dynamic Ports**: Sidecar engines receive dynamic port via `--port` or `HOCLUC_PLUGIN_PORT`.
- [ ] **Package Freshness**: `node scripts/validate_plugins.mjs` passes with 0 errors.
- [ ] **Clean Feature-First Structure**: No loose files in `lib/services/` or `lib/widgets/`; zero flat tests at `test/` root.
- [ ] **Architecture Gate**: `flutter test test/architecture_test.dart` passes 10/10 invariants (100%).
