import 'dart:typed_data';
import 'package:flutter/services.dart';

class AudioBridge {
  static const _commands = MethodChannel('hocluc/audio');
  static const _events = EventChannel('hocluc/audio/events');
  Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .map((event) => Map<String, dynamic>.from(event as Map));
  Future<List<Map<String, dynamic>>> devices() async =>
      ((await _commands.invokeMethod<List<dynamic>>('devices')) ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
  Future<void> start(String input, String output, {bool muted = false}) =>
      _commands.invokeMethod('start', {
        'input': input,
        'output': output,
        'muted': muted,
      });
  Future<void> stop() => _commands.invokeMethod('stop');
  Future<int> mode(bool english) async =>
      await _commands.invokeMethod<int>('mode', {'english': english}) ?? 0;
  Future<void> mute(bool muted) =>
      _commands.invokeMethod('mute', {'muted': muted});
  Future<void> enqueue(Uint8List samples) => _commands.invokeMethod('enqueue', {
    'samples': samples,
    'sampleRate': 24000,
  });
  Future<void> preview(String output, Uint8List samples) =>
      _commands.invokeMethod('preview', {'output': output, 'samples': samples});
}
