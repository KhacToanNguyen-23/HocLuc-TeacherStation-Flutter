import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_inspector_panel.dart';

void main() {
  testWidgets('StudioInspectorPanel renders live cockpit tabs and chat', (
    tester,
  ) async {
    final studio = StudioState();
    final notesController = TextEditingController();
    final questionController = TextEditingController();
    final endpointController = TextEditingController();

    final meetService = MeetAutomationService();
    meetService.setMeetingUrl('https://meet.google.com/abc-defg-hij');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 600,
            child: StudioInspectorPanel(
              studio: studio,
              notesController: notesController,
              questionController: questionController,
              endpointController: endpointController,
              onPreview: () {},
            ),
          ),
        ),
      ),
    );

    // Preserve develop navigation and keep the Meet surface mounted.
    expect(find.text('Trực tiếp'), findsOneWidget);
    expect(find.text('Thiết bị & Cài đặt'), findsOneWidget);
    expect(find.text('Chuẩn bị Google Meet'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Tắt tiếng cả lớp'), findsOneWidget);

    // Test send message via input
    await tester.enterText(find.byType(TextField).first, 'Chào các em!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chào các em!'), findsOneWidget);
    expect(find.text('Tôi (Giáo viên)'), findsOneWidget);

    await tester.tap(find.text('Thiết bị & Cài đặt'));
    await tester.pumpAndSettle();

    expect(find.text('Trợ giảng AI'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Base URL'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ĐẦU RA CHO MEETING'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ĐẦU RA CHO MEETING'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    meetService.clearMeetingEvents();
    studio.dispose();

    notesController.dispose();
    questionController.dispose();
    endpointController.dispose();
  });
}
