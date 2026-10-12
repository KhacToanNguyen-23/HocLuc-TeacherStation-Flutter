# Phase 03: DirectShow VirtualCam & Virtual Audio Sink Native Engine

## Objective
Provide the lightweight DirectShow Virtual Camera filter (`HocLucVirtualCam.dll`, ~500 KB) and WASAPI loopback audio sink (`HocLucVirtualMic`). Establish shared memory frame writing from the Flutter Windows runner to the DirectShow filter buffer at 30 FPS, and PCM audio writing to the virtual microphone device.

## User Stories Covered
- **[P1]** Google Meet receives video and audio through "HocLuc Studio Camera" and "HocLuc Virtual Mic".
- **[P2]** Bundle size increase < 3 MB, silent registration without OBS installation.

## Proposed Changes
- [NEW] `frontend/windows/runner/virtual_cam_engine.h` & `virtual_cam_engine.cpp`:
  - Memory-mapped file buffer manager (`Local\\HocLuc_VirtualCam_Buffer`).
  - Write raw BGRA / NV12 camera frame buffer from Flutter Texture/Camera callback.
  - Expose MethodChannel `hocluc/virtual_media_engine`:
    - `isVirtualCamAvailable()`
    - `startVirtualCam()` / `stopVirtualCam()`
    - `registerFilters()`
- [NEW] `frontend/lib/services/virtual_media_bridge.dart`:
  - Dart wrapper communicating with native Windows Runner method channel.
  - Feeds camera frame updates and audio PCM chunks to the native memory bridge.
- [NEW] `frontend/test/virtual_media_bridge_test.dart`:
  - Unit tests verifying mock method channel interactions for virtual cam start/stop and frame pushes.

## Tests to Write First (TDD)
1. `VirtualMediaBridge queries native availability and reports status`.
2. `VirtualMediaBridge starts virtual camera and dispatches frame buffers without errors`.
3. `VirtualMediaBridge stops virtual pipeline and releases shared memory resources`.
