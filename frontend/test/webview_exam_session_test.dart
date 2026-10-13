import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/services/exam_api.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/widgets/auth/google_webview_login_dialog.dart';

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
  void signIn({String? token}) => auth.signInWithGoogleToken(
    accessToken: GoogleMeetAuthService.webviewSessionMarker,
    name: 'Giáo viên',
    email: 'teacher@test.vn',
    sessionToken: token,
  );
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    auth.signOut();
    await Future<void>.delayed(Duration.zero);
  });

  testWidgets(
    'Develop Google dialog completes app login without OAuth configuration',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        for (final width in [375.0, 414.0, 768.0, 1024.0, 1440.0]) {
          auth.signOut();
          tester.view.physicalSize = Size(width, 1000);
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => GoogleWebviewLoginDialog.show(context),
                    child: const Text('Google'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Google'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Chưa cấu hình Google OAuth'),
            findsNothing,
          );
          await tester.enterText(find.byType(TextField), 'teacher@test.vn');
          await tester.tap(find.text('Xác nhận đăng nhập'));
          await tester.pumpAndSettle();
          expect(auth.hasLocalGoogleProfile, isTrue);
          expect(auth.teacherEmail, 'teacher@test.vn');
          expect(auth.appSessionToken, isNull);
          expect(find.byType(GoogleWebviewLoginDialog), findsNothing);
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  test(
    'Stored develop Google profile creates one session for concurrent exam calls',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_is_signed_in': true,
        'auth_token': GoogleMeetAuthService.webviewSessionMarker,
        'auth_method': 'google',
        'auth_email': 'teacher@test.vn',
        'auth_name': 'Giáo viên',
      });
      await auth.init();
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
      expect(auth.accessToken, GoogleMeetAuthService.webviewSessionMarker);
      expect(auth.teacherEmail, 'teacher@test.vn');
      expect(auth.appSessionToken, 'local-session');
      expect(auth.teacherId, 'local-teacher');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_app_session'), 'local-session');
    },
  );

  test(
    'Expired local session renews once and preserves Google login',
    () async {
      signIn(token: 'expired-session');
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
      signIn();
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
      expect(auth.appSessionToken, isNull);
      offline = false;
      expect(await api.get('dashboard'), {'ok': true});
    },
  );

  test(
    'Late response cannot attach exams to a signed out or switched user',
    () async {
      signIn();
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
      expect(auth.appSessionToken, isNull);
      expect(auth.isSignedIn, isFalse);
      expect(examReads, 0);
    },
  );

  test('PDF upload obtains local session before sending file bytes', () async {
    signIn();
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
