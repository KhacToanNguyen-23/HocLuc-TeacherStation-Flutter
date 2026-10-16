import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/screens/google_workspace_screen.dart';
import 'package:teaching_companion/services/google_workspace_api.dart';
import 'package:teaching_companion/services/google_meet_auth_service.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/services/system_microphone_service.dart';
import 'package:teaching_companion/theme/app_theme.dart';
import 'package:teaching_companion/widgets/meet_admission_button.dart';
import 'package:teaching_companion/widgets/meet_admission_shell.dart';
import 'package:teaching_companion/widgets/system_microphone_controls.dart';
import 'package:teaching_companion/widgets/studio/studio_meet_cockpit_tab.dart';

import 'support/meet_admission_fixture.dart';

const _capture = bool.fromEnvironment('HLS_CAPTURE');

GoogleWorkspaceApi _workspace({bool connected = true}) => GoogleWorkspaceApi(
  email: 'teacher@example.invalid',
  client: MockClient((request) async {
    final Object data;
    if (request.url.path.endsWith('bootstrap')) {
      data = {'token': 'visual-fixture'};
    } else if (request.url.path.endsWith('status')) {
      data = {
        'configured': true,
        'connected': connected,
        if (!connected) ...{
          'state': 'REAUTH_REQUIRED',
          'message': 'Cần cấp quyền Google lại để tiếp tục quản lý lớp.',
        },
      };
    } else {
      data = {
        'courses': [
          {
            'id': 'fixture-class',
            'courseId': 'classroom-fixture',
            'title': 'Lớp 12A · Ôn tập cuối kỳ',
            'description': 'Lớp học dành cho bộ kiểm tra giao diện.',
            'warnings': [],
            'calendarStatus': 'READY',
            'meetingUrl': room,
            'students': [
              {
                'name': 'Nguyễn Minh Anh',
                'email': 'minhanh@example.invalid',
                'classroomStatus': 'JOINED',
                'meetStatus': 'CALENDAR_INVITED',
                'meetAllowed': true,
              },
              {
                'name': 'Trần Hà',
                'email': 'tran.ha@example.invalid',
                'classroomStatus': 'INVITED',
                'meetStatus': 'GRANT_FAILED',
                'meetAllowed': false,
              },
            ],
          },
        ],
      };
    }
    return http.Response.bytes(
      utf8.encode(jsonEncode(data)),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

Future<void> _snapshot(WidgetTester tester, GlobalKey key, String scene) async {
  expect(tester.takeException(), isNull, reason: scene);
  if (!_capture) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final picture = await boundary.toImage(pixelRatio: 1);
    final bytes = await picture.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../.run/new-feature-appearance/$scene.png');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    picture.dispose();
  });
}

Widget _app(GlobalKey key, Widget home) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: home,
  ),
);

void main() {
  setUpAll(() async {
    for (final entry in {
      'Manrope': 'assets/fonts/Manrope.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final font = FontLoader(entry.key)..addFont(rootBundle.load(entry.value));
      await font.load();
    }
  });

  testWidgets(
    'reduced motion jumps overflowing Meet chat to the latest message',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final meet = MeetAutomationService.forTesting();
      for (var i = 0; i < 40; i++) {
        await meet.sendChatMessage('Tin nhắn kiểm tra $i');
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(reduceMotion: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 380,
                height: 700,
                child: ListenableBuilder(
                  listenable: meet,
                  builder: (context, _) => StudioMeetCockpitTab(
                    meetService: meet,
                    authService: GoogleMeetAuthService(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final controller = tester
          .widget<ListView>(find.byType(ListView))
          .controller!;
      expect(controller.position.maxScrollExtent, greaterThan(0));
      expect(controller.offset, 0);
      await tester.enterText(find.byType(TextField), 'Tin nhắn mới nhất');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(controller.offset, controller.position.maxScrollExtent);
      expect(find.text('Tin nhắn mới nhất'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      meet.dispose();
    },
  );

  for (final connected in [true, false]) {
    testWidgets(
      'Google Workspace uses shared appearance, connected=$connected',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _workspace(connected: connected);
        final key = GlobalKey();
        await tester.pumpWidget(_app(key, GoogleWorkspaceScreen(api: api)));
        await tester.pumpAndSettle();
        expect(
          find.text(
            connected ? 'Google đã kết nối' : 'Google cần cấp quyền lại',
          ),
          findsOneWidget,
        );
        await _snapshot(
          tester,
          key,
          connected ? 'workspace-connected' : 'workspace-reconnect',
        );
        if (connected) {
          await tester.scrollUntilVisible(find.text('Học sinh / Email'), 300);
          await tester.pumpAndSettle();
          await _snapshot(tester, key, 'workspace-roster');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        api.close();
      },
    );
  }

  testWidgets('admission popup keeps shared panel and primary action states', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final meet = MeetAutomationService.forTesting();
    seedAdmissions(meet);
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        key,
        MeetAdmissionShell(
          service: meet,
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MeetAdmissionButton(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('meet-admission-menu')));
    await tester.pumpAndSettle();
    final popup = tester.widget<Material>(
      find.byKey(const Key('meet-admission-popup')),
    );
    expect(popup.color, AppColors.surface);
    expect(popup.elevation, 4);
    final approve = tester.widget<FilledButton>(
      find.byKey(const Key('meet-admission-approve-all')),
    );
    final primary = FilledButtonTheme.of(
      tester.element(find.byWidget(approve)),
    ).style!;
    expect(
      primary.backgroundColor!.resolve({WidgetState.hovered}),
      AppColors.primaryHover,
    );
    expect(
      primary.backgroundColor!.resolve({WidgetState.pressed}),
      AppColors.primaryPressed,
    );
    await _snapshot(tester, key, 'meet-admission');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('meet-admission-popup')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    meet.dispose();
  });

  testWidgets('microphone controls and settings share the chrome palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const channel = MethodChannel('test/appearance-microphone');
    final microphone = SystemMicrophoneService.forTesting(channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'systemMicrophoneDevices') {
            return [
              {'id': 'mic', 'name': 'USB Microphone'},
            ];
          }
          return {
            'id': 'mic',
            'name': 'USB Microphone',
            'muted': false,
            'volume': .7,
            'level': .5,
          };
        });
    final key = GlobalKey();
    await tester.pumpWidget(
      _app(
        key,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: SystemMicrophoneControls(microphone: microphone),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .color,
      AppColors.emerald100,
    );
    await _snapshot(tester, key, 'microphone-controls');
    await tester.tap(find.byTooltip('Cài đặt microphone Windows'));
    await tester.pumpAndSettle();
    await _snapshot(tester, key, 'microphone-settings');
    await tester.pumpWidget(const SizedBox.shrink());
    microphone.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
