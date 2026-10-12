# Brainstorm: Virtual Cam & Mic Transmission Pipeline for Teacher Station

**Date:** 2026-10-12
**Status:** Completed

## Ideas Explored
1. **WebView2 MediaStream Bridge Loopback:** Captures hardware webcam and mic directly inside WebView2, extracts frames and audio levels to Flutter via bridge. (Dismissed: Cannot easily integrate standalone OS-level voice customization or external recording later, relies heavily on browser DOM/WebRTC internals).
2. **Dual Direct Capture:** Flutter and WebView2 both open the physical webcam and mic simultaneously. (Dismissed: Windows USB webcams are non-sharable single-client devices, causing device busy or black screen errors).
3. **Virtual Camera & Virtual Mic Loopback Device Engine:** Flutter captures physical webcam and mic, renders local preview in Lobby and Studio PIP, feeds video to a DirectShow VirtualCam DLL and audio to a Virtual Audio Loopback (WASAPI). Google Meet in WebView2 consumes "HocLuc Studio Camera" and "HocLuc Virtual Mic". (Selected).

## User's Direction
- **Primary Goal:** Establish a basic, stable, and lightweight connection pipeline first (camera preview in Lobby/Studio + mic audio level meter + pass-through to Google Meet).
- **Extensibility:** The architecture must cleanly separate the audio/video processing pipeline so that future features (AI voice changers, pitch shift, noise reduction, face filters) can be inserted without altering the connection to Google Meet.
- **Packaging Constraint:** The release bundle must remain lightweight (not bloated like a full OBS install; overhead < 3MB, silent registration).

## Open Questions
1. DirectShow VirtualCam registration method: Silent `regsvr32` during installation or on-demand runtime registration.
2. Microphone capture library: Pure Flutter Windows plugin (`record_windows` / `record`) vs native C++ (`miniaudio`).

## Risks
1. **Device Permission & Windows Driver Registry:** Antivirus or UAC policies on Windows might flag dynamic `regsvr32` execution if not properly bundled into the main installer.
2. **Latency:** Ensure frame copy between Flutter texture/runner and DirectShow shared memory buffer remains under 5ms to prevent audio-video desync in Google Meet.
