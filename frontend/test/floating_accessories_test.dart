import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/floating_pip.dart';
import 'package:teaching_companion/widgets/floating_timer.dart';
import 'package:teaching_companion/widgets/drawer_questions.dart';
import 'package:teaching_companion/widgets/stage_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 05: Floating Studio Accessories', () {
    testWidgets('FloatingPip renders webcam card and handles toggle/minimize', (
      tester,
    ) async {
      final studio = StudioState();
      expect(studio.showCameraPip, isFalse);

      studio.toggleCameraPip();
      expect(studio.showCameraPip, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [FloatingPip(studio: studio)]),
          ),
        ),
      );
      await tester.pump();

      // Normal card state
      expect(find.text('Webcam GV'), findsOneWidget);
      expect(find.text('GV'), findsOneWidget);
      expect(find.text('1080p · 30fps'), findsOneWidget);
      expect(find.text('Mic ON'), findsOneWidget);

      // Minimize PIP
      studio.togglePipMinimized();
      await tester.pump();
      expect(find.byIcon(Icons.open_in_full), findsOneWidget);
      expect(find.text('1080p · 30fps'), findsNothing);

      // Restore PIP
      studio.togglePipMinimized();
      await tester.pump();
      expect(find.text('1080p · 30fps'), findsOneWidget);

      // Hide PIP
      studio.toggleCameraPip();
      await tester.pump();
      expect(find.text('Webcam GV'), findsNothing);

      studio.dispose();
    });

    testWidgets('FloatingTimer displays MM:SS and handles controls', (
      tester,
    ) async {
      final studio = StudioState();
      studio.setTimerSeconds(120); // 02:00

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: FloatingTimer(studio: studio)),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('02:00'), findsOneWidget);

      // Tap timer pill to expand popover
      await tester.tap(find.text('02:00'));
      await tester.pump();

      expect(find.text('5p'), findsOneWidget);
      expect(find.text('10p'), findsOneWidget);
      expect(find.text('+1p'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);

      // Tap 5p preset
      await tester.tap(find.text('5p'));
      await tester.pump();
      expect(studio.seconds, 300);
      expect(find.text('05:00'), findsOneWidget);

      // Start timer
      await tester.tap(find.text('Bắt đầu'));
      await tester.pump();
      expect(studio.timerRunning, isTrue);
      expect(find.text('Tạm dừng'), findsOneWidget);

      // Reset timer
      await tester.tap(find.text('Đặt lại'));
      await tester.pump();
      expect(studio.timerRunning, isFalse);

      studio.dispose();
    });

    testWidgets('DrawerQuestions slides out and shows document manager', (
      tester,
    ) async {
      final studio = StudioState();
      expect(studio.showQuestionsDrawer, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [DrawerQuestions(studio: studio)]),
          ),
        ),
      );
      await tester.pump();

      // Closed state: pull tab is visible
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Open drawer
      studio.setQuestionsDrawer(true);
      await tester.pumpAndSettle();

      expect(find.text('Tài liệu giảng dạy'), findsOneWidget);
      expect(find.text('+ Nhập tệp'), findsOneWidget);

      // Close drawer with close icon button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(studio.showQuestionsDrawer, isFalse);

      studio.dispose();
    });

    testWidgets('StageContainer contains Drawer and PIP in 16:9 stage', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StageContainer(studio: studio)),
        ),
      );
      await tester.pump();

      expect(find.byType(FloatingPip), findsOneWidget);
      expect(find.byType(DrawerQuestions), findsOneWidget);

      studio.dispose();
    });
  });
}
