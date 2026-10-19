import 'dart:ui';

class BoardSticker {
  BoardSticker({
    required this.id,
    required this.type,
    required this.normalizedRect,
    required this.rawText,
    this.tokens = const [],
    this.issues = const [],
  });

  final String id;
  final String type;
  Rect normalizedRect;
  final String rawText;
  final List<Map<String, dynamic>> tokens;
  final List<String> issues;

  String get text => rawText;
  String? get grammarIssue => issues.isNotEmpty ? issues.first : null;

  BoardSticker copyWith({
    String? id,
    String? type,
    Rect? normalizedRect,
    String? rawText,
    List<Map<String, dynamic>>? tokens,
    List<String>? issues,
  }) {
    return BoardSticker(
      id: id ?? this.id,
      type: type ?? this.type,
      normalizedRect: normalizedRect ?? this.normalizedRect,
      rawText: rawText ?? this.rawText,
      tokens: tokens ?? this.tokens,
      issues: issues ?? this.issues,
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
    'tokens': tokens,
    'issues': issues,
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
      tokens:
          (json['tokens'] as List?)
              ?.map((t) => Map<String, dynamic>.from(t as Map))
              .toList() ??
          const [],
      issues:
          (json['issues'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}
