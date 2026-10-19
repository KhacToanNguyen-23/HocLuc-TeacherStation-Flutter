import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/audio_translation_service.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/audio_translation_controls.dart';

void main() {
  testWidgets(
    'Render actual audio controls with English selected and translation off',
    (tester) async {
      final loader = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await loader.load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      tester.view.physicalSize = const Size(560, 1020);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final api = LocalService();
      final audio = AudioTranslationService(service: api)
        ..language = 'en'
        ..supported = true
        ..inputId = 'mic'
        ..outputId = 'headphones'
        ..devices = [
          {'id': 'mic', 'name': 'Microphone (Realtek Audio)', 'input': true},
          {'id': 'headphones', 'name': 'Tai nghe nghe thử', 'input': false},
        ];
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              fontFamily: 'Manrope',
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff0284c7),
              ),
            ),
            home: Scaffold(
              backgroundColor: const Color(0xfff8fafc),
              body: Center(
                child: Container(
                  width: 430,
                  padding: const EdgeInsets.all(20),
                  color: Colors.white,
                  child: ListView(
                    children: [
                      const Text(
                        'Âm thanh lớp học',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AudioTranslationControls(
                        audio: audio,
                        onPreferencesChanged: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(audio.requested, isFalse);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final picture = await boundary.toImage();
        final png = await picture.toByteData(format: ui.ImageByteFormat.png);
        await Directory('../.run').create(recursive: true);
        await File(
          '../.run/audio-controls.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        picture.dispose();
      });
      audio.dispose();
      api.dispose();
    },
  );
}

