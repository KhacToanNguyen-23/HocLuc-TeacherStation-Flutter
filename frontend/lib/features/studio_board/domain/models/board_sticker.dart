import 'dart:ui';

class BoardSticker {
  BoardSticker({
    required this.id,
    required this.type,
    required this.normalizedRect,
    required this.rawText,
    this.title,
    this.svgContent,
    this.imageBase64,
    this.tokens = const [],
    this.rotation = 0.0,
    this.metadata,
  });

  final String id;
  final String type;
  Rect normalizedRect;
  final String rawText;
  final String? title;
  final String? svgContent;
  final String? imageBase64;
  final List<Map<String, dynamic>> tokens;
  final double rotation;
  final Map<String, dynamic>? metadata;

  String get text => rawText;

  BoardSticker copyWith({
    String? id,
    String? type,
    Rect? normalizedRect,
    String? rawText,
    String? title,
    String? svgContent,
    String? imageBase64,
    List<Map<String, dynamic>>? tokens,
    double? rotation,
    Map<String, dynamic>? metadata,
  }) {
    return BoardSticker(
      id: id ?? this.id,
      type: type ?? this.type,
      normalizedRect: normalizedRect ?? this.normalizedRect,
      rawText: rawText ?? this.rawText,
      title: title ?? this.title,
      svgContent: svgContent ?? this.svgContent,
      imageBase64: imageBase64 ?? this.imageBase64,
      tokens: tokens ?? this.tokens,
      rotation: rotation ?? this.rotation,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'rect': [
      double.parse(normalizedRect.left.toStringAsFixed(4)),
      double.parse(normalizedRect.top.toStringAsFixed(4)),
      double.parse(normalizedRect.width.toStringAsFixed(4)),
      double.parse(normalizedRect.height.toStringAsFixed(4)),
    ],
    'rawText': rawText,
    if (title != null) 'title': title,
    if (svgContent != null) 'svgContent': svgContent,
    if (imageBase64 != null) 'imageBase64': imageBase64,
    'tokens': _withoutLegacyParserMetadata(tokens),
    'rotation': rotation,
    if (metadata != null) 'metadata': metadata,
  };

  static BoardSticker fromJson(Map<String, dynamic> json) {
    final rectList = (json['rect'] as List).cast<num>();
    return BoardSticker(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'generic_card',
      normalizedRect: Rect.fromLTWH(
        rectList[0].toDouble(),
        rectList[1].toDouble(),
        rectList[2].toDouble(),
        rectList[3].toDouble(),
      ),
      rawText: json['rawText'] as String? ?? '',
      title: json['title'] as String?,
      svgContent: json['svgContent'] as String?,
      imageBase64: json['imageBase64'] as String?,
      tokens: _withoutLegacyParserMetadata(
        (json['tokens'] as List?)
                ?.map((t) => Map<String, dynamic>.from(t as Map))
                .toList() ??
            const [],
      ),
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }
}

List<Map<String, dynamic>> _withoutLegacyParserMetadata(
  List<Map<String, dynamic>> tokens,
) => tokens.map((token) {
  final sanitized = Map<String, dynamic>.from(token)
    ..remove('role')
    ..remove('pos')
    ..remove('dep');
  return sanitized;
}).toList(growable: false);
