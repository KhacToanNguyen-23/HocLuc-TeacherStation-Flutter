import 'package:flutter/material.dart';

class ChalkWordToken {
  static const neutralColor = Color(0x88d4e8a6);

  const ChalkWordToken({
    required this.word,
    Color? color,
    required this.relativeRect,
  }) : color = color ?? neutralColor;

  final String word;
  final Color color;
  final Rect relativeRect;

  Map<String, dynamic> toJson() => {
    'word': word,
    'color': color.toARGB32(),
    'relativeRect': [
      relativeRect.left,
      relativeRect.top,
      relativeRect.width,
      relativeRect.height,
    ],
  };

  factory ChalkWordToken.fromJson(Map<String, dynamic> json) {
    final rectList = (json['relativeRect'] as List).cast<num>();
    return ChalkWordToken(
      word: json['word'] as String? ?? '',
      // Ignore legacy serialized role colors; old annotations become neutral.
      color: neutralColor,
      relativeRect: Rect.fromLTWH(
        rectList[0].toDouble(),
        rectList[1].toDouble(),
        rectList[2].toDouble(),
        rectList[3].toDouble(),
      ),
    );
  }
}

class SmartChalkAnnotation {
  SmartChalkAnnotation({
    required this.id,
    this.source = 'chalkboard',
    this.pageIndex = 0,
    required this.rawText,
    required this.normalizedBounds,
    required this.tokens,
    this.isVisible = true,
    this.normalizedOffset = Offset.zero,
  });

  final String id;
  final String source;
  final int pageIndex;
  final String rawText;
  final Rect normalizedBounds;
  final List<ChalkWordToken> tokens;
  bool isVisible;
  Offset normalizedOffset;

  SmartChalkAnnotation copyWith({
    String? id,
    String? source,
    int? pageIndex,
    String? rawText,
    Rect? normalizedBounds,
    List<ChalkWordToken>? tokens,
    bool? isVisible,
    Offset? normalizedOffset,
  }) {
    return SmartChalkAnnotation(
      id: id ?? this.id,
      source: source ?? this.source,
      pageIndex: pageIndex ?? this.pageIndex,
      rawText: rawText ?? this.rawText,
      normalizedBounds: normalizedBounds ?? this.normalizedBounds,
      tokens: tokens ?? this.tokens,
      isVisible: isVisible ?? this.isVisible,
      normalizedOffset: normalizedOffset ?? this.normalizedOffset,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source,
    'pageIndex': pageIndex,
    'rawText': rawText,
    'normalizedBounds': [
      normalizedBounds.left,
      normalizedBounds.top,
      normalizedBounds.width,
      normalizedBounds.height,
    ],
    'tokens': tokens.map((t) => t.toJson()).toList(),
    'isVisible': isVisible,
    'offset': [normalizedOffset.dx, normalizedOffset.dy],
  };

  factory SmartChalkAnnotation.fromJson(Map<String, dynamic> json) {
    final boundsList = (json['normalizedBounds'] as List).cast<num>();
    final offsetList = (json['offset'] as List?)?.cast<num>() ?? [0, 0];
    final tokensRaw = (json['tokens'] as List?) ?? [];

    return SmartChalkAnnotation(
      id: json['id'] as String,
      source: json['source'] as String? ?? 'chalkboard',
      pageIndex: (json['pageIndex'] as num?)?.toInt() ?? 0,
      rawText: json['rawText'] as String? ?? '',
      normalizedBounds: Rect.fromLTWH(
        boundsList[0].toDouble(),
        boundsList[1].toDouble(),
        boundsList[2].toDouble(),
        boundsList[3].toDouble(),
      ),
      tokens: tokensRaw
          .map(
            (t) => ChalkWordToken.fromJson(Map<String, dynamic>.from(t as Map)),
          )
          .toList(),
      isVisible: json['isVisible'] as bool? ?? true,
      normalizedOffset: Offset(
        offsetList[0].toDouble(),
        offsetList[1].toDouble(),
      ),
    );
  }
}
