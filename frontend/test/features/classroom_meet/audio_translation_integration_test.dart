import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/audio_translation_studio_button.dart';

void main() {
  test(
    'Translation follows shared microphone state and unregisters on dispose',
    () async {
      final media = TeacherMediaService();
      final studio = StudioState();
      expect(studio.audio.muted, !media.isMicActive);
      await media.toggleMic();
      expect(studio.audio.muted, !media.isMicActive);
      await media.toggleMic();
      expect(studio.audio.muted, !media.isMicActive);
      studio.dispose();
      await media.toggleMic();
      await media.toggleMic();
    },
  );
  testWidgets(
    'Translation popup fits narrow and wide windows and closes with Escape',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final studio = StudioState();
      addTearDown(studio.dispose);
      for (final width in [375.0, 768.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 700);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AudioTranslationStudioButton(studio: studio)),
          ),
        );
        await tester.tap(find.text('Dịch giọng nói offline'));
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
      }
    },
  );
}

