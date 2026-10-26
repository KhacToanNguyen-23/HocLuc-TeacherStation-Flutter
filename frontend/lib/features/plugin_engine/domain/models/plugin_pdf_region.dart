import 'package:flutter/material.dart';

/// A plugin-produced interactive region on a PDF page, in canonical PDF points.
class PluginPdfRegion {
  const PluginPdfRegion({
    required this.id,
    required this.label,
    required this.groupId,
    required this.bounds,
  });

  final String id;
  final String label;
  final String groupId;
  final Rect bounds;

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'group_id': groupId,
    'bounds': {
      'x': bounds.left,
      'y': bounds.top,
      'width': bounds.width,
      'height': bounds.height,
    },
  };

  static PluginPdfRegion? tryParse(Object? value) {
    if (value is! Map) return null;
    final id = value['id']?.toString() ?? '';
    final label = value['label']?.toString() ?? '';
    final groupId = value['group_id']?.toString() ?? '';
    final rawBounds = value['bounds'];
    if (id.isEmpty || label.isEmpty || groupId.isEmpty || rawBounds is! Map) {
      return null;
    }
    final x = _finiteNumber(rawBounds['x']);
    final y = _finiteNumber(rawBounds['y']);
    final width = _finiteNumber(rawBounds['width']);
    final height = _finiteNumber(rawBounds['height']);
    if (x == null || y == null || width == null || height == null) return null;
    if (x < 0 || y < 0 || width <= 0 || height <= 0) return null;
    return PluginPdfRegion(
      id: id,
      label: label,
      groupId: groupId,
      bounds: Rect.fromLTWH(x, y, width, height),
    );
  }

  static double? _finiteNumber(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }
}
