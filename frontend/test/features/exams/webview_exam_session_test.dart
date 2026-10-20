import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/exams/services/exam_session_service.dart';

void main() {
  final auth = GoogleMeetAuthService();
  http.Response response(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'Content-Type': 'application/json'},
  );
  Map<String, Object> session(String token) => {
    'token': token,
    'user': {'id': 'local-teacher', 'role': 'TEACHER'},
  };
  Future<void> signIn({String? token}) async {
    SharedPreferences.setMockInitialValues({
      'auth_is_signed_in': true,
      'auth_method': 'google',
      'auth_token': ExamSessionService.webviewSessionMarker,
      'auth_email': 'teacher@test.vn',
      'auth_name': 'Giáo viên',
    });
    await auth.init();
    if (token != null) {
      await ExamSessionService().attachLocalExamSession(
        token: token,
        teacherId: 'local-teacher',
      );
    }
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth.signOut();
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'Stored develop Google profile creates one session for concurrent exam calls',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_is_signed_in': true,
        'auth_token': ExamSessionService.webviewSessionMarker,
        'auth_method': 'google',
        'auth_email': 'teacher@test.vn',
        'auth_name': 'Giáo viên',
      });
      await auth.init();
      final providerToken = auth.accessToken;
      int bootstrap = 0, sessions = 0;
      final api = ExamApi(
        base: 'http://127.0.0.1:47831',
        client: MockClient((req) async {
          if (req.url.path == '/api/bootstrap') {
            bootstrap++;
            return response({'token': 'companion-proof'});
          }
          if (req.url.path == '/api/auth/google/webview-session') {
            sessions++;
            expect(req.headers['X-Companion-Token'], 'companion-proof');
            expect(jsonDecode(req.body)['email'], 'teacher@test.vn');
            return response(session('local-session'));
          }
          expect(req.headers['authorization'], 'Bearer local-session');
          return response({'ok': true});
        }),
      );
      addTearDown(api.dispose);
      await Future.wait([api.get('dashboard'), api.get('analytics')]);
      expect(bootstrap, 1);
      expect(sessions, 1);
      expect(auth.accessToken, providerToken);
      expect(auth.teacherEmail, 'teacher@test.vn');
      expect(ExamSessionService().appSessionToken, 'local-session');
      expect(ExamSessionService().teacherId, 'local-teacher');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_app_session'), 'local-session');
    },
  );

  test(
    'Expired local session renews once and preserves Google login',
    () async {
      await signIn(token: 'expired-session');
      int renewals = 0, reads = 0;
      final api = ExamApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/bootstrap') {
            return response({'token': 'companion-proof'});
          }
          if (req.url.path == '/api/auth/google/webview-session') {
            renewals++;
            return response(session('renewed-session'));
          }
          reads++;
          if (req.headers['authorization'] == 'Bearer expired-session') {
            return response({}, 401);
          }
          expect(req.headers['authorization'], 'Bearer renewed-session');
          return response({'ok': true});
        }),
      );
      addTearDown(api.dispose);
      expect(await api.get('dashboard'), {'ok': true});
      expect(renewals, 1);
      expect(reads, 2);
      expect(auth.isSignedIn, isTrue);
    },
  );

  test(
    'Backend outage leaves app Google login usable and can be retried',
    () async {
      await signIn();
      bool offline = true;
      final api = ExamApi(
        client: MockClient((req) async {
          if (offline) throw http.ClientException('offline');
          if (req.url.path == '/api/bootstrap') {
            return response({'token': 'proof'});
          }
          if (req.url.path == '/api/auth/google/webview-session') {
            return response(session('recovered-session'));
          }
          return response({'ok': true});
        }),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.get('dashboard'),
        throwsA(isA<http.ClientException>()),
      );
      expect(auth.isSignedIn, isTrue);
      expect(ExamSessionService().appSessionToken, isNull);
      offline = false;
      expect(await api.get('dashboard'), {'ok': true});
    },
  );

  test(
    'Late response cannot attach exams to a signed out or switched user',
    () async {
      await signIn();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      int examReads = 0;
      final api = ExamApi(
        client: MockClient((req) async {
          if (req.url.path == '/api/bootstrap') {
            return response({'token': 'proof'});
          }
          if (req.url.path == '/api/auth/google/webview-session') {
            started.complete();
            return pending.future;
          }
          examReads++;
          return response({});
        }),
      );
      addTearDown(api.dispose);
      final failure = expectLater(
        api.get('dashboard'),
        throwsA(isA<ExamApiException>()),
      );
      await started.future;
      auth.signOut();
      pending.complete(response(session('late-session')));
      await failure;
      expect(ExamSessionService().appSessionToken, isNull);
      expect(auth.isSignedIn, isFalse);
      expect(examReads, 0);
    },
  );

  test('PDF upload obtains local session before sending file bytes', () async {
    await signIn();
    final client = MockClient.streaming((req, body) async {
      if (req.url.path == '/api/bootstrap') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({'token': 'proof'}))),
          200,
        );
      }
      if (req.url.path == '/api/auth/google/webview-session') {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(session('upload-session')))),
          200,
        );
      }
      expect(req.headers['authorization'], 'Bearer upload-session');
      expect(req.headers['content-type'], startsWith('multipart/form-data'));
      expect(await body.bytesToString(), contains('filename="source.pdf"'));
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"ok":true}')),
        200,
      );
    });
    final api = ExamApi(client: client);
    addTearDown(api.dispose);
    await api.upload('sources', utf8.encode('%PDF-1.4'), 'source.pdf');
  });
}

