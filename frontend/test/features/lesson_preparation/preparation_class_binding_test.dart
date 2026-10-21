import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/classroom_meet/presentation/dashboard/select_classroom_dialog.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/planning_meta.dart';
import 'package:teaching_companion/features/classroom_meet/domain/models/teaching_target.dart';
import 'package:teaching_companion/features/studio_board/domain/models/board_sticker.dart';

void main() {
  final plan = PlanningMeta(
    id: 'variant',
    title: 'Adapted lesson',
    createdAt: 0,
    updatedAt: 0,
  );
  test('public board image ID survives lesson serialization', () {
    final original = BoardSticker(
      id: 'image',
      type: 'lesson_image',
      normalizedRect: const Rect.fromLTWH(0, 0, 1, 1),
      rawText: 'Context',
      imageAssetId: 'owned-image',
    );
    expect(
      BoardSticker.fromJson(original.toJson()).imageAssetId,
      'owned-image',
    );
    expect(
      original.copyWith(rawText: 'Changed title').imageAssetId,
      'owned-image',
    );
  });
  testWidgets('local class binding is selected instead of the default preset', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TeachingTarget? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => SelectClassroomDialog.show(
                context,
                plan: plan,
                preferredClassName: 'Class B',
                onLaunch: (target) async {
                  launched = target;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
    await tester.pumpAndSettle();
    expect(launched?.title, contains('Class B'));
    expect(launched?.planningId, 'variant');
  });
  testWidgets(
    'missing bound Google class cannot silently fall back to another class',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var launches = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => SelectClassroomDialog.show(
                  context,
                  plan: plan,
                  preferredCourseId: 'unavailable',
                  preferredClassName: 'Class B',
                  onLaunch: (_) async {
                    launches++;
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận & Bắt đầu dạy'));
      await tester.pumpAndSettle();
      expect(launches, 0);
      expect(
        find.text('Chọn lớp Google Classroom trước khi dạy.'),
        findsOneWidget,
      );
    },
  );
}
