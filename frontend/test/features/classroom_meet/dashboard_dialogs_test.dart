import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/join_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/schedule_classroom_dialog.dart';

void main() {
  group('JoinClassroomDialog Widget Tests', () {
    testWidgets('renders input and validates meet URL before invoking onJoin', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? joinedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => JoinClassroomDialog(
                    onJoin: (url) async {
                      joinedUrl = url;
                    },
                  ),
                ),
                child: const Text('Open Join'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Join'));
      await tester.pumpAndSettle();

      expect(find.text('Tham gia phòng học'), findsOneWidget);
      expect(find.text('Vào phòng học'), findsOneWidget);

      // Attempt submit without url
      await tester.tap(find.text('Vào phòng học'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập link hoặc mã phòng Google Meet'), findsOneWidget);
      expect(joinedUrl, isNull);

      // Enter invalid URL
      await tester.enterText(find.byType(TextField), 'invalid-url');
      await tester.tap(find.text('Vào phòng học'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mã phòng không hợp lệ'), findsOneWidget);
      expect(joinedUrl, isNull);

      // Enter valid meet code
      await tester.enterText(find.byType(TextField), 'abc-defg-hij');
      await tester.tap(find.text('Vào phòng học'));
      await tester.pumpAndSettle();

      expect(joinedUrl, 'https://meet.google.com/abc-defg-hij');
    });

    testWidgets('cancels dialog when clicking Hủy', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => JoinClassroomDialog.show(context),
                child: const Text('Open Join'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Join'));
      await tester.pumpAndSettle();
      expect(find.text('Tham gia phòng học'), findsOneWidget);

      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Tham gia phòng học'), findsNothing);
    });
  });

  group('ScheduleClassroomDialog Widget Tests', () {
    testWidgets('renders schedule fields and saves classroom session', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => ScheduleClassroomDialog.show(context),
                child: const Text('Open Schedule'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Schedule'));
      await tester.pumpAndSettle();

      expect(find.text('Lên lịch buổi học'), findsOneWidget);
      expect(find.text('Tên bài giảng / Buổi học:'), findsOneWidget);
      expect(find.text('Môn học & Lớp phụ trách:'), findsOneWidget);
      expect(find.text('Lưu lịch học'), findsOneWidget);

      // Save schedule
      await tester.tap(find.text('Lưu lịch học'));
      await tester.pumpAndSettle();

      expect(find.text('Lên lịch buổi học'), findsNothing);
      expect(find.textContaining('Đã lên lịch thành công'), findsOneWidget);
    });
  });
}
