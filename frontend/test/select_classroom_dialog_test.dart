import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/models/planning_meta.dart';
import 'package:teaching_companion/models/teaching_target.dart';
import 'package:teaching_companion/widgets/dashboard/select_classroom_dialog.dart';

void main() {
  final now = DateTime.now().millisecondsSinceEpoch;
  final samplePlan = PlanningMeta(
    id: 'plan_test_01',
    title: 'Toán 12 - Tích phân từng phần',
    subject: 'Toán',
    pageCount: 3,
    createdAt: now,
    updatedAt: now,
  );

  group('SelectClassroomDialog Widget Tests', () {
    testWidgets(
      'renders dialog with plan info, subject badge and preset classes',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () =>
                      SelectClassroomDialog.show(context, plan: samplePlan),
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        // Open Dialog
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Chọn lớp để bắt đầu dạy'), findsOneWidget);
        expect(find.text('Toán 12 - Tích phân từng phần'), findsOneWidget);
        expect(find.text('Toán'), findsOneWidget);
        expect(find.text('LỚP HỌC TIÊU CHUẨN'), findsOneWidget);
        expect(find.text('Lớp 12A1'), findsOneWidget);
        expect(find.text('Lớp 11A1'), findsOneWidget);
        expect(find.text('Xác nhận & Bắt đầu dạy'), findsOneWidget);
      },
    );

    testWidgets('confirms with selected preset class and triggers onLaunch', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      TeachingTarget? launchedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectClassroomDialog.show(
                  context,
                  plan: samplePlan,
                  onLaunch: (target) async {
                    launchedTarget = target;
                  },
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Select 'Lớp 11A1'
      await tester.tap(find.text('Lớp 11A1'));
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();

      expect(launchedTarget, isNotNull);
      expect(launchedTarget!.planningId, 'plan_test_01');
      expect(launchedTarget!.title, contains('Lớp 11A1'));
      expect(launchedTarget!.title, contains('Toán 12 - Tích phân từng phần'));
      // Dialog should have popped
      expect(find.text('Chọn lớp để bắt đầu dạy'), findsNothing);
    });

    testWidgets('confirms with custom class name entered by teacher', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      TeachingTarget? launchedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectClassroomDialog.show(
                  context,
                  plan: samplePlan,
                  onLaunch: (target) async {
                    launchedTarget = target;
                  },
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter custom class name
      await tester.enterText(
        find.byType(TextField).first,
        'Lớp 12 Chuyên Toán',
      );
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();

      expect(launchedTarget, isNotNull);
      expect(launchedTarget!.planningId, 'plan_test_01');
      expect(launchedTarget!.title, contains('Lớp 12 Chuyên Toán'));
      expect(launchedTarget!.title, contains('Toán 12 - Tích phân từng phần'));
    });

    testWidgets('confirms with custom Google Meet URL entered by teacher', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      TeachingTarget? launchedTarget;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectClassroomDialog.show(
                  context,
                  plan: samplePlan,
                  onLaunch: (target) async {
                    launchedTarget = target;
                  },
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter Meet URL in the second TextField
      await tester.enterText(
        find.byType(TextField).last,
        'https://meet.google.com/abc-defg-hij',
      );
      await tester.pumpAndSettle();

      // Confirm
      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();

      expect(launchedTarget, isNotNull);
      expect(
        launchedTarget!.meetingUrl,
        'https://meet.google.com/abc-defg-hij',
      );
      expect(launchedTarget!.title, contains('Lớp 12A1'));
    });

    testWidgets('dismisses dialog when clicking Hủy', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool called = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectClassroomDialog.show(
                  context,
                  plan: samplePlan,
                  onLaunch: (_) async {
                    called = true;
                  },
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Chọn lớp để bắt đầu dạy'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Chọn lớp để bắt đầu dạy'), findsNothing);
    });
  });
}
