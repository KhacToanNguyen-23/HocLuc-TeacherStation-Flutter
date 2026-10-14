import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Clicks only selected ID; duplicate taps share an attempt; click is not success',
    () async {
      final commands = <Map<String, dynamic>>[];
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          commands.add(command(script));
          return jsonEncode({'status': 'PENDING'});
        },
      );
      seedAdmissions(service);
      final first = service.admitRequest('request-a');
      final duplicate = service.admitRequest('request-a');
      expect(identical(first, duplicate), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(commands.length, 1);
      expect(commands.single['requestId'], 'request-a');
      expect(service.pendingAdmitCount, 2);
      service.receiveBridgeMessage(
        message('ADMISSION_QUEUE', {
          'requests': [
            {'id': 'request-b', 'name': 'Trần Thị B'},
          ],
          'unknownCount': 0,
        }, sequence: 3),
      );
      expect(
        service.pendingAdmitCount,
        2,
      ); // vanished request is still awaiting proof
      service.receiveBridgeMessage(
        message('ADMISSION_RESULT', {
          'requestId': 'request-a',
          'attemptId': commands.single['attemptId'],
          'status': 'CONFIRMED',
        }, sequence: 4),
      );
      expect(await first, isTrue);
      expect(await duplicate, isTrue);
      expect(service.admissionRequests.single.id, 'request-b');
      service.dispose();
    },
  );

  test(
    'Transport failures, plain booleans and timeout retain notice without success',
    () async {
      final service = MeetAutomationService.forTesting(
        executeScript: (_) async => 'true',
      );
      seedAdmissions(service);
      expect(await service.admitRequest('request-a'), isFalse);
      expect(service.pendingAdmitCount, 2);
      expect(service.admissionError('request-a'), isNotNull);
      service.dispose();
      final timeout = MeetAutomationService.forTesting(
        executeScript: (_) async => jsonEncode({'status': 'PENDING'}),
        admissionTimeout: const Duration(milliseconds: 20),
      );
      seedAdmissions(timeout);
      expect(await timeout.admitRequest('request-a'), isFalse);
      expect(timeout.admissionRequests.length, 2);
      expect(timeout.admissionError('request-a'), contains('Chưa xác nhận'));
      timeout.dispose();
    },
  );

  test(
    'Stale documents, rooms, revisions and attempt results cannot alter current queue',
    () async {
      final commands = <Map<String, dynamic>>[];
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          commands.add(command(script));
          return jsonEncode({'status': 'PENDING'});
        },
      );
      seedAdmissions(service);
      final pending = service.admitRequest('request-a');
      await Future<void>.delayed(Duration.zero);
      for (final invalid in [
        message('ADMISSION_RESULT', {
          'requestId': 'request-a',
          'attemptId': commands.single['attemptId'],
          'status': 'CONFIRMED',
        }, doc: 'old-doc'),
        message('ADMISSION_RESULT', {
          'requestId': 'request-a',
          'attemptId': 'old-attempt',
          'status': 'CONFIRMED',
        }),
        message('ADMISSION_QUEUE', {
          'requests': [],
          'unknownCount': 0,
        }, sequence: 1),
        message(
          'ADMISSION_QUEUE',
          {'requests': [], 'unknownCount': 0},
          sequence: 100,
          url: 'https://meet.google.com/xyz-abcd-efg',
        ),
      ]) {
        service.receiveBridgeMessage(invalid);
      }
      expect(service.pendingAdmitCount, 2);
      service.setMeetingUrl('https://meet.google.com/xyz-abcd-efg');
      expect(await pending, isFalse);
      expect(service.pendingAdmitCount, 0);
      service.dispose();
    },
  );

  test(
    'Same-name requests without distinguishing detail are never auto-clicked',
    () async {
      int clicks = 0;
      final service = MeetAutomationService.forTesting(
        executeScript: (_) async {
          clicks++;
          return jsonEncode({'status': 'PENDING'});
        },
      );
      seedAdmissions(
        service,
        requests: [
          {'id': 'one', 'name': 'Minh'},
          {'id': 'two', 'name': 'Minh'},
        ],
      );
      expect(await service.admitRequest('one'), isFalse);
      expect(clicks, 0);
      expect(service.admissionError('one'), contains('trùng tên'));
      service.dispose();
    },
  );

  test(
    'Unknown identities only show a fallback; clearing a queue reports zero',
    () {
      final service = MeetAutomationService.forTesting();
      seedAdmissions(service);
      service.receiveBridgeMessage(
        message('ADMISSION_QUEUE', {
          'requests': [],
          'unknownCount': 2,
        }, sequence: 3),
      );
      expect(service.admissionRequests, isEmpty);
      expect(service.unknownAdmissionCount, 2);
      service.receiveBridgeMessage(
        message('ADMISSION_QUEUE', {
          'requests': [],
          'unknownCount': 0,
        }, sequence: 4),
      );
      expect(service.pendingAdmitCount, 0);
      service.dispose();
    },
  );
}
