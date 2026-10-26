import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/domain/models/plugin_manifest.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_event_hub.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

void main() {
  group('GlassPreset', () {
    test('cycles clear, frosted, solid, then clear', () {
      expect(GlassPreset.clear.next, GlassPreset.frosted);
      expect(GlassPreset.frosted.next, GlassPreset.solid);
      expect(GlassPreset.solid.next, GlassPreset.clear);
    });

    test('maps presets to the specified opacity and blur values', () {
      expect(GlassPreset.clear.opacity, closeTo(0.15, 0.0001));
      expect(GlassPreset.clear.blurSigma, 10);
      expect(GlassPreset.frosted.opacity, closeTo(0.28, 0.0001));
      expect(GlassPreset.frosted.blurSigma, 20);
      expect(GlassPreset.solid.opacity, closeTo(0.85, 0.0001));
      expect(GlassPreset.solid.blurSigma, 28);
    });

    test('gives each preset distinct refraction and lighting values', () {
      final presets = GlassPreset.values;

      expect(presets.map((preset) => preset.refraction).toSet(), hasLength(3));
      expect(
        presets.map((preset) => preset.rimIntensity).toSet(),
        hasLength(3),
      );
      expect(
        presets.map((preset) => preset.specularIntensity).toSet(),
        hasLength(3),
      );
    });
  });

  testWidgets('exposes a stable marker when shader filtering is unsupported', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidGlassContainer(
            preset: GlassPreset.frosted,
            shaderFilterSupported: false,
            child: const Text('Palette'),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('glass_shader_fallback')), findsOneWidget);
    expect(find.byKey(const ValueKey('glass_shader_filter')), findsNothing);
  });

  testWidgets('clips renderer to the configured rounded bounds', (
    tester,
  ) async {
    const radius = BorderRadius.all(Radius.circular(23));
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidGlassContainer(
            preset: GlassPreset.frosted,
            borderRadius: radius,
            shaderFilterSupported: false,
            child: const Text('Palette'),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(
      find.ancestor(
        of: find.byKey(const ValueKey('glass_shader_fallback')),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(clip.borderRadius, radius);
  });

  testWidgets('glass shell keeps an edge against dark and light fixtures', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: LiquidGlassContainer(
            preset: GlassPreset.frosted,
            borderColor: AppColors.overlayMuted,
            child: const Text('Palette'),
          ),
        ),
      ),
    );

    final borders = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(LiquidGlassContainer),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((widget) => (widget.decoration as BoxDecoration).border)
        .whereType<Border>()
        .map((border) => border.top.color)
        .toSet();
    expect(borders, contains(const Color(0xff0b2348)));
    expect(borders, contains(const Color(0xffc4d6ec)));
    const fixtures = [
      Color(0xff14221d),
      Color(0xffffffff),
      Color(0xff000000),
      Color(0xffd50000),
      Color(0xff1e40af),
      Color(0xfffbbf24),
    ];
    for (final fixture in fixtures) {
      expect(
        borders.any((border) => _contrastRatio(border, fixture) >= 3),
        isTrue,
        reason: 'The palette shell must keep a visible edge over $fixture.',
      );
    }
  });

  group('StudioState glass preset', () {
    late StudioState studio;
    late InstalledPlugin plugin;
    final scripts = <String>[];
    late void Function(String) sender;

    setUp(() {
      studio = StudioState();
      plugin = InstalledPlugin(
        manifest: PluginManifest(id: 'test.glass.runtime', name: 'Test'),
      );
      studio.openPlugin(plugin);
      scripts.clear();
      sender = scripts.add;
      PluginEventHub.instance.register(plugin.id, sender);
      scripts.clear();
    });

    tearDown(() {
      PluginEventHub.instance.unregister(plugin.id, sender);
      studio.dispose();
    });

    test('starts frosted and emits one generic host event per real change', () {
      expect(studio.glassPreset, GlassPreset.frosted);
      expect(scripts, isEmpty);

      studio.setGlassPreset(GlassPreset.clear);
      studio.setGlassPreset(GlassPreset.clear);

      expect(studio.glassPreset, GlassPreset.clear);
      expect(scripts, hasLength(1));
      expect(scripts.single, contains('"event":"GLASS_PRESET_CHANGE"'));
      expect(scripts.single, contains('"preset":"clear"'));
    });

    test('notifies a separately mounted floating plugin too', () {
      final floatingPlugin = InstalledPlugin(
        manifest: PluginManifest(
          id: 'test.glass.floating',
          name: 'Floating test',
        ),
      );
      final floatingScripts = <String>[];
      void floatingSender(String script) => floatingScripts.add(script);
      studio.floatingPlugin = floatingPlugin;
      PluginEventHub.instance.register(floatingPlugin.id, floatingSender);
      floatingScripts.clear();

      studio.setGlassPreset(GlassPreset.clear);

      expect(scripts, hasLength(1));
      expect(floatingScripts, hasLength(1));
      expect(floatingScripts.single, contains('"preset":"clear"'));
      PluginEventHub.instance.unregister(floatingPlugin.id, floatingSender);
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
