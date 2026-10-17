import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/virtual_media_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 03: VirtualMediaBridge Tests', () {
    late VirtualMediaBridge bridge;
    final List<MethodCall> methodCalls = [];

    setUp(() {
      bridge = VirtualMediaBridge();
      bridge.resetForTesting();
      methodCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VirtualMediaBridge.channel, (
            MethodCall call,
          ) async {
            methodCalls.add(call);
            switch (call.method) {
              case 'isVirtualCamInstalled':
                return true;
              case 'startVirtualCam':
                return true;
              case 'stopVirtualCam':
                return true;
              case 'sendVideoFrame':
                return true;
              case 'sendAudioChunk':
                return true;
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(VirtualMediaBridge.channel, null);
    });

    test('1. Initial state of bridge is idle and not streaming', () {
      expect(bridge.isStreaming, isFalse);
      expect(bridge.framesSent, equals(0));
      expect(bridge.audioChunksSent, equals(0));
    });

    test('2. isVirtualCamInstalled invokes native channel', () async {
      final installed = await bridge.isVirtualCamInstalled();
      expect(installed, isTrue);
      expect(
        methodCalls.map((c) => c.method),
        contains('isVirtualCamInstalled'),
      );
    });

    test(
      '3. startVirtualCam and stopVirtualCam manage streaming lifecycle',
      () async {
        final started = await bridge.startVirtualCam(
          width: 1920,
          height: 1080,
          fps: 30,
        );
        expect(started, isTrue);
        expect(bridge.isStreaming, isTrue);
        expect(
          methodCalls.last.arguments,
          equals({'width': 1920, 'height': 1080, 'fps': 30}),
        );

        final stopped = await bridge.stopVirtualCam();
        expect(stopped, isTrue);
        expect(bridge.isStreaming, isFalse);
      },
    );

    test(
      '4. sendVideoFrame and sendAudioChunk track dispatched metrics',
      () async {
        await bridge.startVirtualCam();

        final frame = Uint8List(1280 * 720 * 4); // Fake BGRA frame
        final frameResult = await bridge.sendVideoFrame(frame);
        expect(frameResult, isTrue);
        expect(bridge.framesSent, equals(1));

        final pcm = Uint8List(1024); // Fake PCM chunk
        final audioResult = await bridge.sendAudioChunk(pcm);
        expect(audioResult, isTrue);
        expect(bridge.audioChunksSent, equals(1));
      },
    );

    test('5. Frames are rejected when bridge is not active', () async {
      final frame = Uint8List(100);
      final frameResult = await bridge.sendVideoFrame(frame);
      expect(frameResult, isFalse);
      expect(bridge.framesSent, equals(0));
    });
  });
}
