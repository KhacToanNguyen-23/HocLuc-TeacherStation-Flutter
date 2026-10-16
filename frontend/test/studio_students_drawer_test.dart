import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_students_drawer.dart';
import 'support/meet_admission_fixture.dart';

void main() {
  testWidgets('Moderation opens real Meet without changing participant state', (
    tester,
  ) async {
    final service = MeetAutomationService.forTesting();
    var opened = false;
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
          body: StudioStudentsDrawer(
            meetService: service,
            onClose: () {},
            onOpenMeet: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('Học sinh đã vào'), findsOneWidget);
    expect(find.byTooltip('Mở mic cho học sinh'), findsNothing);
    expect(find.byTooltip('Mời học sinh ra khỏi phòng'), findsNothing);
    await tester.tap(find.byTooltip('Mở Google Meet để điều khiển học sinh'));
    expect(opened, isTrue);
    expect(service.participants.single.isMuted, isFalse);
    expect(find.text('Tự động duyệt học sinh'), findsNothing);
    expect(find.text('Cho vào tất cả'), findsNothing);
    expect(service.pendingAdmitCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
}
