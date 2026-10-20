import 'dart:ui';

import 'package:perfect_freehand/perfect_freehand.dart';

/// Shared by live ink and persisted strokes, in canvas pixel coordinates.
Path buildInkPath(List<Offset> points, double width, {bool highlight = false}) {
  if (points.isEmpty) return Path();
  if (points.length == 1) {
    return Path()
      ..addOval(Rect.fromCircle(center: points.first, radius: width / 2));
  }
  final outline = getStroke(
    points.map((p) => PointVector(p.dx, p.dy)).toList(),
    options: StrokeOptions(
      size: width,
      thinning: highlight ? 0.0 : 0.35,
      smoothing: 0.75,
      streamline: 0.65,
      // Keep the tip at the latest input in both live and committed ink.
      isComplete: true,
    ),
  );
  if (outline.isEmpty) return Path();

  // Each outline point controls a quadratic between adjacent midpoints.
  // Include the wraparound segment so the closed seam is smooth too.
  final first = outline.first;
  final last = outline.last;
  final path = Path()
    ..moveTo((last.dx + first.dx) / 2, (last.dy + first.dy) / 2);
  for (var i = 0; i < outline.length; i++) {
    final current = outline[i];
    final next = outline[(i + 1) % outline.length];
    path.quadraticBezierTo(
      current.dx,
      current.dy,
      (current.dx + next.dx) / 2,
      (current.dy + next.dy) / 2,
    );
  }
  return path..close();
}
