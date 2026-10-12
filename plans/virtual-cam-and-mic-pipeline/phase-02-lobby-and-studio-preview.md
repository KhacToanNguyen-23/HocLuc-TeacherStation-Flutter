# Phase 02: Classroom Lobby & Studio Floating PIP Live Preview UI

## Objective
Connect `MediaDeviceService` to the Classroom Lobby screen (`ClassroomLobbyScreen`) and the Studio Floating PIP widget (`FloatingPip`). Replace static avatar placeholders with live video textures, animated audio level indicators, and interactive mute controls.

## User Stories Covered
- **[P1]** Live webcam feed in Classroom Lobby preview card.
- **[P1]** Live microphone volume meter in Lobby card.
- **[P1]** Studio Floating PIP live camera stream and interactive mute buttons.

## Proposed Changes
- [MODIFY] `frontend/lib/screens/classroom_lobby_screen.dart`:
  - Integrate `MediaDeviceService` with live camera view inside `_buildMediaCheckCard()`.
  - Add animated audio level visualizer bar / mic pulse ring when speaking.
  - Hook camera toggle button and mic toggle button to `MediaDeviceService`.
- [MODIFY] `frontend/lib/widgets/floating_pip.dart`:
  - Replace static `GV` avatar with live camera texture stream when camera is unmuted.
  - Display fallback avatar when camera is muted by teacher.
- [NEW] `frontend/test/media_preview_ui_test.dart`:
  - Test Lobby screen displays camera preview and responds to mic amplitude updates.
  - Test Floating PIP toggles between live texture and avatar on mute.

## Tests to Write First (TDD)
1. `ClassroomLobbyScreen renders live camera preview when service is active`.
2. `ClassroomLobbyScreen updates audio meter indicator when audioLevelStream emits`.
3. `FloatingPip renders CameraPreview widget when unmuted and fallback avatar when muted`.
