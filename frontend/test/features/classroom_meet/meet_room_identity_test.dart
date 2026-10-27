import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const room = 'https://meet.google.com/abc-defg-hij';
  const document = 'https://meet.google.com/meet/abc-defg-hij';

  test(
    'both official Meet routes identify a room without accepting lookalikes',
    () {
      expect(MeetAutomationService.isOfficialMeetingUrl(room), true);
      expect(MeetAutomationService.isOfficialMeetingUrl(document), true);
      expect(
        MeetAutomationService.isOfficialMeetingUrl('$document?authuser=1'),
        true,
      );
      for (final url in [
        'https://meet.google.com/meet/abc-defg-hij/extra',
        'https://meet.google.com/other/abc-defg-hij',
        'https://meet.google.com.evil.test/meet/abc-defg-hij',
        'http://meet.google.com/meet/abc-defg-hij',
        'https://meet.google.com:444/meet/abc-defg-hij',
        'https://user@meet.google.com/meet/abc-defg-hij',
      ]) {
        expect(MeetAutomationService.isOfficialMeetingUrl(url), false);
      }
    },
  );

  test(
    'redirected document joins and prepares chat with its actual URL',
    () async {
      final commands = <Map<String, dynamic>>[];
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          if (script.contains('.endTutorObservation(') ||
              script.contains('.cancelTutor(')) {
            return 'false';
          }
          final value =
              jsonDecode(
                    script.substring(
                      script.indexOf('({') + 1,
                      script.indexOf(') :'),
                    ),
                  )
                  as Map<String, dynamic>;
          commands.add(value);
          return jsonEncode({...value, 'status': 'READY'});
        },
      );
      service.setMeetingUrl(room);
      service.handleWebMessageForTesting({
        'type': 'MEET_BRIDGE_READY',
        'documentId': 'doc',
        'url': document,
      });
      service.handleWebMessageForTesting({
        'type': 'MEET_JOINED',
        'documentId': 'doc',
        'url': document,
        'payload': {'url': document},
      });
      expect(service.isBridgeReady, true);
      expect(service.isHostJoined, true);
      expect(await service.beginTutorObservation(), true);
      expect(commands.single['url'], document);
      expect(service.meetingUrl, room);
      service.handleWebMessageForTesting({
        'type': 'MEET_SCREEN_SHARE_STATE',
        'documentId': 'doc',
        'url': document,
        'payload': {'active': true},
      });
      expect(service.isScreenSharing, true);
      service.dispose();
    },
  );

  test('another room cannot supply readiness through the new route', () {
    final service = MeetAutomationService.forTesting();
    service.setMeetingUrl(room);
    service.handleWebMessageForTesting({
      'type': 'MEET_BRIDGE_READY',
      'documentId': 'other',
      'url': 'https://meet.google.com/meet/xyz-abcd-efg',
    });
    expect(service.isBridgeReady, false);
    expect(service.isHostJoined, false);
    service.dispose();
  });

  test('pasting the new route retains the canonical stored room link', () {
    final service = MeetAutomationService.forTesting();
    service.setMeetingUrl(document);
    expect(service.meetingUrl, room);
    service.dispose();
  });
}
