import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/models/teaching_target.dart';
import 'package:teaching_companion/screens/studio_screen.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_inspector_panel.dart';

void main() {
  for (final size in [
    const Size(360, 740),
    const Size(760, 680),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    testWidgets('Meet rail uses overlay without resizing board at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = StudioState()..loading = false;
      await tester.pumpWidget(
        MaterialApp(home: StudioScreen(initialState: state)),
      );
      await tester.pump();
      final board = find.byKey(const ValueKey('studio-board-space'));
      final before = tester.getRect(board);
      expect(find.byKey(const Key('studio-meet-rail')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('studio-meet-rail'))).width,
        52,
      );
      final toggle = find.byTooltip('Google Meet');
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(tester.getRect(board), before);
      expect(
        tester.getRect(find.byType(StudioInspectorPanel)).right,
        lessThanOrEqualTo(size.width - 52),
      );
      await tester.tap(find.byTooltip('Đóng panel Meet'));
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsNothing);
      expect(tester.getRect(board), before);
      await tester.tap(toggle);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsNothing);
      await tester.tap(toggle);
      await tester.pump();
      await tester.tapAt(
        tester.getTopLeft(find.byKey(const Key('dismiss-meet-panel'))) +
            const Offset(2, 80),
      );
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsNothing);
      expect(tester.getRect(board), before);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  for (final width in [900.0, 1440.0]) {
    testWidgets('teaching opens Meet panel and can reopen it at width $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = StudioState()..loading = false;
      await tester.pumpWidget(
        MaterialApp(
          home: StudioScreen(
            initialState: state,
            teachingTarget: const TeachingTarget(
              title: 'Lớp thử',
              courseId: 'course',
              meetingUrl: 'https://meet.google.com/abc-defg-hij',
              teacherEmail: 'teacher@example.com',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsOneWidget);
      final toggle = find.byTooltip('Google Meet');
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsNothing);
      await tester.tap(toggle);
      await tester.pump();
      expect(find.byType(StudioInspectorPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await MeetAutomationService().leaveClassroom();
    });
  }
}
