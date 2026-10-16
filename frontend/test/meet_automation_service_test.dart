import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

void main() {
  group('MeetAutomationService Tests', () {
    test('room change invalidates and clears the previous roster', () {
      final service = MeetAutomationService.forTesting();
      service.receiveBridgeMessage({'type': 'PARTICIPANTS_UPDATE', 'payload': [
        {'id': 'old', 'name': 'Old room'},
      ]});
      expect(service.participantsFresh, isTrue);
      service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
      expect(service.participantsFresh, isFalse);
      expect(service.participants, isEmpty);
      service.dispose();
    });
    test('Initial state is clean', () {
      final service = MeetAutomationService();
      expect(service.messages, isEmpty);
      expect(service.raisedHands, isEmpty);
      expect(service.pendingAdmitCount, equals(0));
      expect(service.isBridgeReady, isFalse);
      expect(service.needsGoogleLogin, isFalse);
    });

    test('Direct URL sets status to ready', () {
      final service = MeetAutomationService();
      service.setMeetingUrl('meet.google.com/test-room-abc');
      expect(service.hasRoom, isTrue);
      expect(
        service.meetingUrl,
        equals('https://meet.google.com/test-room-abc'),
      );
      expect(service.status, equals(MeetStatus.ready));
    });

    test('chat without Meet does not fabricate a sent message', () async {
      final service = MeetAutomationService.forTesting();
      expect(await service.sendChatMessage('Xin chào'), isFalse);
      expect(service.messages, isEmpty);
      service.dispose();
    });

    test('a successful chat click is not a delivery confirmation', () async {
      final service = MeetAutomationService.forTesting(
        executeScript: (_) async => 'true',
      );
      expect(await service.sendChatMessage('Xin chào'), isTrue);
      expect(service.messages, isEmpty);
      service.receiveBridgeMessage({
        'type': 'CHAT_MESSAGE',
        'payload': {
          'id': 'confirmed',
          'sender': 'Bạn',
          'text': 'Xin chào',
          'isSelf': true,
        },
      });
      expect(service.messages.single.text, 'Xin chào');
      service.dispose();
    });

    test('clearMeetingEvents resets live state', () {
      final service = MeetAutomationService();
      service.clearMeetingEvents();
      expect(service.messages, isEmpty);
      expect(service.raisedHands, isEmpty);
      expect(service.pendingAdmitCount, equals(0));
      expect(service.isBridgeReady, isFalse);
    });

    test('linked classes prevent auto-admit and restore legacy preference', () {
      final service = MeetAutomationService();
      service.autoAdmitEnabled = true;
      service.linkedTeacherEmail = 'teacher@example.com';
      expect(service.autoAdmitEnabled, isFalse);
      service.autoAdmitEnabled = true;
      expect(service.autoAdmitEnabled, isFalse);
      service.linkedTeacherEmail = null;
      expect(service.autoAdmitEnabled, isTrue);
    });

    test(
      'room URL alone is preparation; joined event must match exact room',
      () {
        final service = MeetAutomationService();
        service.clearMeetingEvents();
        service.setMeetingUrl('https://meet.google.com/abc-defg-hij');
        expect(service.isHostJoined, isFalse);
        service.handleWebMessageForTesting({
          'type': 'MEET_JOINED',
          'payload': {'url': 'https://meet.google.com/klm-nopq-rst'},
        });
        expect(service.isHostJoined, isFalse);
        service.handleWebMessageForTesting({
          'type': 'MEET_JOINED',
          'payload': {'url': 'https://meet.google.com/abc-defg-hij?authuser=0'},
        });
        expect(service.isHostJoined, isTrue);
        service.clearMeetingEvents();
      },
    );
  });
}
