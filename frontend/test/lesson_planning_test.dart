import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/planning_meta.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'package:teaching_companion/widgets/dashboard/planning_list_card.dart';
import 'package:teaching_companion/widgets/studio/studio_top_bar.dart';

void main() {
  group('Lesson Planning Model Tests', () {
    test('PlanningMeta serialization and deserialization', () {
      final now = DateTime(2026, 10, 14, 10, 30).millisecondsSinceEpoch;
      final plan = PlanningMeta(
        id: 'plan_123',
        title: 'Toán 10 - Hệ bất phương trình',
        subject: 'Toán',
        pageCount: 3,
        createdAt: now,
        updatedAt: now,
      );

      final json = plan.toJson();
      expect(json['id'], 'plan_123');
      expect(json['title'], 'Toán 10 - Hệ bất phương trình');
      expect(json['subject'], 'Toán');
      expect(json['pageCount'], 3);

      final restored = PlanningMeta.fromJson(json);
      expect(restored.id, plan.id);
      expect(restored.title, plan.title);
      expect(restored.subject, plan.subject);
      expect(restored.pageCount, plan.pageCount);
      expect(restored.formattedUpdatedAt.contains('10:30'), isTrue);
    });
  });

  group('PlanningListCard Widget Tests', () {
    testWidgets('renders empty state when plannings list is empty', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool createdNew = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlanningListCard(
              plannings: const [],
              isLoading: false,
              selectedSubject: 'Tất cả',
              subjectOptions: const ['Tất cả', 'Toán', 'Tiếng Anh'],
              onSubjectChanged: (_) {},
              onCreateNew: () => createdNew = true,
              onEdit: (_) {},
              onLaunch: (_) {},
              onDelete: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Chưa có kế hoạch bài giảng'), findsOneWidget);
      expect(find.text('Soạn bài mới'), findsOneWidget);

      await tester.tap(find.text('Soạn bài mới'));
      expect(createdNew, isTrue);
    });

    testWidgets('renders list of planning cards and handles callbacks', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now().millisecondsSinceEpoch;
      final plans = [
        PlanningMeta(
          id: 'plan_01',
          title: 'Tiếng Anh 11 - Unit 1',
          subject: 'Tiếng Anh',
          pageCount: 2,
          createdAt: now,
          updatedAt: now,
        ),
        PlanningMeta(
          id: 'plan_02',
          title: 'Toán 12 - Tích phân',
          subject: 'Toán',
          pageCount: 4,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      PlanningMeta? editedPlan;
      PlanningMeta? launchedPlan;
      PlanningMeta? deletedPlan;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 400,
              child: PlanningListCard(
                plannings: plans,
                isLoading: false,
                selectedSubject: 'Tất cả',
                subjectOptions: const ['Tất cả', 'Toán', 'Tiếng Anh'],
                onSubjectChanged: (_) {},
                onCreateNew: () {},
                onEdit: (p) => editedPlan = p,
                onLaunch: (p) => launchedPlan = p,
                onDelete: (p) => deletedPlan = p,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Tiếng Anh 11 - Unit 1'), findsOneWidget);
      expect(find.text('Toán 12 - Tích phân'), findsOneWidget);
      expect(find.text('2 trang'), findsOneWidget);
      expect(find.text('4 trang'), findsOneWidget);

      // Tap Soạn tiếp
      await tester.tap(find.text('Soạn tiếp').first);
      expect(editedPlan?.id, 'plan_01');

      // Tap Dạy ngay
      await tester.tap(find.text('Dạy ngay').first);
      expect(launchedPlan?.id, 'plan_01');

      // Tap Xóa
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      expect(deletedPlan?.id, 'plan_01');
    });
  });

  group('StudioTopBar Planning Mode Tests', () {
    testWidgets('displays Planning badge and action buttons without Leave Room button', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioState()
        ..online = true
        ..loading = false;
      bool exited = false;
      bool launched = false;
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1280,
              height: 60,
              child: StudioTopBar(
                studio: studio,
                width: 1280,
                hasLessons: false,
                hasInspector: false,
                onToggleLessons: () {},
                onToggleInspector: () {},
                onRename: () {},
                onPreview: () {},
                onSave: () => saved = true,
                onRetryConnect: () {},
                isPlanningMode: true,
                onExitPlanning: () => exited = true,
                onCreateClassroomFromPlanning: () => launched = true,
              ),
            ),
          ),
        ),
      );

      // Verify planning badge
      expect(find.text('Kế hoạch bài giảng'), findsOneWidget);

      // Verify Thoát, Lưu bài soạn, and Tạo phòng học buttons
      expect(find.text('Thoát'), findsOneWidget);
      expect(find.text('Lưu bài soạn'), findsOneWidget);
      expect(find.text('Tạo phòng học'), findsOneWidget);

      // Verify Leave Room button is absent
      expect(find.text('Rời phòng'), findsNothing);

      // Tap Thoát
      await tester.tap(find.text('Thoát'));
      expect(exited, isTrue);

      // Tap Lưu bài soạn
      await tester.tap(find.text('Lưu bài soạn'));
      expect(saved, isTrue);

      // Tap Tạo phòng học
      await tester.tap(find.text('Tạo phòng học'));
      expect(launched, isTrue);
    });
  });
}
