# HocLuc Teacher Station

> A desktop and web teaching station with a microkernel plugin architecture, built with **Flutter (Dart)** and **Java 17 (Spring Boot 3)**.

---

## 1. Product Overview

**HocLuc Teacher Station** is an integrated digital workspace designed for teachers conducting online and hybrid classes. Instead of switching between disconnected presentation tools, digital whiteboards, Google Meet browser tabs, PDF exam repositories, and subject-specific simulators (such as scientific calculators or grammar analyzers), **HocLuc Teacher Station** unifies **Lesson Planning, Classroom Management, Live 16:9 Instruction, and Exam Analytics** into a single cohesive platform.

### Core Design Principles
- **Teacher-First Ergonomics:** A calm, high-contrast workspace (Warm Paper and Chalkboard palette) designed to reduce cognitive load and keep teachers in full control during live instruction.
- **Pure Microkernel Plugin Host:** The core application (`frontend/lib/`) is completely agnostic to subject-specific tools. Subject extensions (Mathematics, Physics, Chemistry, English, Casio fx-580VN X Calculator, etc.) are packaged as `.hlep` archives, distributed via the **On-Demand Cloud Marketplace**, cached locally on disk, and fully unloaded from memory when closed.
- **Seamless Google Classroom and Google Meet Integration:** Automated roster synchronization, embedded meeting control, automatic student admission, system-level microphone synchronization, and native Google Meet screen sharing from the embedded meeting panel.

---

## 2. Functional Requirements (FR)

### FR-01: Authentication, Teacher Profile, and Classroom Workspace
| ID | Feature | Description | Status |
| :--- | :--- | :--- | :---: |
| **FR-01.1** | Multi-Method Authentication | Sign-in via Email/Phone and Password, OTP verification for registration, Desktop Google OAuth2, and one-click Demo access. | Implemented |
| **FR-01.2** | Google Classroom Synchronization | Connects the teacher's Google account, synchronizes courses and student rosters, and automatically re-checks pending (`PROVISIONED`) courses when returning to the application. | Implemented |
| **FR-01.3** | Session Scheduling and History | Schedules live sessions, launches classroom lobbies, archives completed lectures, and exports post-session PDF handouts. | Implemented |

### FR-02: Ergonomic 16:9 Studio and Lesson Planning
| ID | Feature | Description | Status |
| :--- | :--- | :--- | :---: |
| **FR-02.1** | 16:9 Stage and Multi-Page Chalkboard | Pressure-sensitive freehand drawing (`perfect_freehand`), highlighter, eraser, geometric shapes, multi-page board management, and split-screen view. | Implemented |
| **FR-02.2** | Document Drawer and PDF Annotation | Imports PDF documents and images into the lesson, supports side-by-side viewing, region snipping, and direct PDF highlight export. | Implemented |
| **FR-02.3** | Pre-Class Lesson Planning | Dedicated preparation mode with speaker notes and one-click cloning of prepared board pages and documents into a live classroom session. | Implemented |
| **FR-02.4** | Floating Classroom Accessories | Draggable countdown timer (`FloatingTimer`), webcam picture-in-picture (`FloatingPip`), and interactive board annotations (`SmartChalkOverlay`). | Implemented |

### FR-03: Google Meet Automation and Audio Bridge
| ID | Feature | Description | Status |
| :--- | :--- | :--- | :---: |
| **FR-03.1** | Automated Meeting Launch and Join | Launches Google Meet inside an embedded WebView2 instance, handles camera/microphone consent with Flutter Allow/Deny buttons, and joins automatically. | Implemented |
| **FR-03.2** | Participant Admission and Cockpit | Displays a live student strip and Meet Cockpit inspector with pending admission counters, automatic admission toggle, speaking/hand-raise indicators, and end-call-for-all controls. | Implemented |
| **FR-03.3** | System Microphone Sync and Translation | Synchronizes mute state and input gain directly with the Windows Audio Endpoint and feeds the live translation/captioning pipeline. | Implemented |
| **FR-03.4** | Native Meet Screen Sharing | Use Present now in the embedded meeting panel, choose a window or screen, and confirm the browser capture picker. No virtual camera driver is required. | Requires live Windows verification |

### FR-04: Exam Workspace, Question Bank, and Competency Analytics
| ID | Feature | Description | Status |
| :--- | :--- | :--- | :---: |
| **FR-04.1** | PDF Exam Extraction | Uploads PDF exam papers, normalizes Vietnamese typography and font ligatures, extracts structured questions, and supports teacher review workflows. | Implemented |
| **FR-04.2** | Question Bank and Exam Matrix | Organizes questions by topic, skill, and difficulty; builds exam blueprints; generates papers; and exports print-ready PDFs. | Implemented |
| **FR-04.3** | Grading and Competency Analytics | Records student exam results, computes score distributions, analyzes skill mastery across sections, and generates targeted study recommendations. | Implemented |

### FR-05: Plugin Ecosystem and Cloud Marketplace (Schema v2.1)
| ID | Feature | Description | Status |
| :--- | :--- | :--- | :---: |
| **FR-05.1** | Cloud Marketplace Registry | Spring Boot backend dynamically scans `plugins/*.hlep` packages, computes `SHA-256` checksums, and exposes catalog (`GET /api/marketplace/plugins`) and download (`GET /api/marketplace/plugins/{id}/download`) endpoints. | Implemented |
| **FR-05.2** | One-Click Install and Offline Cache | Teachers browse, install, and auto-update `.hlep` plugins directly from the Studio drawer, with local extraction to `%LOCALAPPDATA%/HocLuc/plugins/<id>/v<version>/`. | Implemented |
| **FR-05.3** | Multi-Instance Plugin Execution | Supports running a floating device plugin (`floating_window`) simultaneously alongside a lesson-bound drawer plugin (`bottom_drawer` / `drawer_panel`). | Implemented |
| **FR-05.4** | Declarative Board Tool Contributions | Dynamically renders in-board tool palettes (`SubjectToolPalette`) from `contributes.tools` declarations in `manifest.json` (modeled after VS Code Extension Contribution Points). | Implemented |
| **FR-05.5** | Automatic SDK Injection | Internal loopback gateway (`PluginWebServer`) automatically injects `hocluc-plugin-sdk.js` into third-party HTML/JS/WASM bundles when `"inject_sdk": true` is set. | Implemented |
| **FR-05.6** | Frameless Bare-Device Mode | When `"frameless": true` is declared in `manifest.json` (such as the **Casio fx-580VN X Calculator**, `336x624`), the host removes all window chrome, headers, and footers, rendering only the physical device body with an integrated top-bezel drag strip and compact close button. | Implemented |

---

## 3. Non-Functional Requirements (NFR)

| ID | Quality Attribute | Specification and Enforcement Mechanism |
| :--- | :--- | :--- |
| **NFR-01** | **Microkernel Isolation and Zero Hardcoding** | - Zero hardcoded plugin identifiers (`english_assistant`, `casio_calculator`, `com.hocluc.plugin.*`) inside `frontend/lib/`.<br>- Zero cross-imports between `frontend/lib/` and `plugins/`.<br>- Automatically enforced on every pull request by `flutter test test/architecture_test.dart`. |
| **NFR-02** | **Performance and Memory Efficiency** | - **Lazy Disk Caching:** Plugin archives are never unpacked into in-memory byte maps (`filesMap`); assets are extracted to disk and served on demand over loopback HTTP (`PluginWebServer`).<br>- **60 FPS Canvas Rendering:** Stroke paths are cached (`_cachedPath`) to maintain smooth ink rendering at 1080p/2K resolutions.<br>- **Deterministic Process Cleanup:** Sidecar processes (Python/binary engines) are supervised and terminated immediately upon plugin closure via `ProcessSupervisor`. |
| **NFR-03** | **Security and Sandboxing** | - **Zip Slip Prevention:** `PluginStorageManager` validates all archive entry paths (`..` traversal checks) prior to disk extraction.<br>- **Package Integrity:** `SHA-256` checksum verification for downloaded `.hlep` packages.<br>- **Dynamic Ephemeral Ports:** Hardcoded ports (such as `18888`) are prohibited; loopback servers and sidecar engines bind to OS-assigned ephemeral ports.<br>- **Local API Protection:** Loopback REST communication is authenticated via `SecurityTokenInterceptor` (`X-Companion-Token`). |
| **NFR-04** | **Offline Resilience** | - Marketplace catalog metadata and installed plugin directories are cached locally (`SharedPreferences` and `%LOCALAPPDATA%/HocLuc/plugins/`), allowing previously installed plugins to run without internet or backend connectivity. |
| **NFR-05** | **Developer Extensibility** | - New subject plugins or third-party open-source web applications (React/Vue/HTML/WASM) can be integrated in under 5 minutes using only a declarative `manifest.json` (Schema v2.1) and `node scripts/package_plugin.mjs <folder>`, requiring zero modifications to Flutter or Java source code. |
| **NFR-06** | **Display Compatibility and Portability** | - Verified by automated visual geometry regression tests (`visual_restyle_test.dart`) across four standard viewports: `1366x768`, `1440x900`, `1920x1080 (100%)`, and `1920x1080 (125% DPI)`.<br>- Supports standalone Windows packaging (`Build-Windows.ps1`) with an embedded custom Java 17 runtime (`jlink`) and WebView2 host requiring no administrator privileges. |

---

## 4. Repository Structure

```text
HocLuc-TeacherStation-Flutter/
├── .github/workflows/             # Automated CI pipelines (Backend CI and Frontend Architecture Gate)
├── .agents/rules/                 # Mandatory architectural rules for AI Coding Agents (Schema v2.1)
├── backend/
│   ├── api/                       # Spring Boot 3 Companion and Plugin Marketplace Service (port 47831)
│   ├── db/                        # Database schema initialization (init.sql)
│   └── whiteboard-host/           # Standalone Fastboard / Netless whiteboard host
├── frontend/                      # Flutter application (Windows Desktop and Web)
│   ├── lib/
│   │   ├── constants/             # Design tokens, color system, spacing, motion curves
│   │   ├── models/                # StudioState, PluginManifest (Schema v2.1), lesson models
│   │   ├── screens/               # Login, Dashboard, Lobby, Studio (16:9), ExamWorkspace
│   │   ├── services/              # PluginManager, PluginWebServer, PluginMarketplaceService, HostBridge
│   │   └── widgets/               # FloatingPluginWindow (Frameless/Standard), SubjectToolPalette, Stage
│   ├── plugins/
│   │   └── audio_bridge/          # Native system audio endpoint bridge
│   └── test/                      # 270+ unit, widget, visual geometry, E2E, and architecture tests
├── plugins/                       # Isolated subject extension packages (.hlep)
│   ├── casio_calculator/          # Casio fx-580VN X Calculator plugin (Frameless Bare-Device mode)
│   ├── casio_calculator.hlep      # Packaged Casio archive served by Backend Marketplace
│   ├── english_assistant/         # English Assistant plugin (S-V-O-A and DGNL + Python sidecar)
│   └── english_assistant.hlep     # Packaged English Assistant archive
├── scripts/
│   └── package_plugin.mjs         # CLI tool to validate Schema v2.1 and package .hlep with SHA-256
├── docs/architecture/             # Architecture documentation and Plugin Developer Guide
├── AGENTS.md                      # Repository architecture invariants for developers and AI agents
└── Build-Windows.ps1              # Standalone Windows portable packaging script
```

---

## 5. Prerequisites and Quick Start

### Prerequisites
- **Java Development Kit (JDK):** JDK 17+ (`java` and `jlink` available in `PATH`)
- **Apache Maven:** Version 3.9+
- **Flutter SDK:** Version 3.27+ (Dart 3.5+)
- **Node.js:** Version 20+ (used by `scripts/package_plugin.mjs`)
- **Operating System:** Windows 10/11 x64 (enable **Developer Mode** in *Settings > System > For developers*)

### Step 1: Start the Backend Companion and Marketplace Service (Terminal 1)
```powershell
cd backend/api
mvn spring-boot:run
```
*The service listens at `http://127.0.0.1:47831` (Marketplace catalog endpoint: `http://127.0.0.1:47831/api/marketplace/plugins`).*

### Step 2: Launch the Flutter Teacher Station (Terminal 2)
```powershell
cd frontend
flutter pub get

# Run natively on Windows Desktop (recommended for full WebView2 and plugin support):
flutter run -d windows

# Or run in Chrome for web preview:
flutter run -d chrome
```

---

## 6. Plugin Development Workflow (Schema v2.1)

Team members can create and publish new plugins inside `plugins/<plugin_name>/` **without modifying any files in `frontend/lib/`**:

1. Create `plugins/<plugin_name>/` with `ui/index.html`, `icon.png`, and `manifest.json` (refer to the copy-paste templates in [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md)).
2. Package the plugin into a `.hlep` archive:
   ```powershell
   node scripts/package_plugin.mjs <plugin_name>
   ```
3. Run the architectural verification suite:
   ```powershell
   cd frontend
   flutter test test/architecture_test.dart
   ```

Refer to [`docs/architecture/plugin-development-guide.md`](docs/architecture/plugin-development-guide.md) and [`AGENTS.md`](AGENTS.md) for complete Schema v2.1 specifications.

---

## 7. Testing and Continuous Integration Gates

Every push and pull request targeting `develop` or `main` is validated by two GitHub Actions workflows:

### Backend Verification (`.github/workflows/ci-backend.yml`)
```powershell
cd backend/api
mvn -B clean test
```

### Frontend Verification and Architecture Gate (`.github/workflows/ci-frontend.yml`)
```powershell
cd frontend

# 1. Static code analysis (zero errors or warnings)
flutter analyze --no-fatal-infos

# 2. Dedicated Plugin Architecture Invariants Gate (enforces AGENTS.md)
flutter test test/architecture_test.dart

# 3. Full unit, widget, visual geometry, and E2E test suite (270+ tests)
flutter test
```

---

## 8. Standalone Windows Distribution (`.exe`)

To build a self-contained portable Windows bundle that runs without requiring end-users to install Java, Flutter, or Node.js:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1
```
The portable distribution is generated in `dist/HocLuc-Teacher-Windows-x64/`.
