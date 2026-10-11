# Mộc · Teacher Station (Học Lực)

> A high-performance, ergonomic teaching companion application for educators, built with **Flutter (Dart)** and **Java 17 (Spring Boot 3)**.

---

## Overview

**Mộc · Teacher Station** is designed to streamline modern online and hybrid classrooms. It combines an intuitive digital whiteboard workspace with an automated companion service, teacher dashboard, and live classroom tools.

### Key Highlights
- **Modern Monorepo Architecture**: Clean separation between Flutter frontend (`frontend/`) and Spring Boot companion backend (`backend/api/`).
- **Ergonomic Studio Workspace**: 16:9 stage container, multi-page whiteboard, PDF/document shelf, sample quiz questions with countdown timers, and floating webcam PIP.
- **Teacher Authentication & Dashboard**:
  - **Password Auth**: Quick sign-in via Email or Phone + Password (zero OTP friction for returning teachers).
  - **Secure Registration**: Phone/Email verification code (OTP countdown) + Password.
  - **Social & Demo Login**: Google Sign-In and 1-click Demo quick access with symmetrical circular action buttons.
  - **Nordic Sky & Slate Design**: Clean aesthetics, responsive 3D cards, and quick avatar profile menu.
- **Low-Latency Windows Broadcasting**: Windows.Graphics.Capture (WGC) C++ plugin (`wgc_broadcaster`) designed for capturing whiteboard HWND directly to virtual camera feeds.

---

## Project Structure

```text
HocLuc-TeacherStation-Flutter/
├── backend/
│   ├── api/                   # Spring Boot 3 Companion REST Service (port 47831)
│   ├── db/                    # Database schema and initialization scripts (init.sql)
│   └── whiteboard-host/       # Standalone Fastboard / Netless whiteboard engine
├── frontend/                  # Flutter application (Web & Windows Desktop)
│   ├── lib/
│   │   ├── constants/         # Design tokens, color system (Nordic Sky / Slate)
│   │   ├── models/            # Studio state, lesson data, drawing strokes
│   │   ├── screens/           # LoginScreen, ClassroomDashboardScreen, StudioScreen
│   │   ├── services/          # REST client, Auth service, Meet automation
│   │   ├── theme/             # Design typography, elevations, and themes
│   │   └── widgets/           # Auth modals, toolbar, stage container, floating PIP
│   ├── plugins/
│   │   └── wgc_broadcaster/   # C++ Windows.Graphics.Capture native plugin
│   └── test/                  # Unit and widget test suite (22 tests)
├── plans/                     # Architecture specifications & design documentation
├── Build-Windows.ps1          # Standalone Windows portable packaging script
└── README.md                  # Project documentation
```

---

## Prerequisites

Before setting up the project, ensure you have the following installed and added to your `PATH`:

- **Java Development Kit (JDK)**: JDK 17 with `java` and `jlink`
- **Apache Maven**: Version 3.9+
- **Flutter SDK**: Version 3.27+ (Dart 3.5+)
- **Node.js & npm**: Node.js 20+ (optional, only required if rebuilding `backend/whiteboard-host`)
- **Operating System**: Windows 10/11 x64 (recommend enabling **Developer Mode** in *Settings > System > For developers* for Flutter symlink support)

---

## Quick Start (Development Workflow)

For active development with instant Hot Reload and live logging, use the recommended dual-terminal setup:

### Terminal 1: Backend Companion Service (Spring Boot)
```bash
cd backend/api
mvn spring-boot:run
```
*The companion service will start and listen at `http://127.0.0.1:47831`.*

### Terminal 2: Frontend Studio (Flutter)
```bash
cd frontend
flutter pub get

# Run on Chrome (Web Preview):
flutter run -d chrome

# Or run natively on Windows Desktop:
flutter run -d windows
```
*Press `r` for Hot Reload, `R` for Hot Restart in the Flutter terminal.*

---

## Testing & Quality Assurance

The codebase enforces strict static analysis and comprehensive test suites across both frontend and backend.

### Backend Verification
```bash
cd backend/api
mvn test
```

### Frontend Static Analysis & Tests
```bash
cd frontend

# Verify 0 analyzer errors or warnings
flutter analyze lib

# Run the full unit and widget test suite
flutter test
```

### Production Web Build
```bash
cd frontend
flutter build web --release
```

---

## Standalone Windows Distribution (`.exe`)

You can generate a self-contained portable Windows package without requiring end-users to install Java, Flutter, or Node.js:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Windows.ps1
```

### How the Portable Package Works:
1. **Embedded Java JRE**: Uses `jlink` to generate a stripped-down Java 17 runtime for the backend.
2. **Self-Hosted WebView2**: Embeds the offline Flutter web bundle inside a lightweight WinForms/WebView2 shell (`HocLuc-Teacher.exe`).
3. **No Admin Privileges Needed**: Runs completely in user space; teacher notes and preferences are saved under `%LOCALAPPDATA%\HocLuc-Teacher\data`.
4. The output is placed in `dist/HocLuc-Teacher-Windows-x64/`.

---

## Capabilities & Architecture Roadmap

| Component | Status | Description |
| :--- | :---: | :--- |
| **Authentication Flow** | ✅ Ready | Password auth, OTP registration, Google sign-in & 1-click Demo |
| **Classroom Dashboard** | ✅ Ready | Classroom management, active sessions, avatar dropdown |
| **Ergonomic Studio Stage** | ✅ Ready | 16:9 stage switcher, drawing tools, quiz timer, split views |
| **Spring Boot Companion API** | ✅ Ready | Session bootstrap (`/api/bootstrap`), auth endpoints, storage |
| **Local Data Persistence** | ✅ Ready | Lessons and teacher settings saved via loopback REST API |
| **WGC Screen Capture Plugin** | 🔄 In Progress | C++ Windows.Graphics.Capture plugin for target window extraction |
| **Virtual Camera Output** | 📋 Planned | DirectShow / UnityCapture virtual camera bridge to Google Meet |
| **AI Lecture Assistant** | 📋 Planned | Speech recognition, noise cancellation, and automated summary |

---

## License & Contributing

This project is developed for educational technology research and teacher assistance.  
For internal guidelines, architectural decisions, and feature specifications, refer to the documents in [`plans/`](plans/).
