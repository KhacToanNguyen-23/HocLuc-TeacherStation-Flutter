import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_students_drawer.dart';
import 'support/meet_admission_fixture.dart';

void main() {
  testWidgets('Participant controls remain; approvals live in global menu', (
    tester,
  ) async {
    final service = MeetAutomationService.forTesting();
    seedAdmissions(service);
    service.receiveBridgeMessage({
      'type': 'PARTICIPANTS_UPDATE',
      'payload': [
        {'id': 'joined', 'name': 'Học sinh đã vào', 'isMuted': false},
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudioStudentsDrawer(meetService: service, onClose: () {}),
        ),
      ),
    );
    expect(find.text('Học sinh đã vào'), findsOneWidget);
    expect(find.text('Tự động duyệt học sinh'), findsNothing);
    expect(find.text('Cho vào tất cả'), findsNothing);
    expect(service.pendingAdmitCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
