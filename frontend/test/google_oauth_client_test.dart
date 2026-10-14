import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/services/google_oauth_client.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/services/local_service.dart';

void main() {
  http.Response jsonResponse(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() { SharedPreferences.setMockInitialValues({}); });

  LocalService backend(String status, List<http.Request> requests, {bool configured = true}) {
    return LocalService(base: 'http://127.0.0.1:47831', client: MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/bootstrap') return http.Response('{"token":"companion-test"}', 200);
      expect(request.headers['X-Companion-Token'], 'companion-test');
      if (request.url.path.endsWith('/start')) {
        return jsonResponse(configured ? {
          'success': true, 'flowId': 'flow-test', 'expiresIn': 300,
          'authorizationUrl': 'https://accounts.google.com/o/oauth2/v2/auth?scope=meetings.space.created&state=test',
        } : {'success': false, 'error': 'Chưa cấu hình Google OAuth.'});
      }
      if (request.url.path.endsWith('/cancel')) return http.Response('{"success":true}', 200);
      return jsonResponse(status == 'CONNECTED' ? {
        'success': true, 'status': 'CONNECTED', 'sessionId': 'opaque-grant',
        'user': {'name': 'Cô Hoa', 'email': 'teacher@example.com', 'avatar': ''},
      } : {'success': false, 'status': status, 'error': 'Chưa cấp quyền Meet.'});
    }));
  }

  test('OAuth uses the system browser and returns only the local grant handle', () async {
    final requests = <http.Request>[];
    String? opened;
    final oauth = GoogleOAuthClient(localService: backend('CONNECTED', requests), openUrl: (url) async { opened = url; });
    final result = await oauth.connect(loginHint: 'teacher@example.com');
    expect(Uri.parse(opened!).host, 'accounts.google.com');
    expect(result['sessionId'], 'opaque-grant');
    expect(result.containsKey('accessToken'), isFalse);
    expect(jsonDecode(requests[1].body)['loginHint'], 'teacher@example.com');
    await oauth.dispose();
    expect(requests.where((r) => r.url.path.endsWith('/cancel')), isEmpty);
  });

  test('Cancellation closes the pending backend flow and never accepts a grant', () async {
    final requests = <http.Request>[];
    late GoogleOAuthClient oauth;
    oauth = GoogleOAuthClient(localService: backend('CONNECTED', requests), openUrl: (_) async { await oauth.cancel(); });
    await expectLater(oauth.connect(), throwsStateError);
    expect(requests.where((r) => r.url.path.endsWith('/cancel')).length, 1);
    expect(requests.where((r) => r.url.path.endsWith('/status')), isEmpty);
    await oauth.dispose();
  });

  test('Missing configuration or denied consent cannot simulate a Google login', () async {
    final requests = <http.Request>[];
    bool opened = false;
    final unconfigured = GoogleOAuthClient(localService: backend('ERROR', requests, configured: false), openUrl: (_) async { opened = true; });
    await expectLater(unconfigured.connect(), throwsStateError);
    expect(opened, isFalse);
    await unconfigured.dispose();
    final denied = GoogleOAuthClient(localService: backend('ERROR', requests), openUrl: (_) async {});
    await expectLater(denied.connect(), throwsStateError);
    await denied.dispose();
  });

  test('Demo and stored WebView markers do not authorize Meet', () async {
    final auth = GoogleMeetAuthService();
    auth.signOut();
    auth.signInWithDemoTeacher();
    expect(auth.isGoogleAuthenticated, isFalse);
    auth.signOut();
    SharedPreferences.setMockInitialValues({'auth_is_signed_in': true, 'auth_method': 'google', 'auth_token': 'webview2_authenticated_google_session'});
    await auth.init();
    expect(auth.isGoogleAuthenticated, isFalse);
    expect(auth.accessToken, isNull);
    expect((await SharedPreferences.getInstance()).getString('auth_token'), isNull);
    auth.signOut();
  });

  test('Linking Google preserves the local teacher identity and OTP token', () async {
    final auth = GoogleMeetAuthService();
    auth.signOut();
    auth.signInWithOtpSession(token: 'local-account-token', name: 'Thầy Toàn', phone: '0901234567');
    auth.connectGoogleSession(sessionId: 'opaque-grant', name: 'Cô Hoa', email: 'teacher@example.com');
    expect(auth.isGoogleAuthenticated, isTrue);
    expect(auth.googleEmail, 'teacher@example.com');
    expect(auth.teacherName, 'Thầy Toàn');
    expect(auth.teacherPhone, '0901234567');
    expect(auth.accessToken, 'local-account-token');
    expect(auth.authMethod, 'otp_phone');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((key) => key.contains('googleSession')), isFalse);
    auth.signOut();
    expect(auth.googleSessionId, isNull);
  });
}
