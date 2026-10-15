import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/media_device_service.dart';
import 'package:teaching_companion/services/teacher_media_service.dart';
import 'package:teaching_companion/widgets/floating_pip.dart';
import 'package:teaching_companion/widgets/lobby/lobby_media_preview.dart';

void main() {
  group('Phase 02: Media Preview UI Tests', () {
    late MediaDeviceService mediaService;
    late TeacherMediaService teacherMedia;

    setUp(() async {
      mediaService = MediaDeviceService();
      mediaService.resetForTesting();
      await mediaService.init(
        mockCameras: [
          const MediaDeviceInfo(
            id: 'cam_1',
            label: 'USB HD Camera',
            kind: MediaDeviceKind.videoInput,
          ),
          const MediaDeviceInfo(
            id: 'cam_2',
            label: 'OBS Virtual Cam',
            kind: MediaDeviceKind.videoInput,
          ),
        ],
        mockMicrophones: [
          const MediaDeviceInfo(
            id: 'mic_1',
            label: 'Microphone Array',
            kind: MediaDeviceKind.audioInput,
          ),
        ],
      );
      teacherMedia = TeacherMediaService();
      await teacherMedia.initMedia();
    });

    testWidgets(
      '1. LobbyMediaPreview renders live status and reacts to audio level',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: LobbyMediaPreview(
                  mediaService: teacherMedia,
                  selectedBackground: 'none',
                  selectedCamera: 'USB HD Camera',
                  selectedMic: 'Microphone Array',
                  simulatedDb: 0.0,
                  onBackgroundSelected: (_) {},
                  onCameraChanged: (_) {},
                  onMicChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // Check header and status
        expect(find.text('Kiểm tra Thiết bị & Hình ảnh'), findsOneWidget);
        expect(find.text('Mic đang bật'), findsOneWidget);

        // Simulate voice input
        mediaService.simulateAudioLevel(0.65);
        await tester.pump();

        // Verify level is updated on teacherMedia
        expect(teacherMedia.audioLevel, equals(0.65));
      },
    );

    testWidgets('2. FloatingPip reflects mute states from MediaDeviceService', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final studio = StudioState();
      studio.toggleCameraPip(); // showCameraPip = true

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingPip(studio: studio)]),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Webcam'), findsOneWidget);
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);

      // Hide PiP
      studio.toggleCameraPip();
      await tester.pump();
      expect(find.text('Webcam'), findsNothing);

      studio.dispose();
    });
  });
}
