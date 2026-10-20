import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/system_microphone_service.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/system_microphone_controls.dart';

void main() {
  testWidgets(
    'studio mute and volume controls change confirmed endpoint state',
    (tester) async {
      const channel = MethodChannel('test/system-microphone-widget');
      final microphone = SystemMicrophoneService.forTesting(channel);
      var muted = false;
      var volume = .7;
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'systemMicrophoneDevices') {
              return [
                {'id': 'mic', 'name': 'USB Mic'},
              ];
            }
            if (call.method == 'setSystemMicrophoneMute') {
              muted = (call.arguments as Map)['muted'] as bool;
            }
            if (call.method == 'setSystemMicrophoneVolume') {
              volume = (call.arguments as Map)['volume'] as double;
            }
            return {
              'id': 'mic',
              'name': 'USB Mic',
              'muted': muted,
              'volume': volume,
              'level': .5,
            };
          });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: microphone,
              builder: (_, _) =>
                  SystemMicrophoneControls(microphone: microphone),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(calls.where((name) => name.startsWith('set')), isEmpty);
      await tester.tap(find.byTooltip('Tắt microphone Windows (mọi ứng dụng)'));
      await tester.pumpAndSettle();
      expect(muted, isTrue);
      expect(
        find.byTooltip('Bật microphone Windows (mọi ứng dụng)'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Cài đặt microphone Windows'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Điều khiển thiết bị cho mọi ứng dụng'),
        findsOneWidget,
      );
      await tester.drag(find.byType(Slider), const Offset(-70, 0));
      await tester.pumpAndSettle();
      expect(calls, contains('setSystemMicrophoneVolume'));
      expect(volume, lessThan(.7));
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      microphone.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
}

