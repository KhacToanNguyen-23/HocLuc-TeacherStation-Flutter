# wgc_broadcaster

A Windows adapter that sends Flutter presentation frames to an installed
UnityCapture virtual camera. The historical package name is retained; the
adapter no longer captures an application HWND with `PrintWindow`.

## Usage

Register the official UnityCapture filter first. `startBroadcast()` checks its
64-bit registration and opens the shared frame buffer. `sendFrame(width, height,
rgba)` accepts tightly packed top-down RGBA bytes and returns whether a receiver
recently requested a frame. Width must be divisible by four; maximum dimensions
are 3840×2160. `stopBroadcast()` clears output and releases sender resources.

The adapter converts row orientation, uses UnityCapture's pixel stride, and
drops frames when the receiver mutex is busy. It does not install drivers,
capture a physical webcam, or route audio. The app's `CameraBroadcastService`
owns frame capture, pacing, output preview, and lifecycle.

See the repository's `plans/camera-output.md` for setup and live verification.

