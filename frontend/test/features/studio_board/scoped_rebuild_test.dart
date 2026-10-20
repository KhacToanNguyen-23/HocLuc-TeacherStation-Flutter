import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/scoped_listenable_builder.dart';

void main() {
  group('Phase 04: Scoped listenable rebuilds', () {
    testWidgets('ScopedListenableBuilder rebuilds only when selection changes', (
      tester,
    ) async {
      final notifier = ValueNotifier<int>(0);
      addTearDown(notifier.dispose);
      var buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: ScopedListenableBuilder<bool>(
            listenable: notifier,
            selector: () => notifier.value.isEven,
            builder: (context, isEven) {
              buildCount++;
              return Text('$isEven');
            },
          ),
        ),
      );
      expect(buildCount, 1);

      notifier.value = 2; // still even -> no rebuild
      await tester.pump();
      expect(buildCount, 1);

      notifier.value = 3; // odd -> rebuild
      await tester.pump();
      expect(buildCount, 2);
      expect(find.text('false'), findsOneWidget);
    });

    test('laser pointer moves never notify aggregate studio listeners', () {
      final studio = StudioState();
      addTearDown(studio.dispose);
      var studioNotifications = 0;
      var laserNotifications = 0;
      studio.addListener(() => studioNotifications++);
      studio.laserOffsetListenable.addListener(() => laserNotifications++);

      studio.setLaserOffset(const Offset(0.1, 0.2));
      studio.setLaserOffset(const Offset(0.3, 0.4));
      studio.setLaserOffset(null);

      expect(studioNotifications, 0);
      expect(laserNotifications, 3);
      expect(studio.laserOffset, isNull);
    });
  });
}

