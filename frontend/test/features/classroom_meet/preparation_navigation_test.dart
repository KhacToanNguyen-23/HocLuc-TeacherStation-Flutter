import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/planning_list_card.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/screens/classroom_dashboard_screen.dart';
import 'package:teaching_companion/features/lesson_preparation/presentation/screens/preparation_workspace_screen.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';

class _Library extends LocalService {
  final plan = PlanningMeta(
    id: 'existing-plan',
    title: 'Water cycle',
    subject: 'Chung',
    pageCount: 1,
    createdAt: 0,
    updatedAt: 0,
  );
  @override
  Future<List<PlanningMeta>> getPlannings() async => [plan];
  @override
  Future<Map<String, dynamic>> getActiveClassroom({
    bool strict = false,
  }) async => {};
  @override
  Future<List<dynamic>> getClassroomHistory({String? teacherId}) async => [];
  @override
  Future<PlanningMeta?> createPlanning({
    required String title,
    required String subject,
    Map<String, dynamic>? content,
  }) async => PlanningMeta(
    id: 'new-plan',
    title: title,
    subject: subject,
    pageCount: 1,
    createdAt: 0,
    updatedAt: 0,
  );
}

class _Routes extends NavigatorObserver {
  MaterialPageRoute<dynamic>? opened;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is MaterialPageRoute) opened = route;
    super.didPush(route, previousRoute);
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final preparation in [false, true]) {
    testWidgets(
      preparation
          ? 'new Soạn bài opens source chooser workspace'
          : 'new Kế hoạch opens Studio planning mode',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = _Library(), routes = _Routes();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [routes],
            home: ClassroomDashboardScreen(localService: library),
          ),
        );
        await tester.pumpAndSettle();
        final tab = find.text(preparation ? 'Soạn bài' : 'Kế hoạch giảng dạy');
        await tester.ensureVisible(tab);
        await tester.tap(tab);
        await tester.pumpAndSettle();
        tester
            .widget<PlanningListCard>(find.byType(PlanningListCard))
            .onCreateNew();
        await tester.pumpAndSettle();
        expect(
          find.text(
            preparation ? 'Tạo bài soạn mới' : 'Tạo kế hoạch giảng dạy',
          ),
          findsOneWidget,
        );
        await tester.enterText(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(TextField),
          ),
          'New QA lesson',
        );
        routes.opened = null;
        await tester.tap(find.text('Bắt đầu soạn'));
        await tester.idle();
        final destination = routes.opened!.builder(
          tester.element(find.byType(ClassroomDashboardScreen)),
        );
        if (preparation) {
          expect(destination, isA<PreparationWorkspaceScreen>());
          expect(
            (destination as PreparationWorkspaceScreen).planningId,
            'new-plan',
          );
          expect(destination.chooseSourceOnOpen, isTrue);
        } else {
          expect(destination, isA<StudioScreen>());
          expect((destination as StudioScreen).planningId, 'new-plan');
          expect(destination.isPlanningMode, isTrue);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        library.client.close();
      },
    );
    testWidgets(
      preparation
          ? 'Soạn bài opens workspace with the existing planning ID'
          : 'Kế hoạch opens Studio without opening the preparation workspace',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final library = _Library(), routes = _Routes();
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [routes],
            home: ClassroomDashboardScreen(localService: library),
          ),
        );
        await tester.pumpAndSettle();
        final planningTab = find.text('Kế hoạch giảng dạy'),
            preparationTab = find.text('Soạn bài');
        expect(
          tester.getTopLeft(planningTab).dx,
          lessThan(tester.getTopLeft(preparationTab).dx),
        );
        await tester.ensureVisible(preparation ? preparationTab : planningTab);
        await tester.tap(preparation ? preparationTab : planningTab);
        await tester.pumpAndSettle();
        final card = tester.widget<PlanningListCard>(
          find.byType(PlanningListCard),
        );
        expect(card.preparationMode, preparation);
        expect(card.plannings.single.id, 'existing-plan');
        expect(
          find.text(preparation ? 'Soạn tiếp' : 'Chỉnh sửa'),
          findsOneWidget,
        );
        expect(
          find.byTooltip('Nhân bản bài soạn'),
          preparation ? findsOneWidget : findsNothing,
        );
        routes.opened = null;
        // Inspect the actual pushed route before mounting the platform-specific editor.
        await tester.tap(find.text(preparation ? 'Soạn tiếp' : 'Chỉnh sửa'));
        final destination = routes.opened!.builder(
          tester.element(find.byType(ClassroomDashboardScreen)),
        );
        if (preparation) {
          expect(destination, isA<PreparationWorkspaceScreen>());
          expect(
            (destination as PreparationWorkspaceScreen).planningId,
            'existing-plan',
          );
        } else {
          expect(destination, isA<StudioScreen>());
          expect((destination as StudioScreen).isPlanningMode, isTrue);
          expect(destination.planningId, 'existing-plan');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        library.client.close();
      },
    );
  }
  testWidgets('each tab preserves its subject filter and dashboard preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final library = _Library();
    final boundary = GlobalKey();
    await tester.runAsync(() async {
      final font = FontLoader('Manrope')
        ..addFont(rootBundle.load('assets/fonts/Manrope.ttf'));
      await font.load();
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ClassroomDashboardScreen(localService: library),
        ),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> tab(String name) async {
      final button = find.text(name).first;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await tab('Kế hoạch giảng dạy');
    tester
        .widget<PlanningListCard>(find.byType(PlanningListCard))
        .onSubjectChanged('Toán');
    await tester.pumpAndSettle();
    await tab('Soạn bài');
    expect(
      tester
          .widget<PlanningListCard>(find.byType(PlanningListCard))
          .selectedSubject,
      'Tất cả',
    );
    await tester.ensureVisible(find.byType(PlanningListCard));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        '../tmp/preparation-navigation-qa/dashboard-preparation.png',
      );
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    tester
        .widget<PlanningListCard>(find.byType(PlanningListCard))
        .onSubjectChanged('Chung');
    await tester.pumpAndSettle();
    await tab('Kế hoạch giảng dạy');
    expect(
      tester
          .widget<PlanningListCard>(find.byType(PlanningListCard))
          .selectedSubject,
      'Toán',
    );
    await tab('Soạn bài');
    expect(
      tester
          .widget<PlanningListCard>(find.byType(PlanningListCard))
          .selectedSubject,
      'Chung',
    );
    await tester.pumpWidget(const SizedBox());
    library.client.close();
  });
  testWidgets('planning and preparation lists fit compact desktop widths', (
    tester,
  ) async {
    for (final width in [600.0, 800.0, 1280.0]) {
      for (final preparation in [false, true]) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PlanningListCard(
                preparationMode: preparation,
                plannings: [_Library().plan],
                isLoading: false,
                selectedSubject: 'Tất cả',
                subjectOptions: const ['Tất cả', 'Sinh học', 'Chung'],
                onSubjectChanged: (_) {},
                onCreateNew: () {},
                onEdit: (_) {},
                onLaunch: (_) {},
                onDelete: (_) {},
                onDuplicate: preparation ? (_) {} : null,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'width=$width preparation=$preparation',
        );
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  testWidgets('empty preparation list keeps its own create action', (
    tester,
  ) async {
    var created = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlanningListCard(
            preparationMode: true,
            plannings: const [],
            isLoading: false,
            selectedSubject: 'Tất cả',
            subjectOptions: const ['Tất cả'],
            onSubjectChanged: (_) {},
            onCreateNew: () => created = true,
            onEdit: (_) {},
            onLaunch: (_) {},
            onDelete: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Chưa có bài soạn'), findsOneWidget);
    await tester.tap(find.text('Soạn bài mới'));
    expect(created, isTrue);
    expect(find.text('Tạo kế hoạch'), findsNothing);
  });
}
