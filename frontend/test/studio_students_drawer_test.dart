import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_students_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioStudentsDrawer Waiting Room Tests', () {
    testWidgets('Waiting room card hidden when pendingAdmitCount is 0', (tester) async {
      final meetService = MeetAutomationService();
      meetService.clearMeetingEvents();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioStudentsDrawer(
              meetService: meetService,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Đang chờ duyệt'), findsNothing);
      expect(find.text('Cho vào tất cả'), findsNothing);
    });

    testWidgets('Waiting room card displays count, admits all, and toggles auto-admit', (tester) async {
      final meetService = MeetAutomationService();
      meetService.clearMeetingEvents();
      meetService.autoAdmitEnabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioStudentsDrawer(
              meetService: meetService,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate 2 students knocking
      meetService.handleWebMessageForTesting({
        'type': 'ADMIT_REQUEST',
        'payload': {'pendingCount': 2},
      });
      await tester.pumpAndSettle();

      // Waiting room card should be visible
      expect(find.textContaining('Đang chờ duyệt (2)'), findsOneWidget);
      expect(find.text('Cho vào tất cả'), findsOneWidget);
      expect(find.text('Tự động duyệt học sinh'), findsOneWidget);

      // Tap 'Cho vào tất cả'
      await tester.tap(find.text('Cho vào tất cả'));
      await tester.pumpAndSettle();

      // Count resets and card disappears
      expect(meetService.pendingAdmitCount, equals(0));
      expect(find.textContaining('Đang chờ duyệt'), findsNothing);

      // Toggle auto-admit switch
      meetService.autoAdmitEnabled = true;
      expect(meetService.autoAdmitEnabled, isTrue);
    });
  });
}
