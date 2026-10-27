import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/theme/theme.dart';
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
        contributesTools: const [
          PluginToolContribution(
            id: 'svo',
            label: 'S-V-O',
            widgetKey: 'svo_tool_button',
          ),
        ],
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

    testWidgets(
      'tapping subject badge button expands and collapses the sub-dock tool buttons',
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

        // Initially expanded: tool buttons are visible in the sub-dock
        expect(find.byKey(const Key('svo_tool_button')), findsOneWidget);

        // Tap badge button -> collapses sub-dock
        await tester.tap(find.byKey(const Key('subject_badge_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('svo_tool_button')), findsNothing);

        // Tap badge button again -> re-expands sub-dock
        await tester.tap(find.byKey(const Key('subject_badge_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('svo_tool_button')), findsOneWidget);
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

  group('Glass preset control', () {
    InstalledPlugin pluginWithTool(
      String pluginId,
      String toolId,
      String label,
    ) {
      return InstalledPlugin(
        manifest: PluginManifest(
          id: pluginId,
          name: label,
          contributesTools: [
            PluginToolContribution(
              id: toolId,
              label: label,
              widgetKey: '${toolId}_tool_button',
            ),
          ],
        ),
      );
    }

    testWidgets('cycles presets and exposes accessible label and state', (
      tester,
    ) async {
      final plugin = pluginWithTool('test.palette.one', 'draw', 'Draw');
      studio.openPlugin(plugin);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(studio.glassPreset, GlassPreset.frosted);
      expect(find.byKey(const Key('glass_preset_button')), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('glass_preset_button'))).label,
        'Độ trong suốt của thanh công cụ',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('glass_preset_button'))).value,
        'Frosted',
      );

      await tester.tap(find.byKey(const Key('glass_preset_button')));
      await tester.pumpAndSettle();
      expect(studio.glassPreset, GlassPreset.solid);
      expect(
        tester.getSemantics(find.byKey(const Key('glass_preset_button'))).value,
        'Solid',
      );

      await tester.tap(find.byKey(const Key('glass_preset_button')));
      await tester.pumpAndSettle();
      expect(studio.glassPreset, GlassPreset.clear);
      expect(
        tester.getSemantics(find.byKey(const Key('glass_preset_button'))).value,
        'Clear',
      );
    });

    testWidgets('glass preset is keyboard-focusable and activated with Enter', (
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

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(const Key('glass_preset_button')))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      final focusedDecoration =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(const Key('glass_preset_button')),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .single
                  .decoration
              as BoxDecoration;
      expect(focusedDecoration.border!.top.color, Colors.white);
      expect(focusedDecoration.border!.top.width, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(studio.glassPreset, GlassPreset.solid);
    });

    testWidgets('dock button boundaries meet 3:1 against their fills', (
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

      final toolDecoration =
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byKey(const Key('svo_tool_button')),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(
        _contrastRatio(toolDecoration.border!.top.color, toolDecoration.color!),
        greaterThanOrEqualTo(3),
      );
      _expectBoundaryAgainstFixtures(
        toolDecoration.border!.top.color,
        toolDecoration.color!,
      );

      final presetDecoration =
          tester
                  .widgetList<DecoratedBox>(
                    find.descendant(
                      of: find.byKey(const Key('glass_preset_button')),
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .single
                  .decoration
              as BoxDecoration;
      expect(presetDecoration.border, isNotNull);
      expect(
        _contrastRatio(
          presetDecoration.border!.top.color,
          presetDecoration.color!,
        ),
        greaterThanOrEqualTo(3),
      );
      _expectBoundaryAgainstFixtures(
        presetDecoration.border!.top.color,
        presetDecoration.color!,
      );
    });

    testWidgets('keeps tool buttons driven by each manifest contribution', (
      tester,
    ) async {
      studio.openPlugin(pluginWithTool('test.palette.one', 'draw', 'Draw'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draw_tool_button')), findsOneWidget);

      studio.openPlugin(
        pluginWithTool('test.palette.two', 'measure', 'Measure'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('draw_tool_button')), findsNothing);
      expect(find.byKey(const Key('measure_tool_button')), findsOneWidget);
      expect(find.byKey(const Key('glass_preset_button')), findsOneWidget);
    });

    testWidgets('keeps backdrop rendering active while dragging the palette', (
      tester,
    ) async {
      studio.openPlugin(pluginWithTool('test.palette.one', 'draw', 'Draw'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      BackdropFilter paletteFilter() => tester.widget<BackdropFilter>(
        find.descendant(
          of: find.byKey(const Key('subject_tool_palette_surface')),
          matching: find.byType(BackdropFilter),
        ),
      );

      expect(paletteFilter().enabled, isTrue);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('subject_badge_button'))),
      );
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(paletteFilter().enabled, isTrue);

      await gesture.up();
      await tester.pump();
      expect(paletteFilter().enabled, isTrue);
    });
  });

  group('Two-Column Grid Wrapping Tests', () {
    testWidgets(
      '3 buttons wrap into 2 rows with Button 3 aligned under Button 1',
      (tester) async {
        final plugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'test.wrap.three',
            name: 'Wrap Test',
            contributesTools: const [
              PluginToolContribution(
                id: 'btn1',
                label: 'Button 1',
                widgetKey: 'wrap_btn_1',
              ),
              PluginToolContribution(
                id: 'btn2',
                label: 'Button 2',
                widgetKey: 'wrap_btn_2',
              ),
              PluginToolContribution(
                id: 'btn3',
                label: 'Button 3',
                widgetKey: 'wrap_btn_3',
              ),
            ],
          ),
        );
        studio.openPlugin(plugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btn1Box = tester.getRect(find.byKey(const Key('wrap_btn_1')));
        final btn2Box = tester.getRect(find.byKey(const Key('wrap_btn_2')));
        final btn3Box = tester.getRect(find.byKey(const Key('wrap_btn_3')));

        // Row 1: Button 1 and Button 2 side by side
        expect(btn1Box.top, equals(btn2Box.top));
        expect(btn2Box.left, greaterThan(btn1Box.right));

        // Row 2: Button 3 wraps underneath Button 1
        expect(btn3Box.top, greaterThan(btn1Box.bottom));
        expect(btn3Box.left, equals(btn1Box.left));
        expect(btn3Box.width, equals(btn1Box.width));
        expect(btn1Box.width, equals(btn2Box.width));
      },
    );

    testWidgets(
      '4 buttons wrap into 2 rows of 2 columns with vertical grid alignment',
      (tester) async {
        final plugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'test.wrap.four',
            name: 'Wrap Test 4',
            contributesTools: const [
              PluginToolContribution(
                id: 'btn1',
                label: 'Button 1',
                widgetKey: 'wrap4_btn_1',
              ),
              PluginToolContribution(
                id: 'btn2',
                label: 'Button 2',
                widgetKey: 'wrap4_btn_2',
              ),
              PluginToolContribution(
                id: 'btn3',
                label: 'Button 3',
                widgetKey: 'wrap4_btn_3',
              ),
              PluginToolContribution(
                id: 'btn4',
                label: 'Button 4',
                widgetKey: 'wrap4_btn_4',
              ),
            ],
          ),
        );
        studio.openPlugin(plugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btn1Box = tester.getRect(find.byKey(const Key('wrap4_btn_1')));
        final btn2Box = tester.getRect(find.byKey(const Key('wrap4_btn_2')));
        final btn3Box = tester.getRect(find.byKey(const Key('wrap4_btn_3')));
        final btn4Box = tester.getRect(find.byKey(const Key('wrap4_btn_4')));

        // Row 1: Button 1 and Button 2
        expect(btn1Box.top, equals(btn2Box.top));
        // Row 2: Button 3 and Button 4
        expect(btn3Box.top, equals(btn4Box.top));
        expect(btn3Box.top, greaterThan(btn1Box.bottom));

        // Vertical alignment: Column 1
        expect(btn3Box.left, equals(btn1Box.left));
        expect(btn3Box.width, equals(btn1Box.width));

        // Vertical alignment: Column 2
        expect(btn4Box.left, equals(btn2Box.left));
        expect(btn4Box.width, equals(btn2Box.width));
      },
    );

    testWidgets(
      '5 buttons wrap into 3 rows and toolbar width remains strictly constrained to 2 columns',
      (tester) async {
        final plugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'test.wrap.five',
            name: 'Wrap Test 5',
            contributesTools: const [
              PluginToolContribution(id: 'btn1', label: 'B1', widgetKey: 'w5_btn_1'),
              PluginToolContribution(id: 'btn2', label: 'B2', widgetKey: 'w5_btn_2'),
              PluginToolContribution(id: 'btn3', label: 'B3', widgetKey: 'w5_btn_3'),
              PluginToolContribution(id: 'btn4', label: 'B4', widgetKey: 'w5_btn_4'),
              PluginToolContribution(id: 'btn5', label: 'B5', widgetKey: 'w5_btn_5'),
            ],
          ),
        );
        studio.openPlugin(plugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final btn1Box = tester.getRect(find.byKey(const Key('w5_btn_1')));
        final btn2Box = tester.getRect(find.byKey(const Key('w5_btn_2')));
        final btn3Box = tester.getRect(find.byKey(const Key('w5_btn_3')));
        final btn4Box = tester.getRect(find.byKey(const Key('w5_btn_4')));
        final btn5Box = tester.getRect(find.byKey(const Key('w5_btn_5')));

        // Row 1: Button 1 | Button 2
        expect(btn1Box.top, equals(btn2Box.top));
        // Row 2: Button 3 | Button 4
        expect(btn3Box.top, equals(btn4Box.top));
        expect(btn3Box.top, greaterThan(btn1Box.bottom));
        // Row 3: Button 5
        expect(btn5Box.top, greaterThan(btn3Box.bottom));

        // Column 1 alignment across all 3 rows
        expect(btn1Box.left, equals(btn3Box.left));
        expect(btn3Box.left, equals(btn5Box.left));
        expect(btn1Box.width, equals(btn3Box.width));
        expect(btn3Box.width, equals(btn5Box.width));

        // Column 2 alignment across row 1 and row 2
        expect(btn2Box.left, equals(btn4Box.left));
        expect(btn2Box.width, equals(btn4Box.width));

        // Wrap parent container width equals exactly 304.0 (2 columns + 8px gap)
        final wrapWidth = tester.getSize(find.byType(Wrap)).width;
        expect(wrapWidth, equals(304.0));
      },
    );

    testWidgets(
      'plugin badge with "Trợ giảng Tiếng Anh" renders without errors',
      (tester) async {
        final plugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'com.hocluc.plugin.english',
            name: 'Trợ giảng Tiếng Anh',
            contributesTools: const [
              PluginToolContribution(
                id: 'svo',
                label: 'S-V-O',
                widgetKey: 'svo_tool_button',
              ),
            ],
          ),
        );
        studio.openPlugin(plugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final textFinder = find.descendant(
          of: find.byKey(const Key('subject_badge_button')),
          matching: find.text('Trợ giảng Tiếng Anh'),
        );
        expect(textFinder, findsOneWidget);
      },
    );

    testWidgets(
      'hot reload reassemble triggers without LateInitializationError',
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

        // Simulate hot reload reassemble
        tester.binding.reassembleApplication();
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('svo_tool_button')), findsOneWidget);
      },
    );

    testWidgets(
      'single plugin button aligns to left edge of main toolbar and is not centered',
      (tester) async {
        final singleToolPlugin = InstalledPlugin(
          manifest: PluginManifest(
            id: 'test.single.tool',
            name: 'Single Tool Plugin',
            contributesTools: const [
              PluginToolContribution(
                id: 'answer_marker',
                label: 'Đánh dấu đáp án',
                widgetKey: 'answer_marker_tool_button',
              ),
            ],
          ),
        );
        studio.openPlugin(singleToolPlugin);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final topDockRect = tester.getRect(
          find.byKey(const Key('subject_tool_palette_surface')),
        );
        final buttonRect = tester.getRect(
          find.ancestor(
            of: find.byKey(const Key('answer_marker_tool_button')),
            matching: find.byType(LiquidGlassContainer),
          ).first,
        );
        final wrapSize = tester.getSize(find.byType(Wrap));

        // The shared container shares the exact width of the main toolbar (304.0)
        expect(wrapSize.width, equals(topDockRect.width));
        expect(wrapSize.width, equals(304.0));

        // Button aligns to the left boundary of the main toolbar (not centered)
        expect(buttonRect.left, equals(topDockRect.left));
        expect(
          buttonRect.left,
          isNot(equals(topDockRect.left + (topDockRect.width - buttonRect.width) / 2)),
        );

        // Button retains its natural width (148.0)
        expect(buttonRect.width, equals(148.0));
      },
    );
  });

  group('Phase 02: PDF Mode Visual Theme and State Isolation', () {
    test('isPdfMode activates dynamically based on viewport and active PDF', () {
      expect(studio.isPdfMode, isFalse);

      // PDF present but board-only viewport -> isPdfMode is false
      studio.pdfFilePath = 'test.pdf';
      studio.setViewportMode(StudioViewportMode.fullBoard);
      expect(studio.isPdfMode, isFalse);

      // PDF present and split viewport -> isPdfMode is true
      studio.setViewportMode(StudioViewportMode.split);
      expect(studio.isPdfMode, isTrue);

      // PDF present and fullPdf viewport -> isPdfMode is true
      studio.setViewportMode(StudioViewportMode.fullPdf);
      expect(studio.isPdfMode, isTrue);

      // Manual override forces PDF mode
      studio.setPdfMode(false);
      expect(studio.isPdfMode, isFalse);
      studio.setPdfMode(true);
      expect(studio.isPdfMode, isTrue);
      studio.setPdfMode(null);
      expect(studio.isPdfMode, isTrue);

      // Closing PDF restores normal mode
      studio.pdfFilePath = null;
      studio.activeDocId = null;
      expect(studio.isPdfMode, isFalse);
    });

    testWidgets('PDF mode applies high-contrast frosted glass surface and soft shadow', (
      tester,
    ) async {
      studio.openPlugin(dummyPlugin);
      studio.setPdfMode(true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topDock = tester.widget<LiquidGlassContainer>(
        find.byKey(const Key('subject_tool_palette_surface')),
      );
      expect(topDock.backgroundColor, const Color(0xf2111a16));
      expect(topDock.boxShadow, isNotNull);
      expect(topDock.boxShadow!.isNotEmpty, isTrue);

      // Inactive tool button inside PDF mode shares the high-contrast frosted glass surface and soft shadow
      final toolGlass = tester.widget<LiquidGlassContainer>(
        find.ancestor(
          of: find.byKey(const Key('svo_tool_button')),
          matching: find.byType(LiquidGlassContainer),
        ).first,
      );
      expect(toolGlass.backgroundColor, const Color(0xf2111a16));
      expect(toolGlass.boxShadow, isNotNull);
      expect(toolGlass.boxShadow!.isNotEmpty, isTrue);

      final toolDecoration =
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byKey(const Key('svo_tool_button')),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(toolDecoration.color, Colors.transparent);
      expect(
        toolDecoration.border!.top.color,
        AppColors.overlayAccent.withValues(alpha: 0.45),
      );
      expect(
        _contrastRatio(toolDecoration.border!.top.color, toolDecoration.color!),
        greaterThanOrEqualTo(3),
      );
      _expectBoundaryAgainstFixtures(
        toolDecoration.border!.top.color,
        toolDecoration.color!,
      );
    });

    testWidgets('Whiteboard mode preserves transparent surface without dark backdrop tint', (
      tester,
    ) async {
      studio.openPlugin(dummyPlugin);
      studio.setPdfMode(false);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(children: [SubjectToolPalette(studio: studio)]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final topDock = tester.widget<LiquidGlassContainer>(
        find.byKey(const Key('subject_tool_palette_surface')),
      );
      expect(topDock.backgroundColor, isNull);
      expect(topDock.boxShadow, isNull);

      final toolGlass = tester.widget<LiquidGlassContainer>(
        find.ancestor(
          of: find.byKey(const Key('svo_tool_button')),
          matching: find.byType(LiquidGlassContainer),
        ).first,
      );
      expect(toolGlass.backgroundColor, isNull);
      expect(toolGlass.boxShadow, isNull);

      final toolDecoration =
          tester
                  .widget<AnimatedContainer>(
                    find.descendant(
                      of: find.byKey(const Key('svo_tool_button')),
                      matching: find.byType(AnimatedContainer),
                    ),
                  )
                  .decoration!
              as BoxDecoration;
      expect(toolDecoration.color, Colors.transparent);
      expect(toolDecoration.border!.top.color, AppColors.overlayMuted);
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final brightest = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darkest = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (brightest + 0.05) / (darkest + 0.05);
}

void _expectBoundaryAgainstFixtures(Color border, Color fill) {
  const fixtures = [
    Color(0xff14221d),
    Color(0xffffffff),
    Color(0xff000000),
    Color(0xffd50000),
    Color(0xff1e40af),
    Color(0xfffbbf24),
  ];
  for (final fixture in fixtures) {
    final borderContrast = _contrastRatio(border, fixture);
    final fillContrast = _contrastRatio(fill, fixture);
    expect(
      borderContrast >= 3 || fillContrast >= 3,
      isTrue,
      reason: 'The dock control boundary must remain visible over $fixture.',
    );
  }
}
