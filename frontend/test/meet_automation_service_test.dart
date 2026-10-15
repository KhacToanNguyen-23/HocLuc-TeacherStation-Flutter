import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

void main() {
  group('MeetAutomationService Tests', () {
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
      expect(service.meetingUrl, equals('https://meet.google.com/test-room-abc'));
      expect(service.status, equals(MeetStatus.ready));
    });

    test('sendChatMessage adds self message to messages list', () async {
      final service = MeetAutomationService();
      await service.sendChatMessage('Xin chào cả lớp!');

      expect(service.messages.isNotEmpty, isTrue);
      final lastMsg = service.messages.last;
      expect(lastMsg.text, equals('Xin chào cả lớp!'));
      expect(lastMsg.isSelf, isTrue);
      expect(lastMsg.sender, contains('Tôi'));
    });

    test('clearMeetingEvents resets live state', () {
      final service = MeetAutomationService();
      service.clearMeetingEvents();
      expect(service.messages, isEmpty);
      expect(service.raisedHands, isEmpty);
      expect(service.pendingAdmitCount, equals(0));
      expect(service.isBridgeReady, isFalse);
    });

    test('removeParticipant removes participant and notifies listeners', () async {
      final service = MeetAutomationService();
      service.handleWebMessageForTesting({
        'type': 'PARTICIPANTS_UPDATE',
        'payload': [
          {'id': 'p1', 'name': 'Nguyễn Văn A', 'isMuted': false, 'isHandRaised': true, 'isSpeaking': false},
        ],
      });
      expect(service.participants.length, equals(1));

      await service.removeParticipant('p1', 'Nguyễn Văn A');
      expect(service.participants, isEmpty);
    });
  });
}

