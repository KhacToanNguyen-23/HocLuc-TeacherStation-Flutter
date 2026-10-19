part of 'studio_state.dart';

/// Stable, page-normalized geometry for one automatically selected answer.
class SmartPenOvalAnnotation {
  const SmartPenOvalAnnotation({
    required this.pageNumber,
    required this.label,
    required this.groupId,
    required this.normalizedLabelBounds,
    required this.points,
    required this.color,
    required this.width,
  });

  final int pageNumber;
  final String label;
  final String groupId;
  final Rect normalizedLabelBounds;
  final List<Offset> points;
  final Color color;
  final double width;

  factory SmartPenOvalAnnotation.fromSelection({
    required SmartPenAnswerSelection selection,
    required Size pageSize,
    required Color color,
    required double width,
    int? seed,
  }) {
    if (pageSize.width <= 0 || pageSize.height <= 0) {
      throw ArgumentError.value(pageSize, 'pageSize', 'must be positive');
    }
    final bounds = Rect.fromLTRB(
      selection.bounds.left / pageSize.width,
      selection.bounds.top / pageSize.height,
      selection.bounds.right / pageSize.width,
      selection.bounds.bottom / pageSize.height,
    );
    final random = math.Random(seed ?? _stableSeed(selection));
    final cx = bounds.center.dx;
    final cy = bounds.center.dy;
    final rx = bounds.width * 0.5 + 5 / pageSize.width;
    final ry = bounds.height * 0.5 + 4 / pageSize.height;
    const count = 40;
    final points = <Offset>[];
    for (var i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count;
      final wobble = 1 + (random.nextDouble() - 0.5) * 0.055;
      points.add(
        Offset(
          (cx + math.cos(angle) * rx * wobble).clamp(0.0, 1.0),
          (cy + math.sin(angle) * ry * wobble).clamp(0.0, 1.0),
        ),
      );
    }
    return SmartPenOvalAnnotation(
      pageNumber: selection.pageNumber,
      label: selection.label,
      groupId: selection.groupId,
      normalizedLabelBounds: bounds,
      points: List.unmodifiable(points),
      color: color,
      width: width,
    );
  }

  static int _stableSeed(SmartPenAnswerSelection selection) {
    final value = '${selection.groupId}:${selection.label}:${selection.bounds}';
    var hash = selection.pageNumber;
    for (final code in value.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return hash;
  }

  BoardStroke toBoardStroke() => BoardStroke(
    color,
    width,
    points,
    isHollow: true,
    smartPenGroupId: groupId,
    smartPenLabel: label,
  );

  Map<String, dynamic> toJson() => {
    'pageNumber': pageNumber,
    'label': label,
    'groupId': groupId,
    'bounds': [
      normalizedLabelBounds.left,
      normalizedLabelBounds.top,
      normalizedLabelBounds.width,
      normalizedLabelBounds.height,
    ],
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    'color': color.toARGB32(),
    'width': width,
  };

  factory SmartPenOvalAnnotation.fromJson(Map<String, dynamic> json) {
    final b = json['bounds'] as List;
    return SmartPenOvalAnnotation(
      pageNumber: (json['pageNumber'] as num).toInt(),
      label: json['label'] as String,
      groupId: json['groupId'] as String,
      normalizedLabelBounds: Rect.fromLTWH(
        (b[0] as num).toDouble(),
        (b[1] as num).toDouble(),
        (b[2] as num).toDouble(),
        (b[3] as num).toDouble(),
      ),
      points: List.unmodifiable(
        (json['points'] as List).map(
          (p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ),
      ),
      color: Color((json['color'] as num).toInt()),
      width: (json['width'] as num).toDouble(),
    );
  }
}
