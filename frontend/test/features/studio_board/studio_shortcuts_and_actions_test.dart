import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/app_theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/screens/studio_screen.dart';
import 'package:teaching_companion/features/studio_board/presentation/stage_container.dart';
import 'package:teaching_companion/features/studio_board/presentation/studio/studio_preview_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Studio Board Keyboard Shortcuts & Focus Immunity Tests', () {
    testWidgets(
        'P, H, E, L switch drawing tools when canvas is active',
        (tester) async {
      final studio = StudioState()
        ..loading = false
        ..tool = 'pen';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StageContainer(studio: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default tool is pen
      expect(studio.tool, 'pen');

      // Press 'H' -> tool switches to highlight
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pumpAndSettle();
      expect(studio.tool, 'highlight');

      // Press 'E' -> tool switches to erase
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      await tester.pumpAndSettle();
      expect(studio.tool, 'erase');

      // Press 'L' -> tool switches to laser
      await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
      await tester.pumpAndSettle();
      expect(studio.tool, 'laser');

      // Press 'P' -> tool switches back to pen
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(studio.tool, 'pen');
    });

    testWidgets(
        'Single-letter shortcuts (P, H, E, L) do NOT switch tools when typing in TextField',
        (tester) async {
      final studio = StudioState()
        ..loading = false
        ..tool = 'pen';
      final textController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('test-field'),
                  controller: textController,
                ),
                Expanded(child: StageContainer(studio: studio)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Focus the text field
      await tester.tap(find.byKey(const ValueKey('test-field')));
      await tester.pumpAndSettle();

      // Type text containing 'h', 'e', 'l', 'p'
      await tester.enterText(
        find.byKey(const ValueKey('test-field')),
        'help',
      );
      await tester.pumpAndSettle();

      // The tool must REMAIN 'pen', NOT accidentally changed by 'h', 'e', 'l'
      expect(studio.tool, 'pen');
      expect(textController.text, 'help');
    });

    testWidgets('Ctrl+Z and Ctrl+Y trigger undo and redo', (tester) async {
      final studio = StudioState()
        ..loading = false
        ..tool = 'pen';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StageContainer(studio: studio),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate drawing: add stroke to studio
      studio.addStroke(
        BoardStroke(
          const Color(0xFFF0F3ED),
          2.0,
          [const Offset(10, 10), const Offset(20, 20)],
        ),
      );
      expect(studio.strokes.length, 1);
      expect(studio.canUndo, isTrue);

      // Press Ctrl+Z -> undo
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(studio.strokes.length, 0);
      expect(studio.canRedo, isTrue);

      // Press Ctrl+Y -> redo
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(studio.strokes.length, 1);
    });

    testWidgets('F5 shortcut triggers presentation preview dialog',
        (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final studio = StudioState()..loading = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: StudioScreen(initialState: studio),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StudioPreviewDialog), findsNothing);

      // Press F5
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();

      // Expect preview dialog to be shown
      expect(find.byType(StudioPreviewDialog), findsOneWidget);
      expect(find.text('Xem trước bảng trình bày'), findsOneWidget);

      // Close preview dialog via close button
      final closeButton = find.byTooltip('Đóng xem trước');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(find.byType(StudioPreviewDialog), findsNothing);
    });
  });
}
