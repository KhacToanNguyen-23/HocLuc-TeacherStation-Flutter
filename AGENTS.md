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

## 2. Hard Invariants for Plugin Development (BẮT BUỘC)

When working on any plugin or extending the Teacher Station plugin system:

1. **Zero Hardcoded Names**: NEVER hardcode plugin IDs (e.g., `'english_assistant'`, `'com.hocluc.plugin.english'`, `'casio'`) or specific subject names inside `frontend/lib/`. The Core Flutter App is a pure Microkernel Host.
2. **No Direct Plugin Imports**: NEVER import files across `frontend/lib/` and `plugins/`. All interactions must go through abstract interfaces and the Host Bridge.
3. **Dynamic Port Allocation**: NEVER hardcode port numbers (e.g., `18888`). Sidecar engines (Python/Binary) must accept dynamic ports passed via the `--port <port>` CLI argument or `HOCLUC_PLUGIN_PORT` environment variable.
4. **On-Demand Memory / Disk Cache**: NEVER unpack raw file bytes into RAM (`filesMap` in memory). Plugins downloaded from the Cloud Marketplace must be extracted to `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/` and loaded on demand (Lazy Loading).
5. **Enforce SDK Bridge**: Webview UI must NEVER call `window.chrome.webview.postMessage` directly with arbitrary payloads. All UI communication MUST use `hocluc-plugin-sdk.js` via the Typed RPC protocol.
6. **Detailed Developer Reference**: Always refer to [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md) for full manifest schema and templates.

---

## 3. Git Commit Rules

- **Only commit source code**: NEVER commit environment configs, personal setup scripts (such as `setup_flutter.ps1`), secrets, or `.env` files.
- All downloaded SDKs (e.g. `.sdk/`) must remain ignored.

---

## 4. Verification Before Completion

Before declaring any task or implementation complete:
- Run the architecture test: `flutter test test/architecture_test.dart` (or relevant tests).
- Ensure no unintended files or temporary artifacts were created.
