import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_admission_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudioAdmissionBanner Tests', () {
    testWidgets('Hidden when pendingAdmitCount is 0', (tester) async {
      final meetService = MeetAutomationService();
      meetService.clearMeetingEvents();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StudioAdmissionBanner(meetService: meetService),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('xin vào lớp'), findsNothing);
    });

    testWidgets('Displays student count, admits all, and toggles auto-admit', (tester) async {
      final meetService = MeetAutomationService();
      meetService.clearMeetingEvents();
      meetService.autoAdmitEnabled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                StudioAdmissionBanner(meetService: meetService),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no banner
      expect(find.textContaining('xin vào lớp'), findsNothing);

      // Simulate 3 students waiting via ADMIT_REQUEST
      meetService.handleWebMessageForTesting({
        'type': 'ADMIT_REQUEST',
        'payload': {'pendingCount': 3},
      });
      await tester.pumpAndSettle();

      // Banner should now appear with count
      expect(find.textContaining('Có 3 học sinh xin vào lớp'), findsOneWidget);
      expect(find.text('Cho vào tất cả'), findsOneWidget);

      // Tap 'Cho vào tất cả'
      await tester.tap(find.text('Cho vào tất cả'));
      await tester.pumpAndSettle();

      // pendingAdmitCount should be reset to 0 and banner disappears
      expect(meetService.pendingAdmitCount, equals(0));
      expect(find.textContaining('xin vào lớp'), findsNothing);

      // Toggle auto-admit directly via service
      meetService.autoAdmitEnabled = true;
      expect(meetService.autoAdmitEnabled, isTrue);

      // When auto-admit is enabled, incoming ADMIT_REQUEST automatically clears count
      meetService.handleWebMessageForTesting({
        'type': 'ADMIT_REQUEST',
        'payload': {'pendingCount': 2},
      });
      await tester.pumpAndSettle();
      expect(meetService.pendingAdmitCount, equals(0));
    });
  });
}
