import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/system_microphone_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/system-microphone');
  late SystemMicrophoneService microphone;
  late List<MethodCall> calls;
  late bool nativeMuted;
  late double nativeVolume;
  late bool failWrites;
  Map<String, Object> state() => {
    'id': 'physical-mic',
    'name': 'USB Mic',
    'muted': nativeMuted,
    'volume': nativeVolume,
    'level': .4,
  };
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    microphone = SystemMicrophoneService.forTesting(channel);
    calls = [];
    nativeMuted = false;
    nativeVolume = .7;
    failWrites = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'systemMicrophoneDevices':
              return [
                {'id': 'physical-mic', 'name': 'USB Mic'},
              ];
            case 'systemMicrophoneState':
              if ((call.arguments as Map)['id'] == 'missing') {
                throw PlatformException(code: 'disconnected');
              }
              return state();
            case 'setSystemMicrophoneMute':
              if (failWrites) throw PlatformException(code: 'access_denied');
              nativeMuted = (call.arguments as Map)['muted'] as bool;
              return state();
            case 'setSystemMicrophoneVolume':
              nativeVolume = (call.arguments as Map)['volume'] as double;
              return state();
            default:
              throw MissingPluginException();
          }
        });
  });
  tearDown(() {
    microphone.dispose();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test(
    'opening controls reads state without changing Windows mute or gain',
    () async {
      await microphone.refresh(discover: true);
      expect(microphone.ready, isTrue);
      expect(microphone.volume, .7);
      expect(calls.map((c) => c.method), [
        'systemMicrophoneDevices',
        'systemMicrophoneState',
      ]);
    },
  );
  test(
    'mute reads current hardware state before toggling and confirms native result',
    () async {
      await microphone.refresh();
      nativeMuted = true; // Changed by a hardware key or Windows after refresh.
      await microphone.toggleMute();
      expect(nativeMuted, isFalse);
      expect(microphone.muted, isFalse);
      expect(calls.last.method, 'setSystemMicrophoneMute');
      await microphone.toggleMute();
      expect(nativeMuted, isTrue);
      expect(microphone.level, 0);
    },
  );
  test(
    'failed mute exposes an error and never reports a successful mute',
    () async {
      await microphone.refresh();
      failWrites = true;
      await microphone.toggleMute();
      expect(microphone.ready, isFalse);
      expect(microphone.muted, isFalse);
      expect(microphone.errorMessage, contains('access_denied'));
    },
  );
  test(
    'device selection does not change the Windows default or mutate mute',
    () async {
      await microphone.refresh();
      calls.clear();
      await microphone.selectDevice('physical-mic');
      await microphone.setVolume(.35);
      expect(calls.last.arguments, {'id': 'physical-mic', 'volume': .35});
      expect(nativeVolume, .35);
      expect(microphone.volume, .35);
      expect(nativeMuted, isFalse);
    },
  );
  test(
    'disconnected device is not silently replaced with another microphone',
    () async {
      await microphone.refresh();
      await microphone.selectDevice('physical-mic');
      await microphone.selectDevice('missing');
      expect(microphone.ready, isFalse);
      expect(microphone.selectedId, 'physical-mic');
      expect(calls.where((c) => c.method.startsWith('set')), isEmpty);
    },
  );
  test('invalid volume never reaches Windows', () async {
    await microphone.refresh();
    await expectLater(microphone.setVolume(double.nan), throwsArgumentError);
    await expectLater(microphone.setVolume(1.1), throwsArgumentError);
    expect(
      calls.where((c) => c.method == 'setSystemMicrophoneVolume'),
      isEmpty,
    );
  });
  test('polling reflects an external mute and does not unmute it', () async {
    await microphone.refresh();
    nativeMuted = true;
    await microphone.refresh();
    expect(microphone.muted, isTrue);
    expect(microphone.level, 0);
    expect(calls.where((c) => c.method.startsWith('set')), isEmpty);
  });
}

