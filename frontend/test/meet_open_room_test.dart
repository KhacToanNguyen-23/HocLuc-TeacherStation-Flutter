import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/services/local_service.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final auth = GoogleMeetAuthService();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth.signOut();
    auth.connectGoogleSession(sessionId: 'local-grant', email: 'host@example.com');
  });
  tearDown(() => auth.signOut());

  MeetAutomationService service(Map<String, dynamic> result, List<http.Request> requests) {
    return MeetAutomationService.forTesting(localServiceFactory: () => LocalService(
      base: 'http://127.0.0.1:47831',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/bootstrap') return http.Response('{"token":"local-test"}', 200);
        expect(request.url.path, '/api/classroom/create');
        expect(request.headers['X-Companion-Token'], 'local-test');
        return http.Response(jsonEncode(result), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    ));
  }

  test('Room creation uses the grant and API URI, preserving OPEN across lobby/studio navigation', () async {
    final requests = <http.Request>[];
    final meet = service({'success': true, 'id': 'class-123', 'meetingUrl': 'https://meet.google.com/abc-defg-hij', 'accessType': 'OPEN'}, requests);
    await meet.createClassroom(title: 'Toán 12');
    expect(meet.meetingUrl, 'https://meet.google.com/abc-defg-hij');
    expect(meet.accessType, 'OPEN');
    expect(meet.classroomId, 'class-123');
    final payload = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(payload['googleSessionId'], 'local-grant');
    expect(payload['title'], 'Toán 12');
    expect(payload.containsKey('accessToken'), isFalse);
    meet.setMeetingUrl(meet.meetingUrl!);
    expect(meet.accessType, 'OPEN');
    expect(meet.classroomId, 'class-123');
    meet.setMeetingUrl('https://meet.google.com/xyz-abcd-efg');
    expect(meet.accessType, isNull);
    expect(meet.classroomId, isNull);
    meet.dispose();
  });

  test('Policy failure never falls back to /new or reports an OPEN room', () async {
    final requests = <http.Request>[];
    final meet = service({'success': false, 'error': 'Google từ chối phòng OPEN.'}, requests);
    expect(await meet.generateAndJoinRealMeetRoom(), isNull);
    expect(meet.status, MeetStatus.error);
    expect(meet.hasRoom, isFalse);
    expect(meet.accessType, isNull);
    expect(requests.where((r) => r.url.path == '/api/classroom/create').length, 1);
    expect(auth.isGoogleAuthenticated, isTrue);
    meet.dispose();
  });

  test('Non-OPEN responses are rejected and expired grants prompt reconnect', () async {
    final requests = <http.Request>[];
    final restricted = service({'success': true, 'meetingUrl': 'https://meet.google.com/abc-defg-hij', 'accessType': 'RESTRICTED'}, requests);
    await restricted.createClassroom();
    expect(restricted.status, MeetStatus.error);
    expect(restricted.meetingUrl, isNull);
    restricted.dispose();
    final expired = service({'success': false, 'requiresGoogleReconnect': true, 'error': 'Hãy kết nối Google lại.'}, requests);
    await expired.createClassroom();
    expect(auth.isGoogleAuthenticated, isFalse);
    expect(expired.status, MeetStatus.error);
    expired.dispose();
  });

  test('Google panel accepts only official HTTPS Meet rooms', () {
    expect(MeetAutomationService.isOfficialMeetingUrl('https://meet.google.com/abc-defg-hij'), isTrue);
    expect(MeetAutomationService.isOfficialMeetingUrl('https://evil.example/abc-defg-hij'), isFalse);
    expect(MeetAutomationService.isOfficialMeetingUrl('https://meet.google.com.evil.example/abc-defg-hij'), isFalse);
    expect(MeetAutomationService.isOfficialMeetingUrl('http://meet.google.com/abc-defg-hij'), isFalse);
    expect(MeetAutomationService.isOfficialMeetingUrl('https://meet.google.com/new'), isFalse);
  });
}
