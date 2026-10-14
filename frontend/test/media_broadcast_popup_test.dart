import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/studio/media_broadcast_controls.dart';

void main() {
  testWidgets('Shared camera controls fit device popup and close on Escape', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final studio = StudioState();
    addTearDown(studio.dispose);
    for (final width in [320.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 700);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MediaBroadcastControlsButton(studio: studio)),
        ),
      );
      await tester.tap(find.text('Camera, micro & phát hình'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Phát camera ảo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    }
  });
}
