# In-app Windows microphone controls

The studio's mic button controls the real Windows capture endpoint. Google Meet
must keep its mic enabled and use the same input device. No virtual audio driver
is needed. The microphone's mute and input volume affect every app using that
endpoint; these are not per-Meet controls. The app does not change the Windows
default input, and never automatically unmutes or restores volume on exit.

- Mic button: reads the current hardware state, toggles Windows mute, and shows
  the state returned by Windows. Hardware-key or Windows changes are polled.
- Settings/tune button: choose the default Windows input or a particular input
  endpoint, adjust input volume, refresh devices, and inspect errors.
- The meter uses Windows endpoint peak information and shows zero when muted
  or unavailable. No extra recording stream is opened for these controls.
- Lobby mute and the existing translation mute state follow the same service.
  Translation's audio routing is otherwise unchanged.

Implementation extends the existing `audio_bridge` plugin using the Windows
Core Audio `IMMDeviceEnumerator`, `IAudioEndpointVolume`, and
`IAudioMeterInformation` interfaces. Only active capture endpoints are accepted;
render/speaker IDs and invalid gain values are rejected. Startup, device
selection, polling, and closing the controls are read-only. Microphone controls
are Windows-only; browser media cannot mute another application's microphone.

Checks:

```powershell
flutter test test/system_microphone_service_test.dart test/system_microphone_controls_test.dart
flutter test
flutter analyze lib test integration_test plugins/audio_bridge/lib
flutter build windows --debug
```

Optional hardware check (briefly mutes the Windows default input, adjusts gain
while muted, and restores the original mute and gain even on assertion failure):

```powershell
flutter test integration_test/system_microphone_smoke_test.dart -d windows
```

For a Meet check, restart the Windows app after rebuilding the native plugin,
leave Meet's own mic enabled, and select the same named microphone in both apps.
Use a second participant/device to verify that studio mute silences the input.
