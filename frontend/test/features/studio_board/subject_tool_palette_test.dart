import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/presentation/subject_tool_palette.dart';

void main() {
  late StudioState studio;
  late InstalledPlugin dummyPlugin;

  setUp(() {
    studio = StudioState();
    dummyPlugin = InstalledPlugin(
      manifest: PluginManifest(
        id: 'com.hocluc.plugin.english',
        name: 'Tiếng Anh',
      ),
    );
  });

  group('Phase 01: Subject Tool Palette Dock Tests', () {
    testWidgets(
      'renders SubjectToolPalette with badge, SVO button, eye toggle, and close button',
      (tester) async {
        studio.openPlugin(dummyPlugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Plugin badge
        expect(find.text('Tiếng Anh'), findsOneWidget);
        // S-V-O Tool button
        expect(find.byKey(const Key('svo_tool_button')), findsOneWidget);
        // Eye toggle button
        expect(find.byKey(const Key('eye_toggle_button')), findsOneWidget);
        // Close button
        expect(find.byKey(const Key('close_palette_button')), findsOneWidget);
      },
    );

    testWidgets('tapping S-V-O button toggles activeSubjectTool state', (
      tester,
    ) async {
      studio.openPlugin(dummyPlugin);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(studio.activeSubjectTool, isNull);

      // Tap S-V-O tool button -> becomes 'svo'
      await tester.tap(find.byKey(const Key('svo_tool_button')));
      await tester.pumpAndSettle();
      expect(studio.activeSubjectTool, equals('svo'));

      // Tap again -> becomes null
      await tester.tap(find.byKey(const Key('svo_tool_button')));
      await tester.pumpAndSettle();
      expect(studio.activeSubjectTool, isNull);
    });

    testWidgets(
      'tapping eye toggle button switches chalkAnnotationsVisible state',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        studio.openPlugin(dummyPlugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(studio.chalkAnnotationsVisible, isTrue);

        // Tap eye button -> becomes false
        await tester.tap(find.byKey(const Key('eye_toggle_button')));
        await tester.pumpAndSettle();
        expect(studio.chalkAnnotationsVisible, isFalse);

        // Tap eye button again -> becomes true
        await tester.tap(find.byKey(const Key('eye_toggle_button')));
        await tester.pumpAndSettle();
        expect(studio.chalkAnnotationsVisible, isTrue);
      },
    );

    testWidgets(
      'tapping close button calls closePlugin and clears activeSubjectTool',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        studio.openPlugin(dummyPlugin);
        studio.setActiveSubjectTool('svo');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('close_palette_button')));
        await tester.pumpAndSettle();

        expect(studio.activePlugin, isNull);
        expect(studio.activeSubjectTool, isNull);
      },
    );

    test(
      'selecting main tool (pen, erase, highlight) automatically resets activeSubjectTool',
      () {
        studio.setActiveSubjectTool('svo');
        expect(studio.activeSubjectTool, equals('svo'));

        studio.tool = 'pen';
        expect(studio.activeSubjectTool, isNull);

        studio.setActiveSubjectTool('svo');
        studio.tool = 'erase';
        expect(studio.activeSubjectTool, isNull);
      },
    );
  });
}

