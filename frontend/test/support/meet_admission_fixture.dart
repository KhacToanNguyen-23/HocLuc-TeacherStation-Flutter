import 'dart:convert';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';

const room = 'https://meet.google.com/abc-defg-hij';
Map<String, dynamic> message(
  String type,
  Object payload, {
  String doc = 'doc-one',
  int sequence = 1,
  String url = room,
}) => {
  'type': type,
  'payload': payload,
  'documentId': doc,
  'sequence': sequence,
  'url': url,
};
void seedAdmissions(
  MeetAutomationService service, {
  List<Map<String, dynamic>>? requests,
}) {
  service.setMeetingUrl(room);
  service.receiveBridgeMessage(
    message('ADMISSION_BRIDGE_READY', {'version': 1}),
  );
  service.receiveBridgeMessage(
    message('ADMISSION_QUEUE', {
      'requests':
          requests ??
          [
            {'id': 'request-a', 'name': 'Nguyễn Văn A'},
            {'id': 'request-b', 'name': 'Trần Thị B'},
          ],
      'unknownCount': 0,
    }, sequence: 2),
  );
}

Map<String, dynamic> command(String script) =>
    jsonDecode(RegExp(r'\.admit\((\{.*\})\) :').firstMatch(script)!.group(1)!)
        as Map<String, dynamic>;

