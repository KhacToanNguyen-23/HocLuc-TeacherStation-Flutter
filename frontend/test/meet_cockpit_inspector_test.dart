import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_inspector_panel.dart';
import 'package:teaching_companion/widgets/studio/studio_meet_cockpit_tab.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';

void main() {
  testWidgets('chat preserves a newer draft and prevents duplicate requests', (tester) async {
    final response = Completer<String>();
    var sends = 0;
    final service = MeetAutomationService.forTesting(executeScript: (_) {
      sends++;
      return response.future;
    });
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StudioMeetCockpitTab(
      meetService: service, authService: GoogleMeetAuthService(),
    ))));
    final input = find.byType(TextField);
    await tester.enterText(input, 'Tin thứ nhất');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    final field = tester.widget<TextField>(input);
    field.onSubmitted!('Tin thứ nhất');
    expect(sends, 1);
    await tester.enterText(input, 'Tin mới đang gõ');
    response.complete('true');
    await tester.pump();
    expect(tester.widget<TextField>(input).controller!.text, 'Tin mới đang gõ');
    expect(service.messages, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
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
    expect(find.text('Chuẩn bị Google Meet'), findsOneWidget);
    expect(find.text('LIVE'), findsNothing);
    expect(find.text('Tắt tiếng trong Google Meet'), findsOneWidget);

    // Test send message via input
    await tester.enterText(find.byType(TextField).first, 'Chào các em!');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Chào các em!'), findsOneWidget);
    expect(find.text('Tôi (Giáo viên)'), findsNothing);
    expect(meetService.messages, isEmpty);
    expect(find.text('Chưa gửi được. Mở Chat trong Google Meet để gửi tin nhắn.'), findsOneWidget);

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
