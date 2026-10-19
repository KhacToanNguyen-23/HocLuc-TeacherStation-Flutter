import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

void main() {
  test(
    'a failed renderer cannot prevent leaving and clearing the room',
    () async {
      final service = MeetAutomationService.forTesting(
        executeScript: (_) async {
          throw StateError('Renderer is gone');
        },
      );
      service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
      await service.pauseSession();
      await service.leaveClassroom(endForEveryone: false);
      expect(service.meetingUrl, isNull);
      expect(service.status, MeetStatus.idle);
      expect(service.isScreenSharing, isFalse);
      service.dispose();
    },
  );

  test('sharing state accepts only the active official Meet room', () {
    final service = MeetAutomationService.forTesting();
    service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
    void report(String url, bool active) => service.receiveBridgeMessage({
      'type': 'MEET_SCREEN_SHARE_STATE',
      'url': url,
      'payload': {'active': active},
    });
    report('https://meet.google.com/klm-nopq-rst', true);
    expect(service.isScreenSharing, isFalse);
    report('https://example.com/abc-defg-hij', true);
    expect(service.isScreenSharing, isFalse);
    report('https://meet.google.com/abc-defg-hij', true);
    expect(service.isScreenSharing, isTrue);
    report('https://meet.google.com/abc-defg-hij', false);
    expect(service.isScreenSharing, isFalse);
    service.dispose();
  });

  test('pause stops real display tracks and clear resets status', () async {
    final commands = <String>[];
    final service = MeetAutomationService.forTesting(
      executeScript: (script) async {
        commands.add(script);
        return 'null';
      },
    );
    service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
    service.receiveBridgeMessage({
      'type': 'MEET_SCREEN_SHARE_STATE',
      'url': service.meetingUrl,
      'payload': {'active': true},
    });
    await service.pauseSession();
    expect(commands.single, contains('HocLucScreenShare.stop()'));
    service.clearMeetingEvents();
    expect(service.isScreenSharing, isFalse);
    service.dispose();
  });
}
