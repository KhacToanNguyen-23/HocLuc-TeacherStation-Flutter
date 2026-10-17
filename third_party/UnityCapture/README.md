# UnityCapture for Windows development

Minimal installation files from [schellingb/UnityCapture](https://github.com/schellingb/UnityCapture), used by Teacher Station's Windows virtual-camera adapter.

## Install once after cloning

1. Keep this checkout at a stable location on Windows x64.
2. Close applications currently using the virtual camera.
3. In File Explorer, open `third_party/UnityCapture/Install`, right-click `Install.bat`, and select **Run as administrator**. Accept the registration dialogs for both DLLs; check that both report success.
4. Restart Teacher Station and the receiving application (browser or OBS). Select **Unity Video Capture** in the receiving application's camera list.

Pulling the repository does not run these scripts. Installation is manual and normally needed only once. The application checks the 64-bit filter registration before broadcasting. A Unity Editor installation is not required.

## Uninstall or move the checkout

Close camera consumers and run `Install/Uninstall.bat` as administrator. Confirm both unregistration dialogs succeed **before** deleting, moving, or replacing the registered DLLs, including when switching to a branch without these files. Reinstall from the new location afterward if needed.

Windows registers the DLLs at their absolute paths; do not remove this folder after installation. If UnityCapture is already installed elsewhere, coordinate before replacing it: registration is shared with other applications on the machine.

## Included files and provenance

- `Install/Install.bat` and `Install/Uninstall.bat`: unchanged upstream single-device registration scripts.
- `Install/UnityCaptureFilter32.dll` and `Install/UnityCaptureFilter64.dll`: unchanged upstream prebuilt filters. Both are required by the supplied scripts.
- `LICENSE.txt`: the complete filter license header copied from upstream `Source/UnityCaptureFilter.cpp`.

Copied from the supplied `UnityCapture-master` archive, whose files are dated April 14, 2023. The archive contains no Git metadata, so its exact upstream commit is unknown. SHA-256 hashes below identify the vendored bytes; they are not independent verification of upstream authenticity.

| File | SHA-256 |
| --- | --- |
| Install.bat | `18335923B497FF4B029032FBF7BBD666976E2D2C9973A6067736A4B9F31DCB25` |
| Uninstall.bat | `756F268A907A09E9C54A45E041FC51507C137BCB19F7B37B620B1C037B93437E` |
| UnityCaptureFilter32.dll | `AA3EBDF03DEA7F3AAB3DD7B724751F49ED71672256B57C6A19AA6809CABF30BA` |
| UnityCaptureFilter64.dll | `72812F5363D8ECB45632253F8C8C888844B1B62E27616F3C8CC21064CCDE25E5` |

Unity samples, sender plugins, custom-name/multiple-device scripts, and build sources are omitted because the app already supplies its sender and uses the default first device.
