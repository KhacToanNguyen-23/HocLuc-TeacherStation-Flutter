import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/media_device_service.dart';

void main() {
  group('Phase 01: MediaDeviceService TDD Tests', () {
    late MediaDeviceService service;

    setUp(() {
      service = MediaDeviceService();
      service.resetForTesting();
    });

    test('1. Initial state has default unmuted flags and zero audio level', () {
      expect(service.isCameraActive, isFalse);
      expect(service.isMicActive, isFalse);
      expect(service.isCameraMuted, isFalse);
      expect(service.isMicMuted, isFalse);
      expect(service.currentAudioLevel, equals(0.0));
      expect(service.cameras, isEmpty);
      expect(service.microphones, isEmpty);
    });

    test('2. Init populates camera and microphone devices', () async {
      await service.init(
        mockCameras: [
          const MediaDeviceInfo(id: 'cam_1', label: 'Integrated Webcam', kind: MediaDeviceKind.videoInput),
          const MediaDeviceInfo(id: 'cam_2', label: 'USB HD Camera', kind: MediaDeviceKind.videoInput),
        ],
        mockMicrophones: [
          const MediaDeviceInfo(id: 'mic_1', label: 'Internal Microphone', kind: MediaDeviceKind.audioInput),
        ],
      );

      expect(service.cameras.length, equals(2));
      expect(service.microphones.length, equals(1));
      expect(service.selectedCamera?.id, equals('cam_1'));
      expect(service.selectedMicrophone?.id, equals('mic_1'));
      expect(service.isCameraActive, isTrue);
      expect(service.isMicActive, isTrue);
    });

    test('3. Toggle and set camera and microphone mute states', () async {
      await service.init(
        mockCameras: [
          const MediaDeviceInfo(id: 'cam_1', label: 'Webcam', kind: MediaDeviceKind.videoInput),
        ],
        mockMicrophones: [
          const MediaDeviceInfo(id: 'mic_1', label: 'Mic', kind: MediaDeviceKind.audioInput),
        ],
      );

      bool notified = false;
      service.addListener(() => notified = true);

      service.toggleCameraMute();
      expect(service.isCameraMuted, isTrue);
      expect(notified, isTrue);

      notified = false;
      service.toggleMicrophoneMute();
      expect(service.isMicMuted, isTrue);
      expect(notified, isTrue);

      service.setCameraMuted(false);
      expect(service.isCameraMuted, isFalse);

      service.setMicrophoneMuted(false);
      expect(service.isMicMuted, isFalse);
    });

    test('4. calculateRmsLevel normalizes PCM16 buffer to [0.0, 1.0]', () {
      // 0 amplitude silence
      final silence = Uint8List(100);
      expect(MediaDeviceService.calculateRmsLevel(silence), closeTo(0.0, 0.001));

      // Max amplitude sine/square (full scale 32767)
      final loudBytes = ByteData(4);
      loudBytes.setInt16(0, 32767, Endian.little);
      loudBytes.setInt16(2, 32767, Endian.little);
      final loud = loudBytes.buffer.asUint8List();
      final level = MediaDeviceService.calculateRmsLevel(loud);
      expect(level, greaterThan(0.9));
    });

    test('5. AudioLevelStream emits normalized amplitude values when audio is active and unmuted', () async {
      await service.init(
        mockMicrophones: [
          const MediaDeviceInfo(id: 'mic_1', label: 'Mic', kind: MediaDeviceKind.audioInput),
        ],
      );

      final levels = <double>[];
      final sub = service.audioLevelStream.listen(levels.add);

      // Simulate audio chunk
      service.simulateAudioLevel(0.75);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.currentAudioLevel, equals(0.75));
      expect(levels.contains(0.75), isTrue);

      // When mic is muted, audio level should be 0.0
      service.setMicrophoneMuted(true);
      service.simulateAudioLevel(0.85);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(service.currentAudioLevel, equals(0.0));
      expect(levels.last, equals(0.0));

      await sub.cancel();
    });
  });
}
