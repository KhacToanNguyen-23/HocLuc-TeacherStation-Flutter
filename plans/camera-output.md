# Windows camera output

The capture-area selector switches between **Toàn bộ ứng dụng** (entire app,
the default) and **Chỉ bảng** (board only), including while broadcasting.
Entire-app mode captures the Flutter app content, including toolbars, drawers,
floating plugin windows, timers, menus, and dialogs. It excludes the operating
system title bar, separate native windows, and other desktop applications.
Board-only mode captures the teaching stage and webcam overlay, with the board's
zoom strip and PDF teaching UI, while keeping surrounding controls local.

`CameraBroadcastService` captures the visible composition, fits it into a fixed
1280×720 frame, and sends raw RGBA bytes to the Windows plugin. It targets 30 FPS,
allows only one capture in flight, and displays measured capture throughput.
The webcam uses `camera` + `camera_windows`, with audio capture disabled.
Virtual cameras are excluded from the physical-camera picker to avoid feedback.

The plugin validates frames and UnityCapture registration, uses pixel stride,
converts Flutter's top-down rows to UnityCapture's bottom-up layout, and uses a
bounded shared-memory mutex wait. Busy receivers drop a frame rather than block
the app. Receiver status reflects recent UnityCapture frame requests; it is not
proof that anyone in a meeting is viewing the stream.

## Live use

1. Register UnityCapture's `Install/Install.bat` once. Keep its installed DLLs
   in the original location. No OBS or Unity game engine is required.
2. Run `flutter run -d windows --release` from `frontend`, then open a teaching
   studio. The bottom-left board controls work without a connected Meet room.
3. Show the webcam with the camera icon. Choose a physical camera using the
   settings icon. Drag the webcam to move it; drag its lower-right handle to
   resize it. Camera-off releases the physical device and shows a placeholder.
4. Choose **Toàn bộ ứng dụng** or **Chỉ bảng** in the bottom-left controls,
   then click **Phát camera ảo**. Open Google Meet's Settings → Video and select
   **Unity Video Capture**. Keep Meet's microphone set to your physical mic.
   Keep Meet's mic enabled; the studio's Windows mic button can mute/unmute
   that same input device. Its tune/settings button selects the controlled
   endpoint and adjusts its Windows input volume (affecting other apps too).
5. The board preview is live. The entire-app preview shows a snapshot taken when
   opened, preventing recursive capture of its own video preview. Non-16:9 app
   windows are fitted into 720p with padding rather than cropped. Stop with
   **Dừng camera ảo**. Leaving the studio releases the camera and output.

Only Windows supports virtual output. The existing browser preview is separate.
The camera adapter does not provide virtual audio. See
`in-app-microphone-controls.md` for Windows input controls; no additional driver
is needed for them. Automatic Meet device selection and custom camera-driver
branding are deferred. Layout coordinates remain stable during window
resizing; they are not saved between application sessions yet.

## Verification

Run `flutter test` and `flutter analyze lib test plugins/wgc_broadcaster/lib`
from `frontend`. The camera regression tests cover failed startup, RGBA frame
transport, overlay bounds, and capture-area pixels (app chrome appears only in
entire-app mode); the lobby tests cover actual camera state and
deferred audio.

Live verification with a physical webcam and independent UnityCapture receiver
confirmed correct orientation and colors, changing 1280×720 frames, PDF capture,
webcam off/on and hide/show, view switching, and output cleanup. Performance was
approximately 22 FPS in profile mode on the development machine. Google Meet's
received image was also confirmed using a second account. Meet's self-preview
may appear mirrored even when the received video is correct.

Temporary hardware-test applications and generated output were removed before
handoff. To repeat the live check, run the studio and join Google Meet using a
second device or account.

The application build opts `webview_windows` 0.4.0 into legacy-coroutine
compatibility for MSVC 14.51. Its build script automatically downloads a
checksum-verified local NuGet executable when NuGet is not on PATH.
