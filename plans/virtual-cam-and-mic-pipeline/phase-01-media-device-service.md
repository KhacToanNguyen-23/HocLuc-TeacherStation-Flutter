# Phase 01: Media Device Discovery & Hardware Audio/Video Capture Service

## Objective
Implement `MediaDeviceService` to discover connected webcams and microphones on Windows, capture live camera frames, stream raw microphone PCM audio, calculate real-time decibel/RMS audio levels, and manage mute states.

## User Stories Covered
- **[P1]** Device discovery and selection.
- **[P1]** Live audio amplitude calculation and mic level metering.

## Proposed Changes
- [NEW] `frontend/lib/services/media_device_service.dart`:
  - `init()`: Detect physical video devices and audio input devices.
  - `startCamera(String deviceId)` / `stopCamera()`.
  - `startMicrophone(String deviceId)` / `stopMicrophone()`.
  - `setCameraMuted(bool muted)` / `setMicrophoneMuted(bool muted)`.
  - `Stream<double> get audioLevelStream`: Emits normalized audio level [0.0 - 1.0] at 30Hz.
  - Expose `cameraController` / texture ID for Flutter UI rendering.
- [NEW] `frontend/test/media_device_service_test.dart`:
  - Test device discovery fallback when hardware is absent.
  - Test audio amplitude normalization formula.
  - Test mute toggles and lifecycle listeners.

## Tests to Write First (TDD)
1. `MediaDeviceService initially has unmuted state and empty devices list`.
2. `MediaDeviceService calculates correct normalized RMS audio level from PCM byte chunks`.
3. `MediaDeviceService toggles camera and microphone mute states and notifies listeners`.
