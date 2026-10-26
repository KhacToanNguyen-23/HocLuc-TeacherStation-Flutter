import 'package:teaching_companion/features/studio_board/presentation/widgets/studio_board_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_drawing_toolbar.dart';

Future<void> chord(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  testWidgets('Ctrl Z and both redo shortcuts work while toolbar holds focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final studio = StudioState()
      ..loading = false
      ..showSpeakerNotes = true;
    studio.addStroke(BoardStroke(Colors.white, 4, [const Offset(.3, .3)]));
    studio.addStroke(BoardStroke(Colors.yellow, 4, [const Offset(.5, .5)]));
    await tester.pumpWidget(
      MaterialApp(home: StudioScreen(initialState: studio)),
    );
    await tester.pump();
    final penIcon = find
        .descendant(
          of: find.byType(StudioDrawingToolbar),
          matching: find.byIcon(Icons.edit_outlined),
        )
        .first;
    final toolbarFocus = Focus.of(tester.element(penIcon));
    toolbarFocus.requestFocus();
    await tester.pump();
    expect(toolbarFocus.hasPrimaryFocus, isTrue);
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(studio.strokes, hasLength(1));
    await chord(tester, LogicalKeyboardKey.keyY);
    expect(studio.strokes, hasLength(2));
    await chord(tester, LogicalKeyboardKey.keyZ);
    await chord(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect(studio.strokes, hasLength(2));
    await tester.sendKeyEvent(LogicalKeyboardKey.f2);
    await tester.pump();
    expect(studio.viewportMode, StudioViewportMode.fullPdf);
    await tester.sendKeyEvent(LogicalKeyboardKey.f3);
    await tester.pump();
    expect(studio.viewportMode, StudioViewportMode.split);
    await tester.sendKeyEvent(LogicalKeyboardKey.f1);
    await tester.pump();
    expect(studio.viewportMode, StudioViewportMode.fullBoard);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('text field keyboard shortcuts never consume board history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final studio = StudioState()
      ..loading = false
      ..showSpeakerNotes = true;
    studio.addStroke(BoardStroke(Colors.white, 4, [const Offset(.3, .3)]));
    await tester.pumpWidget(
      MaterialApp(home: StudioScreen(initialState: studio)),
    );
    await tester.pump();
    await tester.tap(find.textContaining('Ghi chú Trang').first);
    await tester.pump();
    final field = find.byType(TextField).first;
    await tester.tap(field);
    await tester.enterText(field, 'Ghi chú của giáo viên');
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(studio.strokes, hasLength(1));
    await chord(tester, LogicalKeyboardKey.keyY);
    expect(studio.strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('read-only board ignores keyboard edit commands', (tester) async {
    final studio = StudioState();
    studio.addStroke(BoardStroke(Colors.white, 4, [const Offset(.3, .3)]));
    await tester.pumpWidget(
      MaterialApp(
        home: StudioBoardShortcuts(
          studio: studio,
          enabled: false,
          child: const SizedBox(),
        ),
      ),
    );
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(studio.strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    studio.dispose();
  });

  testWidgets('dialog focus cannot undo the board behind it', (tester) async {
    final studio = StudioState();
    studio.addStroke(BoardStroke(Colors.white, 4, [const Offset(.3, .3)]));
    await tester.pumpWidget(
      MaterialApp(
        home: StudioBoardShortcuts(studio: studio, child: const SizedBox()),
      ),
    );
    final context = tester.element(find.byType(StudioBoardShortcuts));
    showDialog<void>(
      context: context,
      builder: (context) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    await chord(tester, LogicalKeyboardKey.keyZ);
    expect(studio.strokes, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    studio.dispose();
  });
}
