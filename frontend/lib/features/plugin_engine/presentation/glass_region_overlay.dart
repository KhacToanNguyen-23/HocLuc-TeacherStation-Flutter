import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/glass_preset.dart';
import 'package:teaching_companion/core/widgets/liquid_glass_container.dart';
import 'package:teaching_companion/features/plugin_engine/services/glass_region_service.dart';

/// Paints host-owned glass surfaces below their WebView and outside its
/// pointer and semantics trees. Regions use global logical bounds from the
/// host's WebView RenderBox and are translated into this viewport.
class GlassRegionOverlay extends StatelessWidget {
  const GlassRegionOverlay({
    super.key,
    required this.viewToken,
    required this.preset,
  });

  final String viewToken;
  final GlassPreset preset;

  @override
  Widget build(BuildContext context) {
    final service = GlassRegionService.instance;
    return IgnorePointer(
      key: const ValueKey('glass_region_overlay_pointer_blocker'),
      child: ExcludeSemantics(
        key: const ValueKey('glass_region_overlay_semantics'),
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            final regions = service.regionsFor(viewToken);
            return ClipRect(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  for (final region in regions)
                    Positioned.fromRect(
                      key: ValueKey(
                        'glass_region_${region.viewToken}_${region.regionId}',
                      ),
                      rect: region.localBounds,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: LiquidGlassContainer(
                          preset: preset,
                          borderRadius: BorderRadius.circular(18),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
