import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/constants/theme.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/screens/studio_screen.dart';
import 'package:teaching_companion/services/meet_automation_service.dart';
import 'package:teaching_companion/services/plugin_manager.dart';
import 'package:teaching_companion/widgets/grid_painter.dart';
import 'package:teaching_companion/widgets/studio/studio_plugins_marketplace_panel.dart';
import 'package:teaching_companion/widgets/studio/studio_top_bar.dart';

const _capture = bool.fromEnvironment('STUDIO_UI_CAPTURE');
final _captureKey = GlobalKey();

Future<StudioState> _pumpStudio(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final state = StudioState()..loading = false;
  MeetAutomationService().setMeetingUrl('https://meet.google.com/abc-defg-hij');
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Manrope',
          scaffoldBackgroundColor: AppColors.paper,
          extensions: [AppColorTheme.light()],
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.sky600,
            primary: AppColors.slate900,
            secondary: AppColors.sky600,
            surface: Colors.white,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(fontSize: 13, color: AppColors.slate900),
          ),
        ),
        home: StudioScreen(initialState: state),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> _screenshot(WidgetTester tester, String name) async {
  if (!_capture) return;
  Tooltip.dismissAllToolTips();
  final previousShadows = debugDisableShadows;
  debugDisableShadows = false;
  void repaint(RenderObject object) {
    object.markNeedsPaint();
    object.visitChildren(repaint);
  }

  repaint(_captureKey.currentContext!.findRenderObject()!);
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/ui-review/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
  debugDisableShadows = previousShadows;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PluginManager().resetForTesting();
  });

  setUpAll(() async {
    if (_capture) {
      for (final name in ['Manrope', 'Literata']) {
        await (FontLoader(
          name,
        )..addFont(rootBundle.load('assets/fonts/$name.ttf'))).load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      final windowsFonts = Platform.environment['WINDIR'];
      if (windowsFonts != null) {
        final bytes = await File(
          '$windowsFonts/Fonts/consola.ttf',
        ).readAsBytes();
        await (FontLoader(
          'monospace',
        )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      }
    }
  });

  for (final size in [
    const Size(1440, 900),
    const Size(1250, 800),
    const Size(1024, 768),
    const Size(768, 680),
    const Size(760, 680),
    const Size(390, 844),
    const Size(320, 568),
  ]) {
    testWidgets('studio actions and Extension fit at ${size.width}', (
      tester,
    ) async {
      final studio = await _pumpStudio(tester, size);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Tài liệu'));
      await tester.pumpAndSettle();
      expect(studio.showQuestionsDrawer, isTrue);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bảng'));
      await tester.pumpAndSettle();
      expect(studio.showQuestionsDrawer, isFalse);
      await tester.tap(find.text('Câu hỏi'));
      await tester.pumpAndSettle();
      expect(studio.view, 'question');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Bảng'));
      await tester.pumpAndSettle();

      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byTooltip('Extension')));
      await tester.pumpAndSettle();
      expect(find.byType(StudioPluginsMarketplacePanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'Extension survives moving into flyout and dismisses on exit, outside tap and Esc',
    (tester) async {
      await _pumpStudio(tester, const Size(1440, 900));
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      Future<void> hoverButton() async {
        await mouse.moveTo(tester.getCenter(find.byTooltip('Extension')));
        await tester.pumpAndSettle();
        expect(find.byType(StudioPluginsMarketplacePanel), findsOneWidget);
      }

      await hoverButton();
      await mouse.moveTo(
        tester.getCenter(find.byType(StudioPluginsMarketplacePanel)),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(StudioPluginsMarketplacePanel), findsOneWidget);
      await _screenshot(tester, 'studio-extension');
      await mouse.moveTo(const Offset(800, 500));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(StudioPluginsMarketplacePanel), findsNothing);

      await hoverButton();
      await tester.tapAt(const Offset(800, 500));
      await tester.pump();
      expect(find.byType(StudioPluginsMarketplacePanel), findsNothing);
      await mouse.moveTo(const Offset(800, 500));
      await hoverButton();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(StudioPluginsMarketplacePanel), findsNothing);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings opens display options and leave icon preserves the leave choices',
    (tester) async {
      await _pumpStudio(tester, const Size(1440, 900));
      await _screenshot(tester, 'studio-main');
      await tester.tap(find.byTooltip('Cài đặt khác'));
      await tester.pumpAndSettle();
      await _screenshot(tester, 'studio-settings');
      await tester.tap(find.text('Cài đặt hiển thị'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hiện lưới bảng'));
      await tester.pumpAndSettle();
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<GridPainter>();
      expect(painters.single.showGrid, isFalse);
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Rời phòng'));
      await tester.pumpAndSettle();
      expect(find.text('Tạm rời phòng'), findsOneWidget);
      expect(find.text('Kết thúc buổi học'), findsOneWidget);
      await tester.tap(find.text('Ở lại tiếp tục dạy'));
      await tester.pumpAndSettle();
      expect(find.byType(StudioTopBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('board page controls, redo and fullscreen keep working', (
    tester,
  ) async {
    final studio = await _pumpStudio(tester, const Size(1440, 900));
    studio.startStroke(const Offset(.3, .3));
    studio.extendStroke(const Offset(.4, .4));
    await tester.pump();
    await tester.tap(find.byTooltip('Hoàn tác nét'));
    await tester.pump();
    expect(studio.strokes, isEmpty);
    await tester.tap(find.byTooltip('Làm lại nét'));
    await tester.pump();
    expect(studio.strokes, hasLength(1));
    await tester.tap(find.byTooltip('Thêm bảng'));
    await tester.pumpAndSettle();
    expect(studio.page, 1);
    expect(studio.strokes, isEmpty);
    await tester.tap(find.byTooltip('Bảng trước'));
    await tester.pumpAndSettle();
    expect(studio.page, 0);
    expect(studio.strokes, hasLength(1));
    await tester.tap(find.byTooltip('Toàn màn hình bảng'));
    await tester.pumpAndSettle();
    expect(find.byType(StudioTopBar), findsNothing);
    expect(find.byTooltip('Thoát toàn màn hình bảng'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(StudioTopBar), findsOneWidget);
    expect(studio.strokes, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
