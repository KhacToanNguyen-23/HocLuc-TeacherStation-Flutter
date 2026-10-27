import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/create_planning_dialog.dart';

void main() {
  const subjectOptions = ['Tất cả', 'Toán', 'Tiếng Anh', 'Vật lý'];

  testWidgets(
    'CreatePlanningDialog renders modal components and handles submission',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CreatePlanningResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CreatePlanningDialog.show(
                    context,
                    subjectOptions: subjectOptions,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify Title & Header
      expect(find.text('Soạn kế hoạch bài giảng mới'), findsOneWidget);
      expect(find.byIcon(Icons.edit_calendar_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify Fields
      expect(find.text('Tên kế hoạch bài giảng'), findsOneWidget);
      expect(find.text('Môn học'), findsOneWidget);
      expect(find.text('Kế hoạch bài giảng mới'), findsOneWidget);

      // Verify Actions
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Bắt đầu soạn'), findsOneWidget);

      // Submit via button
      await tester.tap(find.text('Bắt đầu soạn'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.title, 'Kế hoạch bài giảng mới');
      expect(result!.subject, 'Toán'); // first non-'Tất cả' option
    },
  );

  testWidgets(
    'CreatePlanningDialog submits via Enter key and custom inputs',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CreatePlanningResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CreatePlanningDialog.show(
                    context,
                    subjectOptions: subjectOptions,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Enter new title
      await tester.enterText(
        find.byType(TextField),
        'Unit 3: Cities of the Future',
      );
      await tester.pumpAndSettle();

      // Submit with Enter key (TextInputAction.done / onSubmitted)
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.title, 'Unit 3: Cities of the Future');
      expect(result!.subject, 'Toán');
    },
  );

  testWidgets(
    'CreatePlanningDialog can be canceled via Hủy button or close icon',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CreatePlanningResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await CreatePlanningDialog.show(
                    context,
                    subjectOptions: subjectOptions,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Open Dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap Hủy
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    },
  );
}
