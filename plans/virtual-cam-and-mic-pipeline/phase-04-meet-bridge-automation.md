# Phase 04: Google Meet Device Selection Automation & Synchronization

## Objective
Update `MeetBridgeScript` and `MeetAutomationService` to automatically detect and select "HocLuc Studio Camera" and "HocLuc Virtual Mic" inside the Google Meet WebView2 session upon room entrance, and synchronize mute/unmute state between the desktop app and Google Meet.

## User Stories Covered
- **[P1]** Google Meet automatically selects virtual camera and mic.
- **[P1]** Bi-directional mute synchronization between Desktop app and Google Meet.

## Proposed Changes
- [MODIFY] `frontend/lib/services/meet_bridge_script.dart`:
  - Enhance script injection to override or auto-select `HocLuc Studio Camera` and `HocLuc Virtual Mic` in `navigator.mediaDevices.enumerateDevices()`.
  - Add JS bridge handlers to toggle Meet's internal mute buttons when Flutter triggers mute/unmute.
  - Dispatch event `MEET_MEDIA_DEVICE_SELECTED` to Flutter when virtual devices are successfully hooked.
- [MODIFY] `frontend/lib/services/meet_automation_service.dart`:
  - Handle `MEET_MEDIA_DEVICE_SELECTED` and update active media status.
  - Expose `syncMuteState(bool micMuted, bool camMuted)` method.
- [MODIFY] `frontend/test/meet_bridge_parser_test.dart`:
  - Add test parsing `MEET_MEDIA_DEVICE_SELECTED` bridge events.

## Tests to Write First (TDD)
1. `MeetBridgeScript contains automated device selection routines for HocLuc virtual devices`.
2. `MeetBridgeParser correctly parses MEET_MEDIA_DEVICE_SELECTED events`.
3. `MeetAutomationService syncs mute states with bridge commands`.
