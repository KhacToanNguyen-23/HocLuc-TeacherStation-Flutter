import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:audio_bridge/audio_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Native WASAPI inventory works without starting microphone capture',
    (tester) async {
      final bridge = AudioBridge();
      final devices = await bridge.devices();
      expect(
        devices.every(
          (d) => d['id'] is String && d['name'] is String && d['input'] is bool,
        ),
        isTrue,
      );
      debugPrint('AUDIO_DEVICE_INVENTORY=${jsonEncode(devices)}');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Text('Native audio: ${devices.length} endpoints'),
          ),
        ),
      );
      final output = devices.where((d) => d['input'] == false).first;
      final ended = Completer<void>();
      final events = bridge.events.listen((event) {
        if (event['type'] == 'previewEnded' && !ended.isCompleted) {
          ended.complete();
        }
        if (event['type'] == 'error' && !ended.isCompleted) {
          ended.completeError(StateError(event['message'] as String));
        }
      });
      try {
        // Render 100 ms of silence: checks WASAPI and platform-event delivery, without capture.
        await bridge.preview(output['id'] as String, Uint8List(2400 * 4));
        await ended.future.timeout(const Duration(seconds: 5));
        debugPrint('AUDIO_SILENT_RENDER_AND_EVENT_OK');
      } finally {
        await events.cancel();
        await bridge.stop();
      }
      await bridge.stop();
    },
  );
}
