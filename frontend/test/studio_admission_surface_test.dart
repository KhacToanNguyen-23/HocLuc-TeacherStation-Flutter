import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/screens/studio_screen.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/stage_container.dart';
import 'package:teaching_companion/widgets/studio/studio_admission_banner.dart';
import 'package:teaching_companion/widgets/studio/studio_question_view.dart';

const room = 'https://meet.google.com/abc-defg-hij';
Map<String, dynamic> message(String type, Object payload, int sequence) => {
  'type': type,
  'payload': payload,
  'sequence': sequence,
  'documentId': 'question-doc',
  'url': room,
};
void seed(MeetAutomationService service) {
  service.setMeetingUrl(room);
  service.receiveBridgeMessage(
    message('ADMISSION_BRIDGE_READY', {'version': 1}, 1),
  );
  service.receiveBridgeMessage(
    message('ADMISSION_QUEUE', {
      'requests': [
        {'id': 'student-a', 'name': 'Nguyễn Văn A'},
        {'id': 'student-b', 'name': 'Trần Thị B'},
      ],
      'unknownCount': 0,
    }, 2),
  );
}

void main() {
  testWidgets(
    'Switching Studio between board and question keeps admission notices',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = MeetAutomationService();
      addTearDown(service.clearMeetingEvents);
      final studio = StudioState()..loading = false;
      seed(service);
      await tester.pumpWidget(
        MaterialApp(home: StudioScreen(initialState: studio)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cho vào'), findsNWidgets(2));
      studio.setView('question');
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Cho vào'), findsNWidgets(2));
      studio.setView('board');
      await tester.pumpAndSettle();
      expect(find.text('Cho vào'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Board still shows admission requests and presentation preview hides them',
    (tester) async {
      final service = MeetAutomationService();
      final studio = StudioState();
      addTearDown(studio.dispose);
      addTearDown(service.clearMeetingEvents);
      seed(service);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StageContainer(studio: studio)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cho vào'), findsNWidgets(2));
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StageContainer(studio: studio, interactive: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StudioAdmissionBanner), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final status in ['CONFIRMED', 'UNCONFIRMED']) {
    testWidgets('Question view keeps student request until $status result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? selected;
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          selected =
              jsonDecode(
                    RegExp(
                      r'\.admit\((\{.*\})\) :',
                    ).firstMatch(script)!.group(1)!,
                  )
                  as Map<String, dynamic>;
          return '{"status":"PENDING"}';
        },
      );
      addTearDown(service.dispose);
      final studio = StudioState();
      addTearDown(studio.dispose);
      seed(service);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioQuestionView(studio: studio, meetService: service),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cho vào'), findsNWidgets(2));
      await tester.tap(find.text('Cho vào').first);
      await tester.pump();
      expect(selected!['requestId'], 'student-a');
      expect(find.text('Đang chờ Meet xác nhận…'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      service.receiveBridgeMessage(
        message('ADMISSION_RESULT', {
          'requestId': 'student-a',
          'attemptId': selected!['attemptId'],
          'status': status,
        }, 3),
      );
      await tester.pump();
      expect(
        find.text('Nguyễn Văn A'),
        status == 'CONFIRMED' ? findsNothing : findsOneWidget,
      );
      expect(find.text('Trần Thị B'), findsOneWidget);
      if (status == 'UNCONFIRMED') {
        expect(find.text('Kiểm tra lại'), findsOneWidget);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioQuestionView(
              studio: studio,
              meetService: service,
              interactive: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StudioAdmissionBanner), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
