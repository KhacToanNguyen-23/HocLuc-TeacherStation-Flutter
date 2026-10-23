import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/presentation/glass_region_overlay.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';

void main() {
  const token = 'overlay-test-view';
  final service = GlassRegionService.instance;

  setUp(() {
    service.beginNavigation(token);
    service.handleMessage(
      viewToken: token,
      pluginId: 'test.glass.overlay',
      navigationGeneration: service.currentGeneration(token)!,
      action: 'glass:register',
      payload: const {
        'region_id': 'card',
        'bounds': {'x': 24, 'y': 38, 'width': 180, 'height': 90},
        'viewport': {'width': 360, 'height': 180},
        'visible': true,
      },
      webViewBounds: const Rect.fromLTWH(0, 0, 360, 180),
    );
  });

  tearDown(() => service.disposeView(token));

  testWidgets('aligns visual-only shader bounds to the registered region', (
    tester,
  ) async {
    expect(service.regionFor(token, 'card'), isNotNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 180,
            child: GlassRegionOverlay(
              viewToken: token,
              preset: GlassPreset.frosted,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));

    final surface = find.byType(LiquidGlassContainer);
    expect(surface, findsOneWidget);
    expect(tester.getRect(surface), const Rect.fromLTWH(24, 38, 180, 90));
    expect(
      find.byKey(const ValueKey('glass_region_overlay_pointer_blocker')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('glass_region_overlay_semantics')),
      findsOneWidget,
    );
  });
}
