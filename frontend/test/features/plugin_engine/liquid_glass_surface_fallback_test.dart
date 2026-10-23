import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';

void main() {
  testWidgets('glass surface clips its child to the rounded bounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 180,
          height: 120,
          child: LiquidGlassContainer(
            preset: GlassPreset.frosted,
            child: SizedBox.expand(child: ColoredBox(color: Colors.deepPurple)),
          ),
        ),
      ),
    );

    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));
    expect(clip.borderRadius, const BorderRadius.all(Radius.circular(16)));
    expect(clip.clipBehavior, Clip.antiAlias);
  });

  testWidgets('fallback glass surface stays visible while the dock moves', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LiquidGlassContainer(
          preset: GlassPreset.frosted,
          shaderFilterSupported: false,
          child: Text('Fallback content'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('glass_shader_fallback')), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
    expect(find.text('Fallback content'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LiquidGlassContainer),
        matching: find.byType(Container),
      ),
      findsOneWidget,
      reason:
          'The gradient backing and child remain even when blur is skipped.',
    );
  });
}
