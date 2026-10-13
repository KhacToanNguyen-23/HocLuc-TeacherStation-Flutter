import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/screens/exams/exam_workspace_screen.dart';
import 'package:teaching_companion/screens/login_screen.dart';
import 'package:teaching_companion/widgets/dashboard/exam_dashboard_card.dart';
import 'package:teaching_companion/widgets/studio/studio_top_bar.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/services/exam_api.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/services/google_oauth_client.dart';
import 'package:teaching_companion/services/local_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleMeetAuthService().signOut();
  });
  ExamApi api({String role = 'TEACHER'}) => ExamApi(
    base: 'http://test.local',
    client: MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer shared-app-session');
      final body = switch (request.url.path) {
        '/api/exams/auth/me' => {
          'id': 'teacher-a',
          'email': 'teacher@test.vn',
          'name': 'Giáo viên',
          'role': role,
        },
        '/api/exams/dashboard' => {
          'classes': 0,
          'students': 0,
          'papers': 0,
          'results': 0,
          'approvedQuestions': 0,
          'sources': 0,
        },
        '/api/exams/analytics' => {
          'limitation': 'Chưa có đáp án chi tiết.',
          'recommendations': [],
          'scores': [],
          'skills': [],
          'topics': [],
          'sections': [],
          'difficulties': [],
        },
        _ => [],
      };
      return http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
      );
    }),
  );
  void signIn() => GoogleMeetAuthService().signInWithOtpSession(
    token: 'shared-app-session',
    name: 'Giáo viên',
    email: 'teacher@test.vn',
    teacherId: 'teacher-a',
  );
  test('Google access token and shared application token stay separate', () {
    final auth = GoogleMeetAuthService();
    final google = GoogleOAuthClient(
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    expect(() => google.accept({'status': 'PENDING'}, auth), throwsStateError);
    expect(auth.isSignedIn, isFalse);
    google.accept({
      'status': 'COMPLETE',
      'token': 'shared-app-session',
      'googleAccessToken': 'google-provider-access',
      'user': {
        'id': 'teacher-a',
        'name': 'Giáo viên',
        'email': 'teacher@test.vn',
        'role': 'TEACHER',
      },
    }, auth);
    expect(auth.accessToken, 'google-provider-access');
    expect(auth.appSessionToken, 'shared-app-session');
    expect(auth.teacherId, 'teacher-a');
    auth.signOut();
    expect(auth.appSessionToken, isNull);
    google.dispose();
  });
  test(
    'Demo cannot access private exam data through a fabricated session',
    () async {
      GoogleMeetAuthService().signInWithDemoTeacher();
      int hits = 0;
      final client = ExamApi(
        client: MockClient((_) async {
          hits++;
          return http.Response('{}', 200);
        }),
      );
      await expectLater(
        client.get('dashboard'),
        throwsA(isA<ExamApiException>().having((e) => e.status, 'status', 401)),
      );
      expect(hits, 0);
      client.dispose();
    },
  );
  test('Backend failure never becomes a successful app login', () async {
    final service = LocalService(
      client: MockClient((_) async => throw http.ClientException('offline')),
      base: 'http://test.local',
    );
    expect(
      (await service.login(
        identifier: 'teacher@test.vn',
        password: 'password',
      ))['success'],
      isFalse,
    );
    expect(
      (await service.register(
        target: 'teacher@test.vn',
        otp: '123456',
        password: 'password',
      ))['success'],
      isFalse,
    );
    service.dispose();
  });
  testWidgets(
    'Existing dashboard opens the native module with its current session',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      signIn();
      final client = api();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ClassroomDashboardScreen(examApi: client)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Đề thi & năng lực'));
      await tester.pumpAndSettle();
      expect(find.byType(ExamWorkspaceScreen), findsOneWidget);
      expect(
        find.text('Ngân hàng câu hỏi'),
        findsWidgets,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.text('Nguồn PDF & duyệt'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Dashboard shortcut opens the requested tool in the same app session',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      signIn();
      final client = api();
      addTearDown(client.dispose);
      await tester.pumpWidget(
        MaterialApp(home: ClassroomDashboardScreen(examApi: client)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mở tổng quan'), findsOneWidget);
      expect(find.text('Nguồn PDF & duyệt'), findsNothing);
      await tester.tap(find.text('Phân tích năng lực'));
      await tester.pumpAndSettle();
      expect(find.byType(ExamWorkspaceScreen), findsOneWidget);
      expect(find.text('Phạm vi phân tích'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Expired or legacy session returns to the existing login screen',
    (tester) async {
      GoogleMeetAuthService().signInWithDemoTeacher();
      await tester.pumpWidget(const MaterialApp(home: ExamWorkspaceScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập lại'), findsOneWidget);
      await tester.tap(find.text('Đăng nhập lại'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(GoogleMeetAuthService().isSignedIn, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Visible exam card fits supported widths and only shows admin shortcuts to admins',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int? opened;
      for (final width in [375.0, 414.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ExamDashboardCard(
                    isAdmin: true,
                    onOpen: (p) => opened = p,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Nguồn PDF & duyệt'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nguồn PDF & duyệt'));
        expect(opened, 7);
        expect(tester.takeException(), isNull, reason: 'card at $width');
      }
      await tester.pumpWidget(
        MaterialApp(home: ExamDashboardCard(onOpen: (p) => opened = p)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nguồn PDF & duyệt'), findsNothing);
      expect(find.text('Ma trận'), findsNothing);
    },
  );
  testWidgets(
    'Teaching toolbar exposes exam tools without changing the board',
    (tester) async {
      final studio = StudioState();
      addTearDown(studio.dispose);
      bool opened = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioTopBar(
              studio: studio,
              width: 800,
              hasLessons: false,
              onToggleLessons: () {},
              onOpenSettings: (_) {},
              onRename: () {},
              onPreview: () {},
              onSave: () {},
              onRetryConnect: () {},
              onOpenExams: () => opened = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final oldView = studio.view;
      await tester.tap(find.text('Đề thi'));
      expect(opened, isTrue);
      expect(studio.view, oldView);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Native module keeps usable navigation at mobile and desktop widths',
    (tester) async {
      signIn();
      final client = api(role: 'ADMIN');
      addTearDown(client.dispose);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [375.0, 414.0, 768.0, 1024.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey(width),
            home: ExamWorkspaceScreen(api: client),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Tổng quan'),
          findsWidgets,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        expect(find.byTooltip('Tải lại'), findsOneWidget);
        expect(tester.takeException(), isNull);
        for (final name in [
          'Ngân hàng câu hỏi',
          'Tạo đề thi',
          'Thư viện đề',
          'Lớp & học sinh',
          'Kết quả kiểm tra',
          'Phân tích năng lực',
          'Nguồn PDF & duyệt',
          'Ma trận',
        ]) {
          final chip = find.widgetWithText(ChoiceChip, name);
          await tester.scrollUntilVisible(
            chip,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(
            find.byWidgetPredicate(
              (w) => w is Text && w.data == name && w.style?.fontSize == 22,
            ),
            findsOneWidget,
            reason: '$name at $width',
          );
          expect(tester.takeException(), isNull, reason: '$name at $width');
        }
      }
    },
  );
}
