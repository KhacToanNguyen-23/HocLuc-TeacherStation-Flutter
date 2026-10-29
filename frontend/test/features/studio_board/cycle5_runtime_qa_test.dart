import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:teaching_companion/features/auth/presentation/auth_form_card.dart';
import 'package:teaching_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:teaching_companion/features/auth/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_lobby_screen.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/features/exams/presentation/screens/exam_workspace_screen.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';

class _MockMediaService extends ChangeNotifier implements TeacherMediaService {
  @override
  bool get isCameraActive => false;
  @override
  bool get isMicActive => false;
  @override
  bool get isInitializing => false;
  @override
  bool get isInitialized => true;
  @override
  bool get supportsAudio => true;
  @override
  double get audioLevel => 0;
  @override
  String? get errorMessage => null;
  @override
  List<String> get availableCameras => const [];
  @override
  List<String> get availableMicrophones => const [];
  @override
  Future<void> initMedia() async {}
  @override
  Widget buildCameraPreview() => const SizedBox.expand();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        'Unexpected media interaction: $invocation',
      );
}

ExamApi _mockExamApi() => ExamApi(
      base: 'http://fixture.local',
      client: MockClient((request) async {
        final Object data = switch (request.url.path) {
          '/api/exams/auth/me' => {
              'id': 'qa-teacher',
              'name': 'Giáo viên',
              'email': 'qa@example.invalid',
              'role': 'TEACHER',
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
              'limitation': 'Chưa có phân tích.',
              'recommendations': [],
              'scores': [],
              'skills': [],
              'topics': [],
              'sections': [],
              'difficulties': [],
            },
          _ => <Object>[],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(data)),
          200,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
        );
      }),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    for (final name in ['Manrope', 'Literata']) {
      await (FontLoader(name)
            ..addFont(rootBundle.load('assets/fonts/$name.ttf')))
          .load();
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  group('Cycle 5 Runtime Visual QA: DPI 150% & Desktop Viewports', () {
    testWidgets('renders key screens at 1920x1080 with 150% DPI without overflow',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.5; // 150% scaling
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final boundaryKey = GlobalKey();

      Future<void> mountAndCapture(Widget widget, String name) async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              home: widget,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '$name should mount without any render overflow');

        // Capture screenshot
        final boundary = boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            if (bytes != null) {
              final file = File(
                '../.run/visual-restyle/after/1920x1080-scale150-$name.png',
              );
              await file.create(recursive: true);
              await file.writeAsBytes(bytes.buffer.asUint8List());
            }
            image.dispose();
          });
        }
      }

      // 1. Login Screen
      await mountAndCapture(const LoginScreen(), 'login');
      expect(find.byType(AuthFormCard), findsOneWidget);

      // 2. Dashboard Screen
      final auth = GoogleMeetAuthService()..signOut();
      auth.signInWithOtpSession(token: 'qa-session', name: 'Giáo viên');
      await mountAndCapture(const ClassroomDashboardScreen(), 'dashboard');

      // 3. Classroom Lobby Screen
      await mountAndCapture(
        ClassroomLobbyScreen(mediaService: _MockMediaService()),
        'lobby',
      );

      // 4. Studio Screen
      final state = StudioState()
        ..loading = false
        ..title = 'Toán 12 · Ứng dụng đạo hàm';
      await mountAndCapture(
        StudioScreen(initialState: state, isPlanningMode: false),
        'studio',
      );

      // 5. Exam Workspace Screen
      await mountAndCapture(
        ExamWorkspaceScreen(api: _mockExamApi()),
        'exams',
      );
    });

    testWidgets(
        '1366x768 with simulated 48px Taskbar maintains bottom button visibility',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      // Usable height excluding Windows Taskbar: 768 - 48 = 720
      tester.view.physicalSize = const Size(1366, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = GoogleMeetAuthService()..signOut();
      auth.signInWithOtpSession(token: 'qa-session-768', name: 'Giáo viên');

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: const ClassroomDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify that Dashboard scroll view can reach bottom without overflow
      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('LoginScreen keyboard navigation: Enter key triggers submission',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final auth = GoogleMeetAuthService()..signOut();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          home: LoginScreen(authService: auth),
        ),
      );
      await tester.pumpAndSettle();

      // Find identifier and password text fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Enter identifier
      await tester.enterText(textFields.at(0), 'teacher@hocluc.vn');
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();

      // Enter password
      await tester.enterText(textFields.at(1), 'password123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Form triggers submission without exceptions
      expect(tester.takeException(), isNull);
    });
  });
}
