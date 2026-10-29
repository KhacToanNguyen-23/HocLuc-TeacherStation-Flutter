import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/presentation/widgets/middle_mouse_pan.dart';

void main() {
  testWidgets('MMB pans in screen pixels and release restores child input', (
    tester,
  ) async {
    final deltas = <Offset>[];
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MiddleMousePan(
          onPan: deltas.add,
          child: GestureDetector(
            onTap: () => taps++,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    final mouse = await tester.startGesture(
      const Offset(100, 100),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await tester.pump();
    await mouse.moveBy(const Offset(25, -15));
    expect(deltas, [const Offset(25, -15)]);
    await mouse.up();
    await tester.pump();
    expect(taps, 0);
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
    expect(deltas.length, 1);
  });
}
