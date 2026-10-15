import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/meet_events.dart';
import 'package:teaching_companion/services/meet_bridge_script.dart';
import 'package:teaching_companion/services/meet_admission_bridge_script.dart';

void main() {
  group('MeetBridgeScript and Parser Tests', () {
    test('MeetBridgeScript contains valid javascript syntax markers', () {
      expect(MeetBridgeScript.script, contains('window.MeetBridge'));
      expect(MeetBridgeScript.script, contains('sendToFlutter'));
      expect(MeetBridgeScript.script, contains('MutationObserver'));
      expect(MeetBridgeScript.script, contains('scanChatMessages'));
      expect(MeetBridgeScript.script, contains('admitAll'));
      expect(MeetBridgeScript.script, contains('muteAll'));
      expect(MeetBridgeScript.script, contains('startPresenting'));
      expect(MeetBridgeScript.script, contains('sendChat'));
      expect(MeetBridgeScript.script, contains('cho phép'));
      expect(MeetAdmissionBridgeScript.script, contains('chấp nhận'));
      expect(MeetBridgeScript.script, contains(r"text.split('\n')"));
      expect(MeetBridgeScript.script, contains('rời khỏi'));
      expect(MeetBridgeScript.script, contains('leave call'));
    });

    test('Parses CHAT_MESSAGE json from bridge', () {
      const rawJson = '''
      {
        "type": "CHAT_MESSAGE",
        "payload": {
          "id": "NguyenVanA_Hello_12:30",
          "sender": "Nguyễn Văn A",
          "text": "Thầy ơi cho em hỏi câu 3 với ạ!",
          "time": "12:30"
        }
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(rawJson);
      expect(data['type'], equals('CHAT_MESSAGE'));

      final chat = MeetChatMessage.fromJson(data['payload']);
      expect(chat.sender, equals('Nguyễn Văn A'));
      expect(chat.text, equals('Thầy ơi cho em hỏi câu 3 với ạ!'));
      expect(chat.time, equals('12:30'));
      expect(chat.isSelf, isFalse);
    });

    test('Parses RAISE_HANDS_UPDATE json from bridge', () {
      const rawJson = '''
      {
        "type": "RAISE_HANDS_UPDATE",
        "payload": {
          "count": 2,
          "names": ["Trần Thị B", "Lê Văn C"]
        }
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(rawJson);
      expect(data['type'], equals('RAISE_HANDS_UPDATE'));

      final event = MeetRaisedHandEvent.fromJson(data['payload']);
      expect(event.count, equals(2));
      expect(event.names, containsAll(['Trần Thị B', 'Lê Văn C']));
    });

    test('Parses ADMIT_REQUEST json from bridge', () {
      const rawJson = '''
      {
        "type": "ADMIT_REQUEST",
        "payload": {
          "pendingCount": 3
        }
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(rawJson);
      expect(data['type'], equals('ADMIT_REQUEST'));

      final event = MeetAdmissionEvent.fromJson(data['payload']);
      expect(event.pendingCount, equals(3));
    });

    test('Parses MEET_MEDIA_DEVICE_SELECTED json from bridge', () {
      const rawJson = '''
      {
        "type": "MEET_MEDIA_DEVICE_SELECTED",
        "payload": {
          "hasHocLucCam": true,
          "hasHocLucMic": true,
          "camLabel": "HocLuc Studio Camera",
          "micLabel": "HocLuc Virtual Mic"
        }
      }
      ''';

      final Map<String, dynamic> data = jsonDecode(rawJson);
      expect(data['type'], equals('MEET_MEDIA_DEVICE_SELECTED'));
      expect(data['payload']['hasHocLucCam'], isTrue);
      expect(data['payload']['hasHocLucMic'], isTrue);
      expect(data['payload']['camLabel'], equals('HocLuc Studio Camera'));
      expect(data['payload']['micLabel'], equals('HocLuc Virtual Mic'));

      expect(MeetBridgeScript.script, contains('setMicMute'));
      expect(MeetBridgeScript.script, contains('setCamMute'));
      expect(MeetBridgeScript.script, contains('MEET_MEDIA_DEVICE_SELECTED'));
    });
  });
}
