import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_inspector_panel.dart';

void main() {
  testWidgets('StudioInspectorPanel renders live cockpit tabs and chat', (tester) async {
    final studio = StudioState();
    final notesController = TextEditingController();
    final questionController = TextEditingController();
    final endpointController = TextEditingController();

    final meetService = MeetAutomationService();
    meetService.setMeetingUrl('meet.google.com/test-room-123');

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

    // Initial tab 0: Trực tiếp
    expect(find.text('Trực tiếp'), findsOneWidget);
    expect(find.text('Cài đặt & Ghi chú'), findsOneWidget);
    expect(find.text('Đang kết nối Google Meet'), findsOneWidget);
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('Tắt tiếng cả lớp'), findsOneWidget);

    // Test send message via input
    await tester.enterText(find.byType(TextField).first, 'Chào các em!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chào các em!'), findsOneWidget);
    expect(find.text('Tôi (Giáo viên)'), findsOneWidget);

    // Switch to Tab 1: Cài đặt & Ghi chú
    await tester.tap(find.text('Cài đặt & Ghi chú'));
    await tester.pumpAndSettle();

    expect(find.text('ĐẦU RA CHO MEETING'), findsOneWidget);
    expect(find.text('Khung trình bày bảng vẽ'), findsOneWidget);

    notesController.dispose();
    questionController.dispose();
    endpointController.dispose();
  });
}
