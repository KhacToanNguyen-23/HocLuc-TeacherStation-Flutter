import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

/// Serializable inking geometry shared by chalkboard and PDF annotations.
class BoardStroke {
  BoardStroke(
    this.color,
    this.width,
    this.points, {
    this.isEraser = false,
    this.rect,
    this.isHollow = false,
    this.smartPenGroupId,
    this.smartPenLabel,
  });

  final Color color;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  final Rect? rect;
  final bool isHollow;
  final String? smartPenGroupId;
  final String? smartPenLabel;

  bool get isSmartPenOval =>
      smartPenGroupId != null && smartPenLabel != null && points.length >= 3;

  Path? _cachedPath;
  Size? _cachedSize;

  Path getPath([Size? size]) {
    if (rect != null) {
      if (size != null) {
        if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
        _cachedSize = size;
        _cachedPath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                rect!.left * size.width,
                rect!.top * size.height,
                rect!.width * size.width,
                rect!.height * size.height,
              ),
              const Radius.circular(3),
            ),
          );
        return _cachedPath!;
      }
      return Path()
        ..addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(3)));
    }

    if (size == null) {
      if (_cachedPath != null && _cachedSize == null) return _cachedPath!;
      if (points.isEmpty) return Path();
      if (points.length == 1) {
        _cachedSize = null;
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
      final path = _pathFromOutline(outline);
      _cachedSize = null;
      _cachedPath = path;
      return path;
    }

    if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final point = Offset(
        points.first.dx * size.width,
        points.first.dy * size.height,
      );
      _cachedSize = size;
      _cachedPath = Path()
        ..addOval(Rect.fromCircle(center: point, radius: width / 2));
      return _cachedPath!;
    }

    final pointVectors = points
        .map((p) => PointVector(p.dx * size.width, p.dy * size.height))
        .toList();
    final outline = getStroke(
      pointVectors,
      options: StrokeOptions(
        size: width,
        thinning: width > 6 ? 0.0 : 0.35,
        smoothing: 0.65,
        streamline: 0.5,
        isComplete: true,
      ),
    );
    final path = _pathFromOutline(outline);
    _cachedSize = size;
    _cachedPath = path;
    return path;
  }

  Path _pathFromOutline(List<Offset> outline) {
    final path = Path();
    if (outline.isNotEmpty) {
      path.moveTo(outline.first.dx, outline.first.dy);
      for (var i = 1; i < outline.length; i++) {
        path.lineTo(outline[i].dx, outline[i].dy);
      }
      path.close();
    }
    return path;
  }

  void invalidatePath() {
    _cachedPath = null;
    _cachedSize = null;
  }

  BoardStroke copy() => BoardStroke(
    color,
    width,
    List<Offset>.of(points),
    isEraser: isEraser,
    rect: rect,
    isHollow: isHollow,
    smartPenGroupId: smartPenGroupId,
    smartPenLabel: smartPenLabel,
  );

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    if (rect != null)
      'rect': [rect!.left, rect!.top, rect!.width, rect!.height],
    if (isHollow) 'isHollow': true,
    if (smartPenGroupId != null) 'smartPenGroupId': smartPenGroupId,
    if (smartPenLabel != null) 'smartPenLabel': smartPenLabel,
  };

  static BoardStroke fromJson(Map<String, dynamic> json) {
    Rect? parsedRect;
    if (json['rect'] is List) {
      final values = json['rect'] as List;
      if (values.length == 4) {
        parsedRect = Rect.fromLTWH(
          (values[0] as num).toDouble(),
          (values[1] as num).toDouble(),
          (values[2] as num).toDouble(),
          (values[3] as num).toDouble(),
        );
      }
    }
    return BoardStroke(
      Color((json['color'] as num).toInt()),
      (json['width'] as num).toDouble(),
      (json['points'] as List)
          .map(
            (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          )
          .toList(),
      isEraser: json['isEraser'] as bool? ?? false,
      rect: parsedRect,
      isHollow: json['isHollow'] == true,
      smartPenGroupId: json['smartPenGroupId'] as String?,
      smartPenLabel: json['smartPenLabel'] as String?,
    );
  }
}
