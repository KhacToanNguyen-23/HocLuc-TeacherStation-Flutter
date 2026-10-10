import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';

/// 24-Hue, 6-Ring Color Wheel Widget & Dialog matching the educational color wheel
class ColorWheelDialog extends StatefulWidget {
  const ColorWheelDialog({super.key, required this.studio});

  final StudioState studio;

  @override
  State<ColorWheelDialog> createState() => _ColorWheelDialogState();
}

class _ColorWheelDialogState extends State<ColorWheelDialog> {
  late Color _selectedColor;

  static const List<double> _wheelHues = [
    60, 50, 40, 30, 20, 10, 0, 345, 330, 310, 290, 270,
    250, 230, 210, 195, 180, 165, 150, 135, 120, 105, 90, 75,
  ];

  static const List<(double lightness, double saturation)> _wheelRings = [
    (0.20, 0.95), // Ring 0: Innermost dark shade
    (0.32, 0.90), // Ring 1: Dark
    (0.44, 0.90), // Ring 2: Medium dark
    (0.56, 0.95), // Ring 3: Vibrant core
    (0.70, 0.85), // Ring 4: Medium light
    (0.84, 0.70), // Ring 5: Outermost pastel tint
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.studio.ink;
  }

  void _onColorTapped(Color color) {
    setState(() => _selectedColor = color);
  }

  void _applyColor() {
    widget.studio.setCustomColor(_selectedColor);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hexCode = '#${_selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xff182721),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x44ffffff), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.palette_outlined, size: 20, color: Color(0xffd4e8a6)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Bảng phối màu tùy thích',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18, color: Colors.white54),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Interactive 24-Sector Color Wheel
              SizedBox(
                width: 250,
                height: 250,
                child: ColorWheelInteractive(
                  selectedColor: _selectedColor,
                  hues: _wheelHues,
                  rings: _wheelRings,
                  onColorSelected: _onColorTapped,
                ),
              ),

              const SizedBox(height: 16),

              // Current color preview & Hex code
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xff121d19),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x22ffffff)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Màu đang chọn',
                            style: TextStyle(fontSize: 10.5, color: Colors.white54),
                          ),
                          Text(
                            hexCode,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xffd4e8a6),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _applyColor,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xffd4e8a6),
                        foregroundColor: const Color(0xff14221d),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Chọn màu này', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Quick Preset Teaching Palette
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Màu phấn & dạ quang phổ biến:',
                    style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in [
                        const Color(0xffffffff),
                        const Color(0xfff0f3ed),
                        const Color(0xffffe66d),
                        const Color(0xffffd166),
                        const Color(0xffff8c69),
                        const Color(0xffff6b6b),
                        const Color(0xffff85a2),
                        const Color(0xffb388ff),
                        const Color(0xff70e0d0),
                        const Color(0xff48cae4),
                        const Color(0xff06d6a0),
                        const Color(0xff9ef01a),
                      ])
                        InkWell(
                          onTap: () => _onColorTapped(c),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _selectedColor == c ? const Color(0xffd4e8a6) : Colors.white24,
                                width: _selectedColor == c ? 2.5 : 1.2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
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
    final ringIndex = ((r - minR) / ringWidth).floor().clamp(0, rings.length - 1);

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
        final color = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();

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

    // Center circular hub
    final centerPaint = Paint()..color = const Color(0xff182721);
    canvas.drawCircle(center, minR, centerPaint);
    canvas.drawCircle(center, minR, linePaint);
  }

  @override
  bool shouldRepaint(covariant ColorWheelPainter oldDelegate) {
    return oldDelegate.selectedColor != selectedColor;
  }
}

/// Minimalist Tool Size Popup Dialog (Clean horizontal stroke lines, no text, compact)
class ToolSizeDialog extends StatelessWidget {
  const ToolSizeDialog({super.key, required this.studio});

  final StudioState studio;

  @override
  Widget build(BuildContext context) {
    final tool = studio.tool;
    final isHighlighter = tool == 'highlight';
    final isEraser = tool == 'erase';

    // 3 clean thickness levels matching the user's reference image
    final List<({double val, double lineThickness})> presets = isHighlighter
        ? [
            (val: 14.0, lineThickness: 3.0),
            (val: 24.0, lineThickness: 7.0),
            (val: 40.0, lineThickness: 13.0),
          ]
        : (isEraser
            ? [
                (val: 0.025, lineThickness: 3.0),
                (val: 0.05, lineThickness: 6.5),
                (val: 0.09, lineThickness: 12.0),
              ]
            : [
                (val: 2.0, lineThickness: 1.8),
                (val: 4.0, lineThickness: 4.0),
                (val: 7.5, lineThickness: 7.5),
              ]);

    final currentVal = studio.currentToolSize;

    // Find the closest preset index
    int selectedIndex = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < presets.length; i++) {
      final diff = (currentVal - presets[i].val).abs();
      if (diff < minDiff) {
        minDiff = diff;
        selectedIndex = i;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Center(
        child: Container(
          width: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xffd5dcd2), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 16,
                offset: Offset(0, 4),
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
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    height: 38,
                    color: i == selectedIndex
                        ? const Color(0xffe5e8e3)
                        : Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Container(
                      height: presets[i].lineThickness,
                      decoration: BoxDecoration(
                        color: Colors.black87,
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
      ),
    );
  }
}
