import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/system_microphone_service.dart';
import 'package:teaching_companion/services/teacher_media_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Windows endpoint mute is shared with the translation pipeline',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      const channel = MethodChannel('hocluc/audio');
      var nativeMuted = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'systemMicrophoneDevices') {
              return [
                {'id': 'mic', 'name': 'USB Mic'},
              ];
            }
            if (call.method == 'setSystemMicrophoneMute') {
              nativeMuted = (call.arguments as Map)['muted'] as bool;
            }
            if (call.method == 'systemMicrophoneState' ||
                call.method == 'setSystemMicrophoneMute') {
              return {
                'id': 'mic',
                'name': 'USB Mic',
                'muted': nativeMuted,
                'volume': .7,
                'level': .4,
              };
            }
            return null;
          });
      final studio = StudioState();
      final media = TeacherMediaService();
      addTearDown(() {
        studio.dispose();
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await SystemMicrophoneService().refresh(discover: true);
      expect(media.isMicActive, isTrue);
      expect(studio.audio.muted, isFalse);
      await media.toggleMic();
      expect(nativeMuted, isTrue);
      expect(media.isMicActive, isFalse);
      expect(studio.audio.muted, isTrue);
      await media.toggleMic();
      expect(nativeMuted, isFalse);
      expect(studio.audio.muted, isFalse);
    },
  );
}
