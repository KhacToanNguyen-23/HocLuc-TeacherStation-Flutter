import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';

import 'ink_path.dart';

export 'dgnl_highlight_palette.dart';
export 'offline_lexeme.dart';
export 'pedagogical_highlight_policy.dart';

enum StudioViewportMode { fullBoard, fullPdf, split }

class PdfDgnlHighlightSpan {
  final String text;
  final String category; // 'grammar', 'collocation', 'vocabulary'
  final String type;
  final String note;
  final List<Rect> normalizedRects;
  final bool isPedagogical;
  final bool isAcademic;
  final bool isPreTeach;
  final bool isFunctionWord;
  final bool isProperNoun;
  final bool isNumber;
  final String? lemma;

  const PdfDgnlHighlightSpan({
    required this.text,
    required this.category,
    required this.type,
    required this.note,
    required this.normalizedRects,
    this.isPedagogical = false,
    this.isAcademic = false,
    this.isPreTeach = false,
    this.isFunctionWord = false,
    this.isProperNoun = false,
    this.isNumber = false,
    this.lemma,
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
    this.id,
    this.isEraser = false,
    bool? isHighlighter,
    this.rect,
    this.isHollow = false,
    this.isDashed = false,
    this.text,
    this.smartPenGroupId,
    this.smartPenLabel,
    this.annotationOwnerId,
    this.annotationGroupId,
    this.annotationItemId,
    this.category,
    this.level,
    this.opacity,
  }) : isHighlighter = isHighlighter ?? (width > 6 || rect != null);
  final String? id;
  final bool isHighlighter;
  final Color color;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  final Rect? rect;
  final bool isHollow;
  final bool isDashed;
  final String? text;
  final String? smartPenGroupId;
  final String? smartPenLabel;
  final String? annotationOwnerId;
  final String? annotationGroupId;
  final String? annotationItemId;
  final String? category;
  final String? level;
  final double? opacity;
  String? get groupedAnnotationGroupId => annotationGroupId ?? smartPenGroupId;
  String? get groupedAnnotationItemId => annotationItemId ?? smartPenLabel;
  bool get isGroupedPdfAnnotation =>
      groupedAnnotationGroupId != null &&
      groupedAnnotationItemId != null &&
      points.length >= 3;
  bool get isSmartPenOval =>
      smartPenGroupId != null && smartPenLabel != null && points.length >= 3;
  Path? _cachedPath;
  Size? _cachedSize;

  bool hitTest(Offset point, double radius) {
    if (rect != null) {
      final inflated = rect!.inflate(radius);
      return inflated.contains(point);
    }
    return points.any((p) => (p - point).distance < radius);
  }

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

    if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
    final pixelPoints = size == null
        ? points
        : points
              .map((p) => Offset(p.dx * size.width, p.dy * size.height))
              .toList();
    _cachedPath = buildInkPath(pixelPoints, width, highlight: isHighlighter);
    _cachedSize = size;
    return _cachedPath!;
  }

  void invalidatePath() {
    _cachedPath = null;
    _cachedSize = null;
  }

  BoardStroke copy() => BoardStroke(
    color,
    width,
    List<Offset>.of(points),
    id: id,
    isEraser: isEraser,
    isHighlighter: isHighlighter,
    rect: rect,
    isHollow: isHollow,
    isDashed: isDashed,
    text: text,
    smartPenGroupId: smartPenGroupId,
    smartPenLabel: smartPenLabel,
    annotationOwnerId: annotationOwnerId,
    annotationGroupId: annotationGroupId,
    annotationItemId: annotationItemId,
    category: category,
    level: level,
    opacity: opacity,
  );

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
    'isHighlighter': isHighlighter,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
    if (id != null) 'id': id,
    if (rect != null)
      'rect': [rect!.left, rect!.top, rect!.width, rect!.height],
    if (isHollow) 'isHollow': true,
    if (isDashed) 'isDashed': true,
    if (text != null) 'text': text,
    if (smartPenGroupId != null) 'smartPenGroupId': smartPenGroupId,
    if (smartPenLabel != null) 'smartPenLabel': smartPenLabel,
    if (annotationOwnerId != null) 'annotationOwnerId': annotationOwnerId,
    if (annotationGroupId != null) 'annotationGroupId': annotationGroupId,
    if (annotationItemId != null) 'annotationItemId': annotationItemId,
    if (category != null) 'category': category,
    if (level != null) 'level': level,
    if (opacity != null) 'opacity': opacity,
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
      id: json['id'] as String?,
      isEraser: json['isEraser'] as bool? ?? false,
      isHighlighter: json['isHighlighter'] as bool?,
      rect: r,
      isHollow: json['isHollow'] == true,
      isDashed: json['isDashed'] == true,
      text: json['text'] as String?,
      smartPenGroupId: json['smartPenGroupId'] as String?,
      smartPenLabel: json['smartPenLabel'] as String?,
      annotationOwnerId: json['annotationOwnerId'] as String?,
      annotationGroupId: json['annotationGroupId'] as String?,
      annotationItemId: json['annotationItemId'] as String?,
      category: json['category'] as String?,
      level: json['level'] as String?,
      opacity: (json['opacity'] as num?)?.toDouble(),
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
