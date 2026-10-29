import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/floating_plugin_window.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'package:teaching_companion/features/studio_board/presentation/subject_tool_palette.dart';

void main() {
  group('Context-Aware Adaptive Glassmorphism Unit Tests', () {
    test('computeGeometricOverlapRatio calculates precise intersection area', () {
      const plugin = Rect.fromLTWH(100, 100, 100, 100); // Area = 10,000

      // Case 1: Disjoint (no overlap)
      expect(
        computeGeometricOverlapRatio(
          plugin,
          const Rect.fromLTWH(0, 0, 50, 50),
        ),
        0.0,
      );

      // Case 2: Partial overlap (50x50 = 2,500 / 10,000 = 0.25)
      expect(
        computeGeometricOverlapRatio(
          plugin,
          const Rect.fromLTWH(0, 0, 150, 150),
        ),
        closeTo(0.25, 0.001),
      );

      // Case 3: Fully contained (10,000 / 10,000 = 1.0)
      expect(
        computeGeometricOverlapRatio(
          plugin,
          const Rect.fromLTWH(0, 0, 500, 500),
        ),
        1.0,
      );

      // Case 4: Null or empty viewport
      expect(computeGeometricOverlapRatio(plugin, null), 0.0);
      expect(computeGeometricOverlapRatio(plugin, Rect.zero), 0.0);
      expect(computeGeometricOverlapRatio(Rect.zero, plugin), 0.0);
    });

    test('AdaptiveGlassmorphismController enforces hysteresis and prevents flickering', () {
      final controller = AdaptiveGlassmorphismController(
        enterPdfThreshold: 0.20,
        exitPdfThreshold: 0.05,
      );

      expect(controller.isPdfGlass, isFalse);

      // 10% overlap: below enter threshold (0.20) -> stays liquidGlass
      expect(controller.updateOverlap(0.10), isFalse);
      expect(controller.isPdfGlass, isFalse);

      // 19% overlap: still below 0.20 -> stays liquidGlass
      expect(controller.updateOverlap(0.19), isFalse);
      expect(controller.isPdfGlass, isFalse);

      // 20% overlap: meets enter threshold -> transitions to pdfGlass
      expect(controller.updateOverlap(0.20), isTrue);
      expect(controller.isPdfGlass, isTrue);

      // Dragging back: 15% overlap -> above exit threshold (0.05), hysteresis keeps pdfGlass!
      expect(controller.updateOverlap(0.15), isFalse);
      expect(controller.isPdfGlass, isTrue);

      // Dragging back: 8% overlap -> still above 0.05 -> stays pdfGlass!
      expect(controller.updateOverlap(0.08), isFalse);
      expect(controller.isPdfGlass, isTrue);

      // Dragging out: 5% overlap -> reaches exit threshold -> transitions back to liquidGlass!
      expect(controller.updateOverlap(0.05), isTrue);
      expect(controller.isPdfGlass, isFalse);

      // 2% overlap: remains liquidGlass
      expect(controller.updateOverlap(0.02), isFalse);
      expect(controller.isPdfGlass, isFalse);
    });
  });

  group('StudioState Context-Aware PDF Viewport Bounds Tests', () {
    late StudioState studio;

    setUp(() {
      studio = StudioState();
    });

    test('getPdfViewportBounds returns null when no active PDF or in fullBoard', () {
      expect(studio.getPdfViewportBounds(), isNull);

      studio.pdfFilePath = 'doc.pdf';
      studio.setViewportMode(StudioViewportMode.fullBoard);
      expect(studio.getPdfViewportBounds(), isNull);
    });

    test('getPdfViewportBounds covers entire stage in fullPdf or maximized mode', () {
      studio.pdfFilePath = 'doc.pdf';
      studio.setViewportMode(StudioViewportMode.fullPdf);

      const stage = Size(1280, 720);
      expect(
        studio.getPdfViewportBounds(stageSize: stage),
        const Rect.fromLTWH(0, 0, 1280, 720),
      );

      studio.setViewportMode(StudioViewportMode.split);
      studio.pdfWindowMaximized = true;
      expect(
        studio.getPdfViewportBounds(stageSize: stage),
        const Rect.fromLTWH(0, 0, 1280, 720),
      );
    });

    test('getPdfViewportBounds tracks FloatingPdfWindow position and size in split mode', () {
      studio.pdfFilePath = 'doc.pdf';
      studio.setViewportMode(StudioViewportMode.split);
      studio.pdfWindowMaximized = false;

      studio.setPdfWindowPosition(const Offset(600, 0));
      studio.setPdfWindowSize(const Size(500, 720));

      expect(
        studio.getPdfViewportBounds(),
        const Rect.fromLTWH(600, 0, 500, 720),
      );

      // Component on left (100, 100, 304, 100) does not overlap
      final leftBounds = const Rect.fromLTWH(100, 100, 304, 100);
      expect(studio.getPdfOverlapRatio(leftBounds), 0.0);
      expect(studio.isComponentOverlappingPdf(leftBounds), isFalse);

      // Component on right (650, 100, 304, 100) overlaps 100%
      final rightBounds = const Rect.fromLTWH(650, 100, 304, 100);
      expect(studio.getPdfOverlapRatio(rightBounds), 1.0);
      expect(studio.isComponentOverlappingPdf(rightBounds), isTrue);
    });
  });

  group('Adaptive Floating Plugin Widgets Integration Tests', () {
    late StudioState studio;
    late InstalledPlugin dummyPlugin;

    setUp(() {
      studio = StudioState();
      dummyPlugin = InstalledPlugin(
        manifest: PluginManifest(
          id: 'com.hocluc.plugin.adaptive.test',
          name: 'Adaptive Tool',
          contributesTools: const [
            PluginToolContribution(
              id: 'tool_one',
              label: 'Tool One',
              widgetKey: 'tool_one_btn',
            ),
          ],
        ),
      );
    });

    testWidgets(
      'SubjectToolPalette uses Liquid Glass when on chalkboard and PDF Glass when dragged over PDF',
      (tester) async {
        studio.openPlugin(dummyPlugin);
        studio.pdfFilePath = 'lecture.pdf';
        studio.setViewportMode(StudioViewportMode.split);

        // Place PDF window on the right side: (600, 0, 600, 720)
        studio.setPdfWindowPosition(const Offset(600, 0));
        studio.setPdfWindowSize(const Size(600, 720));

        // Place SubjectToolPalette on the left side (chalkboard): (50, 100)
        studio.setSubjectPaletteOffset(const Offset(50, 100));

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(children: [SubjectToolPalette(studio: studio)]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. On Chalkboard: Palette uses Liquid Glass (backgroundColor is null)
        var topDock = tester.widget<LiquidGlassContainer>(
          find.byKey(const Key('subject_tool_palette_surface')),
        );
        expect(
          topDock.backgroundColor,
          isNull,
          reason: 'Palette on chalkboard must retain Liquid Glass appearance',
        );
        var buttonGlass = tester.widget<LiquidGlassContainer>(
          find.ancestor(
            of: find.byKey(const Key('tool_one_btn')),
            matching: find.byType(LiquidGlassContainer),
          ).first,
        );
        expect(
          buttonGlass.backgroundColor,
          isNull,
          reason: 'Tool button on chalkboard must retain Liquid Glass appearance',
        );

        // 2. Drag Palette over PDF window: position (650, 100)
        studio.setSubjectPaletteOffset(const Offset(650, 100));
        await tester.pumpAndSettle();

        topDock = tester.widget<LiquidGlassContainer>(
          find.byKey(const Key('subject_tool_palette_surface')),
        );
        expect(
          topDock.backgroundColor,
          const Color(0xff111a16).withValues(alpha: 0.80),
          reason: 'Palette substantially overlapping PDF must use PDF Glass',
        );
        buttonGlass = tester.widget<LiquidGlassContainer>(
          find.ancestor(
            of: find.byKey(const Key('tool_one_btn')),
            matching: find.byType(LiquidGlassContainer),
          ).first,
        );
        expect(
          buttonGlass.backgroundColor,
          const Color(0xff111a16).withValues(alpha: 0.80),
          reason: 'Tool button over PDF must use PDF Glass frosted surface',
        );

        // 3. Drag back to chalkboard: position (50, 100)
        studio.setSubjectPaletteOffset(const Offset(50, 100));
        await tester.pumpAndSettle();

        topDock = tester.widget<LiquidGlassContainer>(
          find.byKey(const Key('subject_tool_palette_surface')),
        );
        expect(
          topDock.backgroundColor,
          isNull,
          reason: 'Palette returning to chalkboard must restore Liquid Glass',
        );
        buttonGlass = tester.widget<LiquidGlassContainer>(
          find.ancestor(
            of: find.byKey(const Key('tool_one_btn')),
            matching: find.byType(LiquidGlassContainer),
          ).first,
        );
        expect(
          buttonGlass.backgroundColor,
          isNull,
          reason: 'Tool button returning to chalkboard must restore Liquid Glass',
        );
      },
    );

    testWidgets(
      'Multiple plugins have independent theme decisions based on their own display context',
      (tester) async {
        studio.openPlugin(dummyPlugin);
        studio.pluginFloating = true;
        studio.pdfFilePath = 'lecture.pdf';
        studio.setViewportMode(StudioViewportMode.split);

        // PDF window on right: (600, 0, 600, 720)
        studio.setPdfWindowPosition(const Offset(600, 0));
        studio.setPdfWindowSize(const Size(600, 720));

        // SubjectToolPalette placed over PDF: (650, 50)
        studio.setSubjectPaletteOffset(const Offset(650, 50));

        // FloatingPluginWindow placed on chalkboard: (50, 300)
        studio.setPluginFloatingPosition(const Offset(50, 300));
        studio.pluginBridge.pluginFloatingSize = const Size(300, 200);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  SubjectToolPalette(studio: studio),
                  FloatingPluginWindow(studio: studio),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Palette is over PDF -> PDF Glass
        final topDock = tester.widget<LiquidGlassContainer>(
          find.byKey(const Key('subject_tool_palette_surface')),
        );
        expect(
          topDock.backgroundColor,
          const Color(0xff111a16).withValues(alpha: 0.80),
        );

        // FloatingPluginWindow is on chalkboard -> Liquid Glass (overlaySurface)
        final windowMaterial = tester.widget<Material>(
          find.descendant(
            of: find.byType(FloatingPluginWindow),
            matching: find.byType(Material),
          ).first,
        );
        expect(windowMaterial.color, isNot(topDock.backgroundColor));
      },
    );
  });
}
