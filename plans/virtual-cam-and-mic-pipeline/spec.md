# Spec: Virtual Cam & Mic Transmission Pipeline

**Date:** 2026-10-12
**Status:** Ready

---

## Problem Statement
Currently, teacher's camera and microphone operate strictly within Google Meet inside the WebView2 container or separate browser, while the Flutter app UI (Lobby screen "Kiểm tra Thiết bị & Hình ảnh" and Studio floating webcam PIP) has no live feed or audio meter. Furthermore, directly capturing physical hardware in Meet prevents future sound customization (DSP filters, noise suppression, voice modulation). A lightweight, modular Virtual Device Pipeline is needed to preview media in the app, feed synchronized streams to Google Meet, and provide a clear insertion point for audio/video processing.

---

## User Stories

<!-- P1 = MVP (must ship), P2 = nice-to-have, P3 = future/out-of-scope -->

- **[P1]** As a teacher, I want to see my real-time webcam feed in the Classroom Lobby preview card ("Kiểm tra Thiết bị & Hình ảnh") and in the Studio Floating PIP card so that I can verify my framing and video quality before and during class.
  Accepted when: Selecting a camera device starts the live video feed inside the Lobby card and Studio PIP at ≥ 24 FPS with no black screens.

- **[P1]** As a teacher, I want to see a live microphone input volume meter in the Lobby card so that I can confirm my voice is being picked up clearly before joining the meeting.
  Accepted when: Speaking into the physical microphone displays real-time audio amplitude fluctuations on the UI level meter with < 50ms visual response.

- **[P1]** As a teacher, I want Google Meet to receive video and audio through "HocLuc Studio Camera" and "HocLuc Virtual Mic" so that students in the room see my camera and hear my speech reliably without device conflicts.
  Accepted when: Google Meet inside WebView2 automatically selects and streams "HocLuc Studio Camera" and "HocLuc Virtual Mic" as active inputs.

- **[P1]** As a teacher, I want to toggle camera mute and microphone mute directly from the Lobby card and Studio controls so that my privacy is respected across both the app and Google Meet simultaneously.
  Accepted when: Clicking mute mic/cam in the app stops transmission to the virtual devices and reflects muted status in Google Meet.

- **[P2]** As an admin or installer, I want the virtual camera and audio bridge to add less than 3 MB to the application bundle and require zero manual command-line configuration by the teacher.
  Accepted when: The application package size increases by < 3 MB and VirtualCam registers automatically without external OBS installation.

- **[P3]** As a teacher, I want to apply real-time voice changer effects (pitch shift, AI voice modulators, studio reverberation) and noise gate filters to my microphone feed before it reaches Google Meet.
  _(Out of scope for P1/P2 MVP — noted as extension point for Phase 3)._

---

## Functional Requirements

1. **FR-01 (Hardware Device Enumeration):** The app must discover and list available physical video capture devices (webcams) and audio input devices (microphones) on the Windows host.
2. **FR-02 (Local Live Preview):** The app must render the selected camera feed onto a Flutter Texture widget in the Lobby preview card and Studio Floating PIP.
3. **FR-03 (Audio Level Metering):** The app must capture raw PCM audio from the selected microphone, compute RMS/peak decibel amplitude, and publish normalized values (0.0 to 1.0) to the UI at 30Hz or higher.
4. **FR-04 (Virtual Camera Transmission):** The app must copy camera frames into a DirectShow VirtualCam shared memory buffer (`HocLucVirtualCam`) so that Windows and WebView2 perceive a native DirectShow camera.
5. **FR-05 (Virtual Audio Sink):** The app must output PCM audio samples into a virtual audio device / loopback endpoint (`HocLucVirtualMic`) with minimal latency (< 30ms).
6. **FR-06 (WebView2 Device Selection Automation):** The injected `MeetBridgeScript` must automatically select `HocLuc Studio Camera` and `HocLuc Virtual Mic` when Google Meet negotiates media devices.

---

## Non-Functional Requirements

- **Performance:** End-to-end video latency between physical capture and virtual camera output < 30ms. CPU utilization overhead for the pass-through pipeline < 3% on standard Intel Core i5 / AMD Ryzen 5 systems.
- **Resource Footprint:** Installer size delta < 3 MB; additional runtime RAM usage < 30 MB.
- **Reliability:** Graceful fallback if no physical webcam or microphone is connected (display informative placeholder and disabled controls).

---

## Success Criteria

- [ ] Video Preview: Lobby screen displays live webcam feed with resolution ≥ 720p at ≥ 24 FPS.
- [ ] Mic Metering: Live audio amplitude changes smoothly when speaking into microphone.
- [ ] Virtual Output: Google Meet in WebView2 captures video and audio from HocLuc virtual devices.
- [ ] Bundle Size: Additional binary files (DLLs / plugins) total < 3 MB.
- [ ] Test Suite: Unit tests and widget tests cover device discovery, mute state toggling, and bridge event synchronization (100% pass rate).

---

## Out of Scope

- AI Voice Changer / RVC neural inference models (reserved for future Phase 3).
- Face beauty filters, virtual green screen background replacement.
- MacOS / Linux virtual camera drivers (Windows desktop target only).

---

## Assumptions

- Windows 10/11 x64 environment with WebView2 Runtime installed.
- User grants OS camera and microphone permissions to the application.
