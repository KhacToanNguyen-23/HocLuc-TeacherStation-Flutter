import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

class BoardStroke {
  BoardStroke(this.color, this.width, this.points, {this.isEraser = false});

  final Color color;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  Path? _cachedPath;

  Path getPath() {
    if (_cachedPath != null) return _cachedPath!;
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      _cachedPath = Path()
        ..addOval(Rect.fromCircle(center: points.first, radius: width / 2));
      return _cachedPath!;
    }
    final pointVectors = points.map((p) => PointVector(p.dx, p.dy)).toList();
    final outline = getStroke(
      pointVectors,
      options: StrokeOptions(
        size: width,
        thinning: 0.35,
        smoothing: 0.65,
        streamline: 0.5,
        isComplete: true,
      ),
    );
    final path = Path();
    if (outline.isNotEmpty) {
      path.moveTo(outline.first.dx, outline.first.dy);
      for (int i = 1; i < outline.length; i++) {
        path.lineTo(outline[i].dx, outline[i].dy);
      }
      path.close();
    }
    _cachedPath = path;
    return path;
  }

  void invalidatePath() {
    _cachedPath = null;
  }

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };

  static BoardStroke fromJson(Map<String, dynamic> json) => BoardStroke(
    Color((json['color'] as num).toInt()),
    (json['width'] as num).toDouble(),
    (json['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList(),
    isEraser: json['isEraser'] as bool? ?? false,
  );
}
