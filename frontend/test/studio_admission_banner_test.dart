import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/widgets/studio/studio_admission_banner.dart';

void main() {
  testWidgets('A request disappearing during pointer down cannot approve the next student', (tester) async {
    int clicks=0;
    final service=MeetAutomationService.forTesting(executeScript:(_) async { clicks++; return '{"status":"NOT_FOUND"}'; });
    service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
    final base={'documentId':'doc-pointer','url':service.meetingUrl};
    service.receiveBridgeMessage({...base,'type':'ADMISSION_BRIDGE_READY','payload':{'version':1},'sequence':1});
    service.receiveBridgeMessage({...base,'type':'ADMISSION_QUEUE','payload':{'requests':[{'id':'a','name':'Alice'},{'id':'b','name':'Bob'}],'unknownCount':0},'sequence':2});
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[StudioAdmissionBanner(meetService:service)]))));
    final gesture=await tester.startGesture(tester.getCenter(find.text('Cho vào').first));
    service.receiveBridgeMessage({...base,'type':'ADMISSION_QUEUE','payload':{'requests':[{'id':'b','name':'Bob'}],'unknownCount':0},'sequence':3});
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(clicks,0);
    expect(service.admissionRequests.single.name,'Bob');
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
  testWidgets('Notice fits a narrow board and offers fallback for unreadable identities', (tester) async {
    tester.view.physicalSize=const Size(320,480);
    tester.view.devicePixelRatio=1;
    addTearDown(() => tester.view.resetPhysicalSize());
    final service=MeetAutomationService.forTesting();
    service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
    final base={'documentId':'doc-small','url':service.meetingUrl};
    service.receiveBridgeMessage({...base,'type':'ADMISSION_BRIDGE_READY','payload':{'version':1},'sequence':1});
    service.receiveBridgeMessage({...base,'type':'ADMISSION_QUEUE','payload':{'requests':[],'unknownCount':2},'sequence':2});
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:Stack(children:[StudioAdmissionBanner(meetService:service)]))));
    expect(find.text('Mở panel Meet'),findsOneWidget);
    expect(find.text('Cho vào'),findsNothing);
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
  testWidgets(
    'Notice names each student, disables only selected action and waits for confirmation',
    (tester) async {
      String? attempt;
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          final match = RegExp(r'\.admit\((\{.*\})\) :').firstMatch(script)!;
          attempt = (jsonDecode(match.group(1)!) as Map)['attemptId'] as String;
          return '{"status":"PENDING"}';
        },
      );
      service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
      Map<String, dynamic> msg(String type, Object payload, int seq) => {
        'type': type,
        'payload': payload,
        'documentId': 'doc-test',
        'sequence': seq,
        'url': service.meetingUrl,
      };
      service.receiveBridgeMessage(
        msg('ADMISSION_BRIDGE_READY', {'version': 1}, 1),
      );
      service.receiveBridgeMessage(
        msg('ADMISSION_QUEUE', {
          'requests': [
            {'id': 'student-a', 'name': 'Nguyễn Văn A'},
            {'id': 'student-b', 'name': 'Trần Thị B'},
          ],
          'unknownCount': 0,
        }, 2),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Positioned.fill(
                  child: Center(child: Text('Bảng giảng dạy')),
                ),
                StudioAdmissionBanner(meetService: service),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Bảng giảng dạy'), findsOneWidget);
      expect(find.text('Cho vào'), findsNWidgets(2));
      await tester.tap(find.text('Cho vào').first);
      await tester.pump();
      expect(find.text('Đang chờ Meet xác nhận…'), findsOneWidget);
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      service.receiveBridgeMessage(
        msg('ADMISSION_RESULT', {
          'requestId': 'student-a',
          'attemptId': attempt,
          'status': 'UNCONFIRMED',
        }, 3),
      );
      await tester.pump();
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Đóng thông báo'), findsOneWidget);
      expect(find.textContaining('Meet đã xác nhận'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );
}
