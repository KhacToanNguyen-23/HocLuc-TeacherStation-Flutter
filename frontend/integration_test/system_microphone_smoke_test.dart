import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Opt-in hardware test: briefly mutes the default input's endpoint controls,
/// then restores both original values. Does not record or transmit audio.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Windows microphone mute and gain are real endpoint controls', (
    tester,
  ) async {
    const channel = MethodChannel('hocluc/audio');
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('Microphone control hardware check')),
      ),
    );
    final original = await channel.invokeMapMethod<String, dynamic>(
      'systemMicrophoneState',
      {'id': ''},
    );
    expect(original, isNotNull);
    final id = original!['id'] as String;
    final muted = original['muted'] as bool;
    final volume = (original['volume'] as num).toDouble();
    try {
      final changed = await channel.invokeMapMethod<String, dynamic>(
        'setSystemMicrophoneMute',
        {'id': id, 'muted': true},
      );
      expect(changed!['muted'], isTrue);
      final readBack = await channel.invokeMapMethod<String, dynamic>(
        'systemMicrophoneState',
        {'id': id},
      );
      expect(readBack!['muted'], isTrue);
      final target = volume > .2 ? volume - .1 : .4;
      final gain = await channel.invokeMapMethod<String, dynamic>(
        'setSystemMicrophoneVolume',
        {'id': id, 'volume': target},
      );
      expect((gain!['volume'] as num).toDouble(), closeTo(target, .03));
    } finally {
      try {
        await channel.invokeMethod<dynamic>('setSystemMicrophoneVolume', {
          'id': id,
          'volume': volume,
        });
      } finally {
        await channel.invokeMethod<dynamic>('setSystemMicrophoneMute', {
          'id': id,
          'muted': muted,
        });
      }
    }
    final restored = await channel.invokeMapMethod<String, dynamic>(
      'systemMicrophoneState',
      {'id': id},
    );
    expect(restored!['muted'], muted);
    expect((restored['volume'] as num).toDouble(), closeTo(volume, .03));
    debugPrint('WINDOWS_MICROPHONE_MUTE_AND_GAIN_OK; ORIGINAL_STATE_RESTORED');
  });
}
