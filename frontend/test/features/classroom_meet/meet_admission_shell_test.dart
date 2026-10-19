import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/services/meet_automation_service.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_shell.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/meet_admission_button.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_drawing_toolbar.dart';
import 'package:teaching_companion/models/studio_state.dart';
import '../../support/meet_admission_fixture.dart';

Widget app(
  MeetAutomationService service, {
  GlobalKey<NavigatorState>? navigatorKey,
  GlobalKey? imageKey,
  StudioState? studio,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: ThemeData(useMaterial3: true, fontFamily: 'Manrope'),
  builder: (_, child) => RepaintBoundary(
    key: imageKey,
    child: MeetAdmissionShell(service: service, child: child!),
  ),
  home: Scaffold(
    backgroundColor: const Color(0xfff4f7fa),
    body: Row(
      children: [
        if (studio != null)
          StudioDrawingToolbar(studio: studio, isVertical: true)
        else
          const SizedBox(
            width: 56,
            child: Center(child: MeetAdmissionButton()),
          ),
        const Expanded(
          child: Center(
            child: Text('Đang giảng dạy', style: TextStyle(fontSize: 28)),
          ),
        ),
      ],
    ),
  ),
);

const menu = Key('meet-admission-menu');
const popup = Key('meet-admission-popup');
const approve = Key('meet-admission-approve-all');

void main() {
  testWidgets('Admission button belongs to the existing pen/eraser toolbar', (
    tester,
  ) async {
    final service = MeetAutomationService.forTesting();
    final studio = StudioState();
    service.setMeetingUrl(room);
    await tester.pumpWidget(app(service, studio: studio));
    expect(
      find.ancestor(
        of: find.byKey(menu),
        matching: find.byType(StudioDrawingToolbar),
      ),
      findsOneWidget,
    );
    final boardPosition = tester.getCenter(find.text('Đang giảng dạy'));
    await tester.tap(find.byKey(menu).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Không còn yêu cầu chờ duyệt.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    seedAdmissions(service);
    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Đang giảng dạy')), boardPosition);
    await tester.tap(find.byKey(menu).hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    final buttonRect = tester.getRect(find.byKey(menu));
    final panelRect = tester.getRect(find.byKey(popup));
    expect(panelRect.left, greaterThan(buttonRect.right));
    await tester.pumpWidget(const SizedBox.shrink());
    studio.dispose();
    service.dispose();
  });

  testWidgets('Unknown accounts cannot be batch-approved or silently cleared', (
    tester,
  ) async {
    final service = MeetAutomationService.forTesting();
    seedAdmissions(service, requests: []);
    service.receiveBridgeMessage(
      message('ADMISSION_QUEUE', {
        'requests': [],
        'unknownCount': 2,
      }, sequence: 3),
    );
    await tester.pumpWidget(app(service));
    await tester.tap(find.byKey(menu).hitTestable());
    await tester.pumpAndSettle();
    expect(find.textContaining('2 yêu cầu chưa đọc được tên'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(approve)).onPressed, isNull);
    expect(find.text('Kiểm tra Meet trong app'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(service.pendingAdmitCount, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });
  testWidgets(
    'Connecting a room during route build safely updates the global menu',
    (tester) async {
      final service = MeetAutomationService.forTesting();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(app(service, navigatorKey: navigator));
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) {
            if (service.pendingAdmitCount == 0) seedAdmissions(service);
            return Scaffold(
              appBar: AppBar(actions: const [MeetAdmissionButton()]),
              body: const Text('Studio'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(menu), findsOneWidget);
      await tester.tap(find.byKey(menu).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );
  testWidgets(
    'Requests never interrupt teaching; menu persists over routes and dialogs; outside/Escape only close box',
    (tester) async {
      final service = MeetAutomationService.forTesting();
      final navigator = GlobalKey<NavigatorState>();
      service.setMeetingUrl(room);
      await tester.pumpWidget(app(service, navigatorKey: navigator));
      final contentPosition = tester.getCenter(find.text('Đang giảng dạy'));
      expect(find.byKey(menu), findsOneWidget);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('meet-admission-dot')))
            .isLabelVisible,
        isFalse,
      );
      seedAdmissions(service);
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.text('Đang giảng dạy')), contentPosition);
      expect(find.byKey(menu), findsOneWidget);
      expect(find.byKey(popup), findsNothing);
      expect(
        tester
            .widget<Badge>(find.byKey(const Key('meet-admission-dot')))
            .isLabelVisible,
        isTrue,
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(actions: const [MeetAdmissionButton()]),
            body: const Text('Kho đề thi'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(menu).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Trần Thị B'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(popup), findsNothing);
      expect(service.pendingAdmitCount, 2);
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(
          title: Text('Hộp thoại khác'),
          actions: [MeetAdmissionButton()],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(menu).hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Văn A'), findsOneWidget);
      await tester.tapAt(const Offset(700, 550));
      await tester.pumpAndSettle();
      expect(find.byKey(popup), findsNothing);
      expect(service.pendingAdmitCount, 2);
      navigator.currentState!.pop();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.byKey(menu), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets(
    'Approve all stays busy until Meet confirms; newcomers need another approval',
    (tester) async {
      final commands = <Map<String, dynamic>>[];
      final service = MeetAutomationService.forTesting(
        executeScript: (script) async {
          commands.add(command(script));
          return jsonEncode({'status': 'PENDING'});
        },
      );
      seedAdmissions(service);
      await tester.pumpWidget(app(service));
      await tester.tap(find.byKey(menu).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(approve));
      await tester.pump();
      expect(commands.length, 1);
      expect(find.text('Đang chờ Meet xác nhận…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(approve)).onPressed,
        isNull,
      );
      service.receiveBridgeMessage(
        message('ADMISSION_QUEUE', {
          'requests': [
            {'id': 'request-a', 'name': 'Nguyễn Văn A'},
            {'id': 'request-b', 'name': 'Trần Thị B'},
            {'id': 'new', 'name': 'Người đến sau'},
          ],
          'unknownCount': 0,
        }, sequence: 3),
      );
      for (var i = 0; i < 2; i++) {
        final sent = commands[i];
        service.receiveBridgeMessage(
          message('ADMISSION_RESULT', {
            ...sent,
            'status': 'CONFIRMED',
          }, sequence: 4 + i),
        );
        await tester.pump();
      }
      expect(commands.map((c) => c['requestId']), ['request-a', 'request-b']);
      expect(service.admissionRequests.single.name, 'Người đến sau');
      expect(find.text('Người đến sau'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(approve)).onPressed,
        isNotNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );

  testWidgets('Failed requests stay visible with an in-app Meet fallback', (
    tester,
  ) async {
    final service = MeetAutomationService.forTesting(
      executeScript: (_) async => jsonEncode({'status': 'NOT_CLICKABLE'}),
    );
    seedAdmissions(
      service,
      requests: [
        {'id': 'request-a', 'name': 'Nguyễn Văn A'},
      ],
    );
    await tester.pumpWidget(app(service));
    await tester.tap(find.byKey(menu).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(approve));
    await tester.pumpAndSettle();
    expect(service.pendingAdmitCount, 1);
    expect(find.textContaining('quyền chủ phòng'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra Meet trong app'));
    await tester.pumpAndSettle();
    expect(find.text('Google Meet trong app'), findsOneWidget);
    expect(find.text('Kết nối Meet trong app'), findsOneWidget);
    service.setMeetingUrl('');
    await tester.pumpAndSettle();
    expect(find.byKey(popup), findsNothing);
    expect(find.byKey(menu), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    service.dispose();
  });

  for (final size in [
    const Size(375, 667),
    const Size(768, 600),
    const Size(1024, 768),
    const Size(1440, 900),
    const Size(600, 300),
  ]) {
    testWidgets('Popup scrolls without overflow at $size with enlarged text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(() async {
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await tester.binding.setSurfaceSize(null);
      });
      final service = MeetAutomationService.forTesting();
      seedAdmissions(
        service,
        requests: List.generate(
          25,
          (i) => {
            'id': 'id-$i',
            'name': 'Nguyễn Thị Minh Anh $i',
            'detail': 'hoc.sinh.$i@example.com',
          },
        ),
      );
      await tester.pumpWidget(app(service));
      await tester.tap(find.byKey(menu).hitTestable());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(popup)).right,
        lessThanOrEqualTo(size.width),
      );
      expect(
        tester.getRect(find.byKey(approve)).bottom,
        lessThanOrEqualTo(size.height),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -5000),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nguyễn Thị Minh Anh 24'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Thị Minh Anh 24').hitTestable(), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    });
  }

  testWidgets('Capture implemented request menu for review', (tester) async {
    const output = String.fromEnvironment('ADMISSION_PREVIEW');
    if (output.isEmpty) return;
    await tester.runAsync(() async {
      await (FontLoader(
        'Manrope',
      )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    final oldShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = oldShadows);
    await tester.binding.setSurfaceSize(const Size(1024, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = MeetAutomationService.forTesting();
    seedAdmissions(
      service,
      requests: [
        {'id': 'a', 'name': 'Nguyễn Minh Anh', 'detail': 'minhanh@example.com'},
        {'id': 'b', 'name': 'Trần Gia Bảo', 'detail': 'giabao@example.com'},
        {'id': 'c', 'name': 'Lê Khánh Linh', 'detail': 'khanhlinh@example.com'},
      ],
    );
    final key = GlobalKey();
    final studio = StudioState();
    await tester.pumpWidget(app(service, imageKey: key, studio: studio));
    await tester.tap(find.byKey(menu).hitTestable());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(output).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    debugDisableShadows = oldShadows;
    await tester.pumpWidget(const SizedBox.shrink());
    studio.dispose();
    service.dispose();
  });
}


