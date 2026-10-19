import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:camera_windows/camera_windows.dart';
import 'package:camera_windows/src/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/media_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Device discovery does not open the webcam owned by the preview',
    () async {
      final service = MediaDeviceService();
      service.resetForTesting();
      final previousPlatform = CameraPlatform.instance;
      CameraWindows.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const cameras = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.camera_windows.CameraApi.getAvailableCameras',
        CameraApi.pigeonChannelCodec,
      );
      const create = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.camera_windows.CameraApi.create',
        CameraApi.pigeonChannelCodec,
      );
      var createCalls = 0;
      messenger.setMockDecodedMessageHandler<Object?>(
        cameras,
        (_) async => [
          <String>['USB Webcam'],
        ],
      );
      messenger.setMockDecodedMessageHandler<Object?>(create, (_) async {
        createCalls++;
        return [1];
      });
      addTearDown(() {
        messenger.setMockDecodedMessageHandler<Object?>(cameras, null);
        messenger.setMockDecodedMessageHandler<Object?>(create, null);
        service.resetForTesting();
        CameraPlatform.instance = previousPlatform;
      });

      await service.init(initializeCamera: false);

      expect(service.cameras.single.id, 'USB Webcam');
      expect(service.isInitialized, isTrue);
      expect(createCalls, 0);
      expect(service.activeCameraId, isNull);
    },
  );
}

