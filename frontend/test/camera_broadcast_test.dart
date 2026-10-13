import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/camera_broadcast_service.dart';
import 'package:teaching_companion/widgets/presentation_surface.dart';
import 'package:wgc_broadcaster/wgc_broadcaster.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('wgc_broadcaster');
  tearDown(() async {
    await CameraBroadcastService().stop();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('failed native startup never reports broadcasting', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'startBroadcast') {
            throw PlatformException(
              code: 'camera_not_installed',
              message: 'Install UnityCapture',
            );
          }
          return true;
        });
    final studio = StudioState();
    await tester.pumpWidget(
      MaterialApp(
        home: PresentationSurface(
          studio: studio,
          child: const ColoredBox(color: Colors.green),
        ),
      ),
    );
    await CameraBroadcastService().start();
    expect(CameraBroadcastService().isBroadcasting, isFalse);
    expect(
      CameraBroadcastService().errorMessage,
      contains('Install UnityCapture'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    studio.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'virtual frame transport preserves RGBA payload and receiver acknowledgement',
    () async {
      MethodCall? sent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent = call;
            return true;
          });
      final pixels = Uint8List.fromList([
        255,
        0,
        0,
        255,
        0,
        255,
        0,
        255,
        0,
        0,
        255,
        255,
        255,
        255,
        255,
        255,
      ]);
      expect(await WgcBroadcaster.sendFrame(4, 1, pixels), isTrue);
      expect(sent!.method, 'sendFrame');
      expect((sent!.arguments as Map)['rgba'], pixels);
    },
  );

  test('webcam remains inside stage at both size limits', () {
    final studio = StudioState();
    for (final size in [const Size(320, 180), const Size(1920, 1080)]) {
      for (final scale in [.12, .4]) {
        studio.setPipWidth(scale);
        for (final position in [Offset.zero, const Offset(1, 1)]) {
          studio.setPipPosition(position);
          final rect = cameraRect(size, studio);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(rect.bottom, lessThanOrEqualTo(size.height));
        }
      }
    }
    studio.dispose();
  });
}
