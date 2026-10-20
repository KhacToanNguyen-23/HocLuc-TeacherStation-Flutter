part of 'studio_state.dart';

enum StudioViewportMode { fullBoard, fullPdf, split }

class PdfDgnlHighlightSpan {
  final String text;
  final String category; // 'grammar', 'collocation', 'vocabulary'
  final String level; // 'B2', 'C1', 'C2'
  final String type;
  final String note;
  final List<Rect> normalizedRects;

  const PdfDgnlHighlightSpan({
    required this.text,
    required this.category,
    this.level = 'B2',
    required this.type,
    required this.note,
    required this.normalizedRects,
  });
}

class PdfDgnlPassage {
  final String id;
  final int pageNumber;
  final String rawText;
  final Rect normalizedBounds;
  final List<PdfDgnlHighlightSpan> spans;
  final Map<String, dynamic> metrics;
  final List<Map<String, dynamic>> clozeQuestions;
  bool isVisible;

  PdfDgnlPassage({
    required this.id,
    required this.pageNumber,
    required this.rawText,
    required this.normalizedBounds,
    required this.spans,
    required this.metrics,
    required this.clozeQuestions,
    this.isVisible = true,
  });
}

class BoardStroke {
  BoardStroke(
    this.color,
    this.width,
    this.points, {
    this.isEraser = false,
    bool? isHighlighter,
    this.rect,
    this.isHollow = false,
    this.smartPenGroupId,
    this.smartPenLabel,
  }) : isHighlighter = isHighlighter ?? (width > 6 || rect != null);
  final bool isHighlighter;
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
      } else {
        return Path()
          ..addRRect(RRect.fromRectAndRadius(rect!, const Radius.circular(3)));
      }
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
          thinning: isHighlighter ? 0.0 : 0.35,
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
      _cachedSize = null;
      _cachedPath = path;
      return path;
    }

    if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final p = Offset(
        points.first.dx * size.width,
        points.first.dy * size.height,
      );
      _cachedSize = size;
      _cachedPath = Path()
        ..addOval(Rect.fromCircle(center: p, radius: width / 2));
      return _cachedPath!;
    }

    final pointVectors = points
        .map((p) => PointVector(p.dx * size.width, p.dy * size.height))
        .toList();
    final outline = getStroke(
      pointVectors,
      options: StrokeOptions(
        size: width,
        thinning: isHighlighter ? 0.0 : 0.35,
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
    _cachedSize = size;
    _cachedPath = path;
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
    isHighlighter: isHighlighter,
    rect: rect,
    isHollow: isHollow,
    smartPenGroupId: smartPenGroupId,
    smartPenLabel: smartPenLabel,
  );

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
    'isHighlighter': isHighlighter,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    if (rect != null)
      'rect': [rect!.left, rect!.top, rect!.width, rect!.height],
    if (isHollow) 'isHollow': true,
    if (smartPenGroupId != null) 'smartPenGroupId': smartPenGroupId,
    if (smartPenLabel != null) 'smartPenLabel': smartPenLabel,
  };

  static BoardStroke fromJson(Map<String, dynamic> json) {
    Rect? r;
    if (json.containsKey('rect') && json['rect'] is List) {
      final rl = json['rect'] as List;
      if (rl.length == 4) {
        r = Rect.fromLTWH(
          (rl[0] as num).toDouble(),
          (rl[1] as num).toDouble(),
          (rl[2] as num).toDouble(),
          (rl[3] as num).toDouble(),
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
      isHighlighter: json['isHighlighter'] as bool?,
      rect: r,
      isHollow: json['isHollow'] == true,
      smartPenGroupId: json['smartPenGroupId'] as String?,
      smartPenLabel: json['smartPenLabel'] as String?,
    );
  }
}

class ImportedDocument {
  ImportedDocument({
    required this.id,
    required this.name,
    this.path,
    this.bytes,
    this.contentFingerprint,
    this.totalPages = 1,
  });

  final String id;
  final String name;
  String? path;
  Uint8List? bytes;
  String? contentFingerprint;
  int totalPages;
  final Map<int, List<BoardStroke>> annotations = {};

  int get sizeBytes => bytes?.lengthInBytes ?? 0;
  String get formattedSize {
    final b = sizeBytes;
    if (b <= 0) return '';
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
