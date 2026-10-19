import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/main.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/models/meet_events.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/screens/classroom_lobby_screen.dart';
import 'package:teaching_companion/screens/exams/exam_workspace_screen.dart';
import 'package:teaching_companion/screens/login_screen.dart';
import 'package:teaching_companion/features/exams/services/exam_api.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/google_meet_auth_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_document_drawer.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_inspector_panel.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_students_drawer.dart';
import 'package:teaching_companion/features/auth/presentation/auth_form_card.dart';
import 'package:teaching_companion/features/auth/presentation/auth_hero_panel.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_action_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/dashboard_empty_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/exam_dashboard_card.dart';
import 'package:teaching_companion/features/exams/presentation/exam_widgets.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/lobby/lobby_media_preview.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/lobby/lobby_meet_room_card.dart';
import 'package:teaching_companion/features/studio_board/presentation/stage_container.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_top_bar.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_student_strip.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';

// These fixtures exercise the real Flutter screens. No account, physical media
// device, Meet session, or production backend is used by the visual audit.
const _phase = String.fromEnvironment(
  'HLS_VISUAL_PHASE',
  defaultValue: 'after',
);
const _capture = bool.fromEnvironment('HLS_CAPTURE');
const _baselineFile = 'test/fixtures/visual_restyle_geometry.json';

class _VisualMediaService extends ChangeNotifier
    implements TeacherMediaService {
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
    'Unexpected media interaction in visual fixture: $invocation',
  );
}

class _VisualMeetService extends ChangeNotifier
    implements MeetAutomationService {
  @override
  List<MeetParticipant> get participants => const [
    MeetParticipant(id: '1', name: 'Nguyễn Minh Anh'),
    MeetParticipant(id: '2', name: 'Trần Hà', isMuted: false, isSpeaking: true),
    MeetParticipant(id: '3', name: 'Lê An', isHandRaised: true),
  ];
  @override
  int get pendingAdmitCount => 2;
  @override
  String? get meetingUrl => 'https://meet.google.com/abc-defg-hij';
  @override
  bool autoAdmitEnabled = true;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected Meet interaction in visual fixture: $invocation',
  );
}

// Frozen pre-restyle root theme. Before PNGs were captured before source edits;
// this theme alone cannot reproduce the previous component source afterward.
ThemeData _beforeTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Manrope',
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF0284C7),
    primary: const Color(0xFF0F172A),
    secondary: const Color(0xFF0284C7),
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
    bodySmall: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF6F7F2),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  ),
);

ExamApi _examApi({String role = 'TEACHER'}) => ExamApi(
  base: 'http://fixture.local',
  client: MockClient((request) async {
    final Object data = switch (request.url.path) {
      '/api/exams/auth/me' => {
        'id': 'visual-teacher',
        'name': 'Giáo viên',
        'email': 'visual@example.invalid',
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
  final measured = <String, Object>{};

  setUpAll(() async {
    for (final name in ['Manrope', 'Literata']) {
      await (FontLoader(
        name,
      )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  tearDownAll(() {
    if (_phase == 'before' && _capture) {
      final file = File(_baselineFile)..createSync(recursive: true);
      file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(measured),
      );
    }
  });

  for (final viewport in [
    ('1366x768', const Size(1366, 768), 1.0),
    ('1440x900', const Size(1440, 900), 1.0),
    ('1920x1080', const Size(1920, 1080), 1.0),
    ('1920x1080-scale125', const Size(1920, 1080), 1.25),
  ]) {
    testWidgets('restyle preserves screen geometry at ${viewport.$1}', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = viewport.$2;
      tester.view.devicePixelRatio = viewport.$3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = GoogleMeetAuthService()..signOut();
      final boundaryKey = GlobalKey();

      Future<void> mount(Widget widget) async {
        // Fully detach capture/media listeners before mounting another screen.
        // A production route transition retains the app capture surface; these
        // independent fixture screens deliberately replace the entire root.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          RepaintBoundary(key: boundaryKey, child: widget),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      Future<void> inspect(
        String scene,
        List<Type> anchors, {
        bool compare = true,
      }) async {
        final key = '${viewport.$1}/$scene';
        final geometry = <String, List<double>>{};
        for (final type in anchors) {
          final finder = find.byType(type);
          for (var index = 0; index < finder.evaluate().length; index++) {
            final rect = tester.getRect(finder.at(index));
            geometry['$type/$index'] = [
              rect.left,
              rect.top,
              rect.width,
              rect.height,
            ];
          }
        }
        expect(geometry, isNotEmpty);
        measured[key] = geometry;
        if (_phase != 'before' && compare) {
          final baseline =
              jsonDecode(File(_baselineFile).readAsStringSync()) as Map;
          final expected = baseline[key] as Map;
          expect(geometry.keys.toSet(), expected.keys.toSet(), reason: key);
          for (final entry in geometry.entries) {
            final original = (expected[entry.key] as List).cast<num>();
            for (var index = 0; index < 4; index++) {
              expect(
                entry.value[index],
                closeTo(original[index].toDouble(), 1),
                reason: '$key ${entry.key} coordinate $index',
              );
            }
          }
        }
        if (_capture) {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              '../.run/visual-restyle/$_phase/${viewport.$1}-$scene.png',
            );
            await file.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }

      await mount(
        _phase == 'before'
            ? MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: _beforeTheme(),
                home: const LoginScreen(),
              )
            : const CompanionApp(),
      );
      final theme = Theme.of(tester.element(find.byType(LoginScreen)));
      await inspect('login', [AuthFormCard, AuthHeroPanel]);

      auth.signInWithOtpSession(token: 'visual-session', name: 'Giáo viên');
      if (_phase == 'before') {
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const ClassroomDashboardScreen(),
          ),
        );
      } else {
        await tester.pumpAndSettle();
      }
      await inspect('dashboard', [
        DashboardActionCard,
        ExamDashboardCard,
        DashboardEmptyCard,
      ]);

      for (final planning in [false, true]) {
        final state = StudioState()
          ..loading = false
          ..title = 'Toán 12 · Hàm số bậc hai';
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: StudioScreen(
              key: ValueKey(planning),
              initialState: state,
              isPlanningMode: planning,
            ),
          ),
        );
        await inspect(planning ? 'planning' : 'studio', [
          StudioTopBar,
          StageContainer,
        ]);
      }

      final media = _VisualMediaService();
      await mount(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: ClassroomLobbyScreen(mediaService: media),
        ),
      );
      await inspect('lobby', [LobbyMediaPreview, LobbyMeetRoomCard]);

      final api = _examApi();
      await mount(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: ExamWorkspaceScreen(api: api),
        ),
      );
      await inspect('exams', [AppBar, ChoiceChip, ExamCard]);

      if (_phase != 'before' && viewport.$1 == '1440x900') {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Ngân hàng câu hỏi'));
        await tester.pumpAndSettle();
        await inspect('exam-bank-empty', [
          AppBar,
          ChoiceChip,
          ExamCard,
        ], compare: false);

        final failingApi = ExamApi(
          base: 'http://fixture.local',
          client: MockClient((_) async => http.Response('Unavailable', 503)),
        );
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: ExamWorkspaceScreen(api: failingApi),
          ),
        );
        expect(find.text('Thử lại'), findsOneWidget);
        await inspect('exam-error', [AppBar, ExamError], compare: false);
        await mount(const SizedBox.shrink());
        failingApi.dispose();

        final board = StudioState()
          ..loading = false
          ..showQuestionsDrawer = true;
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: StudioScreen(initialState: board),
          ),
        );
        await inspect('studio-documents', [
          StageContainer,
          StudioDocumentDrawer,
        ], compare: false);
        board.setQuestionsDrawer(false);
        await tester.tap(find.byTooltip('Thiết bị và API AI'));
        await tester.pumpAndSettle();
        await inspect('studio-inspector', [
          StageContainer,
          StudioInspectorPanel,
        ], compare: false);
        await tester.tap(find.byTooltip('Danh sách học sinh'));
        await tester.pumpAndSettle();
        await inspect('studio-students', [
          StageContainer,
          StudioStudentsDrawer,
        ], compare: false);

        final meet = _VisualMeetService();
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: MeetAdmissionScope(
              service: meet,
              open: (anchor, {bool showMeet = false}) {},
              isOpen: false,
              revision: 0,
              child: Scaffold(
                body: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 100),
                        StudioStudentStrip(
                          meetService: meet,
                          onOpenStudentsDrawer: () {},
                        ),
                      ],
                    ),
                    const Positioned(
                      top: 12,
                      right: 20,
                      child: MeetAdmissionButton(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await inspect('studio-meet-states', [
          StudioStudentStrip,
          MeetAdmissionButton,
        ], compare: false);
        await tester.tap(find.byTooltip('Thu gọn dải học sinh (mở rộng bảng)'));
        await tester.pumpAndSettle();
        expect(find.text('Mở dải học sinh'), findsOneWidget);
        await inspect('studio-meet-collapsed', [
          StudioStudentStrip,
        ], compare: false);
        await mount(const SizedBox.shrink());
        meet.dispose();

        auth.signOut();
        await mount(const CompanionApp());
        await tester.tap(find.text('Đăng ký'));
        await tester.pumpAndSettle();
        await inspect('signup', [AuthFormCard, AuthHeroPanel], compare: false);

        final loginResponse = Completer<http.Response>();
        final loginClient = MockClient(
          (request) async => request.url.path.endsWith('bootstrap')
              ? http.Response('{"token":"visual-companion"}', 200)
              : loginResponse.future,
        );
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: LoginScreen(localService: LocalService(client: loginClient)),
          ),
        );
        await tester.enterText(
          find.byType(TextField).at(0),
          'visual@example.invalid',
        );
        await tester.enterText(
          find.byType(TextField).at(1),
          'fixture-password',
        );
        await tester.tap(find.text('Đăng nhập'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(CircularProgressIndicator), findsWidgets);
        await inspect('login-loading', [
          AuthFormCard,
          AuthHeroPanel,
        ], compare: false);
        loginResponse.complete(
          http.Response.bytes(
            utf8.encode('{"error":"Không kết nối được dịch vụ."}'),
            503,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.error_outline_rounded), findsWidgets);
        await inspect('login-error', [
          AuthFormCard,
          AuthHeroPanel,
        ], compare: false);
        await mount(const SizedBox.shrink());
        loginClient.close();

        auth.signInWithOtpSession(token: 'visual-session', name: 'Giáo viên');
        final admin = _examApi(role: 'ADMIN');
        await mount(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: ExamWorkspaceScreen(api: admin),
          ),
        );
        await inspect('exam-admin-overview', [
          AppBar,
          ChoiceChip,
          ExamCard,
        ], compare: false);
        var page = 1;
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
          final navigation = find.descendant(
            of: find.byKey(const PageStorageKey('exam-navigation')),
            matching: find.byType(Scrollable),
          );
          final chip = find.widgetWithText(ChoiceChip, name);
          await tester.scrollUntilVisible(chip, 220, scrollable: navigation);
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Admin page $name');
          await inspect('exam-admin-${page++}', [
            AppBar,
            ChoiceChip,
          ], compare: false);
        }
        await mount(const SizedBox.shrink());
        admin.dispose();
      }

      await mount(const SizedBox.shrink());
      api.dispose();
      media.dispose();
      auth.signOut();
    });
  }
}

