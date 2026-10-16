import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

void main() {
  const url = 'https://meet.google.com/abc-defg-hij';
  late MeetAutomationService service;
  setUp(() {
    service = MeetAutomationService.forTesting();
    service.setMeetingUrl(url);
    service.linkedTeacherEmail = 'teacher@example.com';
  });
  tearDown(() => service.dispose());
  void account(String? email, {String room = url}) =>
      service.receiveBridgeMessage({
        'type': 'MEET_ACCOUNT',
        'payload': {'url': room, 'email': email},
      });
  void joined() => service.receiveBridgeMessage({
    'type': 'MEET_JOINED',
    'payload': {'url': url},
  });
  test(
    'unknown account needs teacher acknowledgement plus actual call evidence',
    () {
      service.confirmMeetAccount();
      expect(service.isHostJoined, isFalse);
      joined();
      expect(service.isHostJoined, isTrue);
      service.clearMeetingEvents();
      joined();
      expect(service.isHostJoined, isFalse);
      service.confirmMeetAccount();
      expect(service.isHostJoined, isTrue);
    },
  );
  test(
    'mismatched account cannot be overridden; matching alone is not a call',
    () {
      account('other@example.com');
      joined();
      service.confirmMeetAccount();
      expect(service.accountMismatch, isTrue);
      expect(service.isHostJoined, isFalse);
      account('TEACHER@example.com');
      expect(service.isHostJoined, isTrue);
      service.clearMeetingEvents();
      account('teacher@example.com');
      expect(service.isHostJoined, isFalse);
    },
  );
  test(
    'leaving the call clears join evidence even when account is unchanged',
    () {
      account('teacher@example.com');
      joined();
      expect(service.isHostJoined, isTrue);
      service.receiveBridgeMessage({
        'type': 'MEET_ACCOUNT',
        'payload': {
          'url': url,
          'email': 'teacher@example.com',
          'inCall': false,
        },
      });
      expect(service.isHostJoined, isFalse);
      service.confirmMeetAccount();
      expect(service.isHostJoined, isFalse);
    },
  );
  test(
    'different room, insecure origin and room/account changes cannot reuse acknowledgement',
    () {
      account(
        'teacher@example.com',
        room: 'https://meet.google.com/klm-nopq-rst',
      );
      account(
        'teacher@example.com',
        room: 'http://meet.google.com/abc-defg-hij',
      );
      expect(service.meetAccountEmail, isNull);
      service.confirmMeetAccount();
      joined();
      service.setMeetingUrl('https://meet.google.com/klm-nopq-rst');
      expect(service.needsAccountConfirmation, isTrue);
      expect(service.isHostJoined, isFalse);
      service.confirmMeetAccount();
      service.linkedTeacherEmail = 'new@example.com';
      expect(service.needsAccountConfirmation, isTrue);
    },
  );
}
