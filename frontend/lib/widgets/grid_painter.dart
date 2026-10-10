import 'package:flutter/material.dart';

const Color chalkboardBg = Color(0xff14221d);
const Color chalkboardGrid = Color(0x1fffffff);
const Color chalkboardSubGrid = Color(0x0fffffff);

class GridPainter extends CustomPainter {
  const GridPainter({
    this.backgroundColor = chalkboardBg,
    this.gridColor = chalkboardGrid,
    this.cellSize = 15.0,
    this.showGrid = true,
  });

  final Color backgroundColor;
  final Color gridColor;
  final double cellSize;
  final bool showGrid;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (!showGrid) return;

    final linePaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final subLinePaint = Paint()
      ..color = chalkboardSubGrid
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Draw vertical grid lines (major line every 5 cells = 75px standard)
    int colIndex = 0;
    for (double x = cellSize; x < size.width; x += cellSize) {
      colIndex++;
      final isMajor = colIndex % 5 == 0;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        isMajor ? linePaint : subLinePaint,
      );
    }

    // Draw horizontal grid lines (major line every 5 cells = 75px standard)
    int rowIndex = 0;
    for (double y = cellSize; y < size.height; y += cellSize) {
      rowIndex++;
      final isMajor = rowIndex % 5 == 0;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        isMajor ? linePaint : subLinePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.showGrid != showGrid;
}
