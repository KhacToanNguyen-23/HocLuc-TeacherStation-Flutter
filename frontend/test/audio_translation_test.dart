import 'dart:async';
import 'dart:typed_data';
import 'package:audio_bridge/audio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/audio_translation_service.dart';
import 'package:teaching_companion/services/local_service.dart';
import 'package:teaching_companion/widgets/studio/audio_translation_controls.dart';

class FakeBridge extends AudioBridge {
  final controller = StreamController<Map<String, dynamic>>.broadcast(
    sync: true,
  );
  bool english = false, muted = false;
  bool? startedMuted;
  int generation = 0, starts = 0;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<List<Map<String, dynamic>>> devices() async => [
    {'id': 'mic', 'name': 'Mic fixture', 'input': true},
    {'id': 'out', 'name': 'Output fixture', 'input': false},
  ];
  @override
  Future<void> start(String input, String output, {bool muted = false}) async {
    this.muted = muted;
    startedMuted = muted;
    starts++;
    controller.add({'type': 'ready'});
  }

  @override
  Future<int> mode(bool value) async {
    english = value;
    return ++generation;
  }

  @override
  Future<void> mute(bool value) async {
    muted = value;
  }

  @override
  Future<void> stop() async {
    english = false;
  }

  @override
  Future<void> enqueue(Uint8List samples) async {}
}

class FakeService extends LocalService {
  final pending = Completer<Map<String, dynamic>>();
  int posts = 0;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    Map<String, dynamic>? data,
  }) async => {'installed': true};
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    bool retryLocalSession = true,
  }) {
    posts++;
    return pending.future;
  }
}

void main() {
  late FakeBridge bridge;
  late FakeService backend;
  late AudioTranslationService audio;
  setUp(() async {
    bridge = FakeBridge();
    backend = FakeService();
    audio = AudioTranslationService(service: backend, bridge: bridge);
    await audio.refreshDevices();
    audio.inputId = 'mic';
    audio.outputId = 'out';
  });
  tearDown(() async {
    audio.dispose();
    backend.dispose();
    await Future<void>.delayed(Duration.zero);
    await bridge.controller.close();
  });
  test(
    'Starting the original bridge while muted sets mute before the first native frame',
    () async {
      await audio.setMuted(true);
      await audio.startOriginal();
      expect(bridge.startedMuted, isTrue);
      expect(audio.mode, 'muted');
      expect(backend.posts, 0);
    },
  );
  test(
    'Saved English and legacy active flags never activate a new session',
    () {
      audio.restore({
        'language': 'English',
        'translationRequested': true,
        'audio': {'targetLanguage': 'en', 'enabled': true},
      });
      expect(audio.language, 'en');
      expect(audio.requested, isFalse);
      expect(bridge.starts, 0);
      expect(backend.posts, 0);
      expect(audio.preferences.containsKey('enabled'), isFalse);
      expect(audio.preferences.containsKey('translationRequested'), isFalse);
    },
  );
  test(
    'Selecting English is a preference and sends no audio or model request',
    () async {
      await audio.selectLanguage('en');
      expect(audio.canTranslate, isTrue);
      expect(audio.requested, isFalse);
      expect(backend.posts, 0);
      expect(bridge.starts, 0);
    },
  );
  test(
    'OFF cancels a late warm-up response without reactivating English',
    () async {
      await audio.selectLanguage('en');
      final warmup = audio.setTranslation(true);
      await Future<void>.delayed(Duration.zero);
      expect(audio.requested, isTrue);
      expect(audio.mode, 'preparing');
      await audio.setTranslation(false);
      backend.pending.complete({'url': 'ws://127.0.0.1:1/stream'});
      await warmup;
      expect(audio.requested, isFalse);
      expect(audio.mode, 'original');
      expect(bridge.english, isFalse);
    },
  );
  test(
    'Switching to Vietnamese cancels pending English and keeps raw output',
    () async {
      await audio.selectLanguage('en');
      final warmup = audio.setTranslation(true);
      await Future<void>.delayed(Duration.zero);
      await audio.selectLanguage('vi');
      backend.pending.complete({'url': 'ws://127.0.0.1:1/stream'});
      await warmup;
      expect(audio.language, 'vi');
      expect(audio.requested, isFalse);
      expect(bridge.english, isFalse);
    },
  );
  test(
    'Mute blocks both paths and ignores the previous connection response',
    () async {
      await audio.selectLanguage('en');
      final warmup = audio.setTranslation(true);
      await Future<void>.delayed(Duration.zero);
      await audio.setMuted(true);
      backend.pending.complete({'url': 'ws://127.0.0.1:1/stream'});
      await warmup;
      expect(audio.mode, 'muted');
      expect(bridge.muted, isTrue);
      expect(bridge.english, isFalse);
    },
  );
  testWidgets(
    'Audio controls fit narrow and wide panels without activating AI',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [375.0, 414.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1100);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AudioTranslationControls(
                    audio: audio,
                    onPreferencesChanged: () {},
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Phát bản dịch tiếng Anh'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(audio.requested, isFalse);
        expect(backend.posts, 0);
      }
    },
  );
}
