import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';

/// Compact Color Wheel Flyout (Clean 190px width, instant pick, non-blocking)
class ColorWheelCompactFlyout extends StatelessWidget {
  const ColorWheelCompactFlyout({
    super.key,
    required this.studio,
    this.onClose,
  });

  final StudioState studio;
  final VoidCallback? onClose;

  static const List<double> wheelHues = [
    60,
    50,
    40,
    30,
    20,
    10,
    0,
    345,
    330,
    310,
    290,
    270,
    250,
    230,
    210,
    195,
    180,
    165,
    150,
    135,
    120,
    105,
    90,
    75,
  ];

  static const List<(double lightness, double saturation)> wheelRings = [
    (0.20, 0.95), // Ring 0: Innermost dark shade
    (0.32, 0.90), // Ring 1: Dark
    (0.44, 0.90), // Ring 2: Medium dark
    (0.56, 0.95), // Ring 3: Vibrant core
    (0.70, 0.85), // Ring 4: Medium light
    (0.84, 0.70), // Ring 5: Outermost pastel tint
  ];

  @override
  Widget build(BuildContext context) {
    final currentColor = studio.ink;
    final hexCode =
        '#${(currentColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 195,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffd5dcd2), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 18,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mini Header
            Row(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hexCode,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff173e35),
                  ),
                ),
                const Spacer(),
                if (onClose != null)
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 14, color: Colors.black45),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Compact 24-Sector Color Wheel (diameter 155px)
            SizedBox(
              width: 155,
              height: 155,
              child: ColorWheelInteractive(
                selectedColor: currentColor,
                hues: wheelHues,
                rings: wheelRings,
                onColorSelected: (c) => studio.setCustomColor(c),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback Compact Color Wheel Dialog (used if called via dialog)
class ColorWheelDialog extends StatelessWidget {
  const ColorWheelDialog({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: ColorWheelCompactFlyout(
          studio: studio,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class ColorWheelInteractive extends StatelessWidget {
  const ColorWheelInteractive({
    super.key,
    required this.selectedColor,
    required this.hues,
    required this.rings,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final List<double> hues;
  final List<(double lightness, double saturation)> rings;
  final ValueChanged<Color> onColorSelected;

  void _handlePointer(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final offset = localPos - center;
    final r = offset.distance;
    final maxR = size.width / 2;
    final minR = 14.0;

    if (r < minR || r > maxR) return;

    // Angle calculation: top is -pi/2, convert to 0..2pi clockwise
    var angle = math.atan2(offset.dy, offset.dx);
    // Align angle so top (-pi/2) corresponds to index 0
    var normalizedAngle = angle + math.pi / 2;
    if (normalizedAngle < 0) normalizedAngle += 2 * math.pi;

    final sectorWidth = (2 * math.pi) / hues.length;
    final sectorIndex = (normalizedAngle / sectorWidth).floor() % hues.length;

    final ringWidth = (maxR - minR) / rings.length;
    final ringIndex = ((r - minR) / ringWidth).floor().clamp(
      0,
      rings.length - 1,
    );

    final hue = hues[sectorIndex];
    final (lightness, saturation) = rings[ringIndex];
    final color = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    onColorSelected(color);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (d) => _handlePointer(d.localPosition, size),
          onPanUpdate: (d) => _handlePointer(d.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: ColorWheelPainter(
              hues: hues,
              rings: rings,
              selectedColor: selectedColor,
            ),
          ),
        );
      },
    );
  }
}

class ColorWheelPainter extends CustomPainter {
  ColorWheelPainter({
    required this.hues,
    required this.rings,
    required this.selectedColor,
  });

  final List<double> hues;
  final List<(double lightness, double saturation)> rings;
  final Color selectedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final minR = 14.0;
    final ringWidth = (maxR - minR) / rings.length;
    final sectorAngle = (2 * math.pi) / hues.length;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    for (int s = 0; s < hues.length; s++) {
      final startAngle = -math.pi / 2 + s * sectorAngle;
      final hue = hues[s];

      for (int r = 0; r < rings.length; r++) {
        final innerR = minR + r * ringWidth;
        final outerR = innerR + ringWidth;
        final (lightness, saturation) = rings[r];
        final color = HSLColor.fromAHSL(
          1.0,
          hue,
          saturation,
          lightness,
        ).toColor();

        fillPaint.color = color;

        final path = Path()
          ..arcTo(
            Rect.fromCircle(center: center, radius: outerR),
            startAngle,
            sectorAngle,
            false,
          )
          ..arcTo(
            Rect.fromCircle(center: center, radius: innerR),
            startAngle + sectorAngle,
            -sectorAngle,
            false,
          )
          ..close();

        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, linePaint);
      }
    }

    // Center circular hub shows the active color
    final centerPaint = Paint()..color = selectedColor;
    canvas.drawCircle(center, minR, centerPaint);
    final centerBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, minR, centerBorder);
  }

  @override
  bool shouldRepaint(covariant ColorWheelPainter oldDelegate) {
    return oldDelegate.selectedColor != selectedColor;
  }
}

/// Minimalist Tool Size Dropdown (Clean horizontal stroke lines, no text, compact dropdown menu)
/// Tool Size Dropdown Button using Flutter's native PopupMenuButton
class ToolSizePopupMenuButton extends StatelessWidget {
  const ToolSizePopupMenuButton({
    super.key,
    required this.studio,
    required this.pine,
    required this.line,
    this.menuKey,
  });

  final StudioState studio;
  final Color pine;
  final Color line;
  final GlobalKey<PopupMenuButtonState<int>>? menuKey;

  static List<({double val, double lineThickness})> getPresetsForTool(
    String tool,
  ) {
    if (tool == 'highlight') {
      return const [
        (val: 14.0, lineThickness: 3.0),
        (val: 24.0, lineThickness: 7.0),
        (val: 40.0, lineThickness: 13.0),
      ];
    } else if (tool == 'erase') {
      return const [
        (val: 0.025, lineThickness: 3.0),
        (val: 0.05, lineThickness: 6.5),
        (val: 0.09, lineThickness: 12.0),
      ];
    } else {
      return const [
        (val: 2.0, lineThickness: 2.0),
        (val: 4.0, lineThickness: 4.5),
        (val: 7.5, lineThickness: 8.0),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final tool = studio.tool;
    final presets = getPresetsForTool(tool);
    final currentVal = studio.currentToolSize;

    int selectedIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < presets.length; i++) {
      final diff = (currentVal - presets[i].val).abs();
      if (diff < minDiff) {
        minDiff = diff;
        selectedIndex = i;
      }
    }

    return PopupMenuButton<int>(
      key: menuKey,
      tooltip: 'Kích thước nét & tẩy',
      offset: const Offset(0, -135),
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black38,
      surfaceTintColor: Colors.transparent,
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xffd5dcd2), width: 1.2),
      ),
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 84),
      onSelected: (index) {
        studio.setCurrentToolSize(presets[index].val);
      },
      itemBuilder: (context) => [
        for (int i = 0; i < presets.length; i++)
          PopupMenuItem<int>(
            value: i,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: i == selectedIndex
                    ? const Color(0xffe5e8e3)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 48,
                height: presets[i].lineThickness,
                decoration: BoxDecoration(
                  color: const Color(0xff1f2a24),
                  borderRadius: BorderRadius.circular(
                    presets[i].lineThickness / 2,
                  ),
                ),
              ),
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xfff5f7f2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height:
                  (tool == 'highlight'
                          ? studio.highlighterWidth / 5
                          : (tool == 'erase'
                                ? studio.eraserRadius * 80
                                : studio.strokeWidth))
                      .clamp(1.8, 7.5),
              decoration: BoxDecoration(
                color: tool == 'erase'
                    ? const Color(0xffff8c69)
                    : (tool == 'laser' ? Colors.redAccent : pine),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 14, color: pine),
          ],
        ),
      ),
    );
  }
}

/// Minimalist Tool Size Dropdown (Clean horizontal stroke lines, no text, compact dropdown menu)
class ToolSizeDropdown extends StatelessWidget {
  const ToolSizeDropdown({super.key, required this.studio, this.onSelected});

  final StudioState studio;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final tool = studio.tool;
    final presets = ToolSizePopupMenuButton.getPresetsForTool(tool);
    final currentVal = studio.currentToolSize;

    int selectedIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < presets.length; i++) {
      final diff = (currentVal - presets[i].val).abs();
      if (diff < minDiff) {
        minDiff = diff;
        selectedIndex = i;
      }
    }

    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 84,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xffd5dcd2), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 16,
              offset: Offset(0, -3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < presets.length; i++)
              InkWell(
                onTap: () {
                  studio.setCurrentToolSize(presets[i].val);
                  onSelected?.call();
                },
                child: Container(
                  height: 38,
                  color: i == selectedIndex
                      ? const Color(0xffe5e8e3)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  child: Container(
                    width: 48,
                    height: presets[i].lineThickness,
                    decoration: BoxDecoration(
                      color: const Color(0xff1f2a24),
                      borderRadius: BorderRadius.circular(
                        presets[i].lineThickness / 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
