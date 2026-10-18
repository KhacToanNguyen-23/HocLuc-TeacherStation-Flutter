// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

extension StudioStateAnnotationsExt on StudioState {
  String get currentPageNote =>
      (page >= 0 && page < pageNotes.length) ? pageNotes[page] : '';

  void setPageNote(int index, String note) {
    while (pageNotes.length <= index) {
      pageNotes.add('');
    }
    if (pageNotes[index] != note) {
      pageNotes[index] = note;
      dirty = true;
      _revision++;
      notifyListeners();
    }
  }

  List<BoardSticker> get currentStickers =>
      pageStickers.putIfAbsent(page, () => []);

  void addSticker(BoardSticker sticker) {
    currentStickers.add(sticker);
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void removeSticker(String id) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list.removeAt(idx);
      dirty = true;
      _revision++;
      notifyListeners();
    }
  }

  void updateStickerRect(String id, Rect newRect) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list[idx].normalizedRect = newRect;
      dirty = true;
      _revision++;
      notifyListeners();
    }
  }

  List<SmartChalkAnnotation> get currentChalkAnnotations =>
      pageChalkAnnotations.putIfAbsent(page, () => []);

  List<SmartChalkAnnotation> getPdfChalkAnnotations(int pageNumber) =>
      pdfChalkAnnotations.putIfAbsent(pageNumber, () => []);

  void addChalkAnnotation(SmartChalkAnnotation annotation) {
    currentChalkAnnotations.add(annotation);
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void addPdfChalkAnnotation(int pageNumber, SmartChalkAnnotation annotation) {
    getPdfChalkAnnotations(pageNumber).add(annotation);
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void removeChalkAnnotation(String id) {
    for (final list in pageChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list.removeAt(idx);
        dirty = true;
        _revision++;
        notifyListeners();
        return;
      }
    }
    for (final list in pdfChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list.removeAt(idx);
        dirty = true;
        _revision++;
        notifyListeners();
        return;
      }
    }
  }

  void removePdfChalkAnnotation(int pageNumber, String id) {
    final list = getPdfChalkAnnotations(pageNumber);
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list.removeAt(idx);
      dirty = true;
      _revision++;
      notifyListeners();
    }
  }

  void updateChalkAnnotationOffset(String id, Offset newOffset) {
    for (final list in pageChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list[idx].normalizedOffset = newOffset;
        dirty = true;
        _revision++;
        notifyListeners();
        return;
      }
    }
    for (final list in pdfChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list[idx].normalizedOffset = newOffset;
        dirty = true;
        _revision++;
        notifyListeners();
        return;
      }
    }
  }

  void clearChalkAnnotations([int? targetPage]) {
    final p = targetPage ?? page;
    pageChalkAnnotations[p]?.clear();
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void clearPdfChalkAnnotations(int pageNumber) {
    pdfChalkAnnotations[pageNumber]?.clear();
    dirty = true;
    _revision++;
    notifyListeners();
  }

  bool analyzeHandwritingAt(Offset touchPoint, {String? hintText}) {
    final annotation = StrokeClusterer.clusterAndAnalyze(
      touchPoint: touchPoint,
      strokes: strokes,
      pageIndex: page,
      hintText: hintText,
    );
    if (annotation == null) {
      return false;
    }

    currentChalkAnnotations.removeWhere((a) {
      final center = a.normalizedBounds.center;
      return (center.dy - touchPoint.dy).abs() < 0.12 &&
          (center.dx - touchPoint.dx).abs() < 0.35;
    });

    addChalkAnnotation(annotation);
    _refineAnnotationWithOcr(annotation, touchPoint);
    return true;
  }

  bool hasStrokesNear(Offset touchPoint) {
    return strokes.any((s) {
      if (s.isEraser || s.points.isEmpty) return false;
      return s.points.any(
        (p) =>
            (p.dy - touchPoint.dy).abs() < 0.12 &&
            (p.dx - touchPoint.dx).abs() < 0.35,
      );
    });
  }

  Future<bool> analyzeHandwritingWithVerifiedText(
    Offset touchPoint,
    String verifiedText,
  ) async {
    final cleanText = verifiedText.trim();
    if (cleanText.isEmpty) return false;

    final tokensData = await EnglishSentenceAnalyzer.analyzeTokensWithBackend(
      cleanText,
    );
    if (tokensData.isEmpty) return false;

    final annotation = StrokeClusterer.clusterAndAnalyze(
      touchPoint: touchPoint,
      strokes: strokes,
      pageIndex: page,
      hintText: cleanText,
    );
    if (annotation == null) return false;

    final totalTokens = tokensData.length;
    final updatedChalkTokens = <ChalkWordToken>[];

    for (int i = 0; i < totalTokens; i++) {
      final t = tokensData[i];
      final word = t['text'] as String;
      final role = t['role'] as String?;

      Rect relRect;
      if (i < annotation.tokens.length) {
        relRect = annotation.tokens[i].relativeRect;
      } else {
        final step = 1.0 / totalTokens;
        relRect = Rect.fromLTWH(i * step, 0.0, step * 0.9, 1.0);
      }

      updatedChalkTokens.add(
        ChalkWordToken(word: word, role: role, relativeRect: relRect),
      );
    }

    final finalAnnotation = annotation.copyWith(
      rawText: cleanText,
      tokens: updatedChalkTokens,
    );

    currentChalkAnnotations.removeWhere((a) {
      final center = a.normalizedBounds.center;
      return (center.dy - touchPoint.dy).abs() < 0.12 &&
          (center.dx - touchPoint.dx).abs() < 0.35;
    });

    addChalkAnnotation(finalAnnotation);
    return true;
  }

  void _refineAnnotationWithOcr(
    SmartChalkAnnotation annotation,
    Offset touchPoint,
  ) async {
    try {
      final lineStrokes = strokes.where((s) {
        if (s.isEraser || s.points.isEmpty) return false;
        return s.points.any(
          (p) =>
              annotation.normalizedBounds.inflate(0.04).contains(p) ||
              ((p.dy - touchPoint.dy).abs() < 0.12 &&
                  p.dx >= (annotation.normalizedBounds.left - 0.03) &&
                  p.dx <= (annotation.normalizedBounds.right + 0.03)),
        );
      }).toList();

      if (lineStrokes.isEmpty) return;

      final pngBytes = await StrokeClusterer.rasterizeStrokesToPng(
        strokes: lineStrokes,
        bounds: annotation.normalizedBounds,
      );
      if (pngBytes == null) return;

      final ocrResult = await EnglishSentenceAnalyzer.analyzeWithOcr(pngBytes);
      if (ocrResult == null) return;

      final text = ocrResult['text'] as String?;
      final rawList = ocrResult['tokens'] as List?;
      final rawTokens = rawList
          ?.map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (text == null ||
          text.isEmpty ||
          rawTokens == null ||
          rawTokens.isEmpty) {
        return;
      }

      final totalTokens = rawTokens.length;
      final hasValidGrammarRoles = rawTokens.any(
        (t) => t['role'] != null && (t['role'] as String).isNotEmpty,
      );
      if (!hasValidGrammarRoles) {
        return;
      }

      final chalkTokens = <ChalkWordToken>[];
      if (totalTokens == annotation.tokens.length) {
        for (int i = 0; i < totalTokens; i++) {
          final t = rawTokens[i];
          chalkTokens.add(
            ChalkWordToken(
              word: t['text'] as String,
              role: t['role'] as String?,
              relativeRect: annotation.tokens[i].relativeRect,
            ),
          );
        }
      } else if (totalTokens < annotation.tokens.length) {
        for (int i = 0; i < annotation.tokens.length; i++) {
          if (i < totalTokens) {
            final t = rawTokens[i];
            chalkTokens.add(
              ChalkWordToken(
                word: t['text'] as String,
                role: t['role'] as String?,
                relativeRect: annotation.tokens[i].relativeRect,
              ),
            );
          } else {
            chalkTokens.add(annotation.tokens[i]);
          }
        }
      } else {
        for (int i = 0; i < totalTokens; i++) {
          final t = rawTokens[i];
          final word = t['text'] as String;
          final role = t['role'] as String?;
          if (i < annotation.tokens.length) {
            chalkTokens.add(
              ChalkWordToken(
                word: word,
                role: role,
                relativeRect: annotation.tokens[i].relativeRect,
              ),
            );
          } else {
            final lastCluster = annotation.tokens.isNotEmpty
                ? annotation.tokens.last.relativeRect
                : const Rect.fromLTWH(0.8, 0.0, 0.15, 1.0);
            final extraIdx = i - annotation.tokens.length + 1;
            final extraW = (lastCluster.width * 0.8).clamp(0.08, 0.25);
            final extraLeft =
                (lastCluster.right + (extraIdx - 1) * extraW + 0.02).clamp(
                  0.0,
                  1.0 - extraW,
                );
            chalkTokens.add(
              ChalkWordToken(
                word: word,
                role: role,
                relativeRect: Rect.fromLTWH(extraLeft, 0.0, extraW, 1.0),
              ),
            );
          }
        }
      }

      final updated = annotation.copyWith(rawText: text, tokens: chalkTokens);

      final idx = currentChalkAnnotations.indexWhere(
        (a) => a.id == annotation.id,
      );
      if (idx != -1) {
        currentChalkAnnotations[idx] = updated;
        dirty = true;
        _revision++;
        notifyListeners();
      }
    } catch (_) {}
  }

  bool analyzePdfSentenceAt(
    int pageNumber,
    Offset normPoint, {
    String? sampleText,
    Rect? targetRect,
  }) {
    getPdfChalkAnnotations(pageNumber).removeWhere((a) {
      final center = a.normalizedBounds.center;
      return (center.dy - normPoint.dy).abs() < 0.04 &&
          (center.dx - normPoint.dx).abs() < 0.35;
    });

    final rawSentence = (sampleText != null && sampleText.trim().isNotEmpty)
        ? sampleText.trim()
        : 'The teacher explains grammar.';

    final stickerData = EnglishSentenceAnalyzer.analyze(text: rawSentence);
    final rawTokens = stickerData.tokens;

    final sentenceRect =
        targetRect ??
        Rect.fromLTWH(
          (normPoint.dx - 0.04).clamp(0.04, 0.58),
          (normPoint.dy - 0.012).clamp(0.005, 0.96),
          0.38,
          0.020,
        );

    final chalkTokens = <ChalkWordToken>[];
    final tokenCount = rawTokens.length;

    if (tokenCount <= 1) {
      final tokenInfo = rawTokens.isNotEmpty
          ? rawTokens.first
          : {'text': rawSentence, 'role': 'subject'};
      chalkTokens.add(
        ChalkWordToken(
          word: tokenInfo['text'] as String,
          role: tokenInfo['role'] as String? ?? 'subject',
          relativeRect: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
        ),
      );
    } else {
      final totalLen = math.max(1, rawSentence.length);
      double currentX = 0.0;
      for (int i = 0; i < tokenCount; i++) {
        final tokenInfo = rawTokens[i];
        final word = tokenInfo['text'] as String;
        final role = tokenInfo['role'] as String?;

        final relW = (word.length / totalLen).clamp(0.05, 0.95);
        final relRect = Rect.fromLTWH(currentX, 0.0, relW, 1.0);
        currentX += relW + (1.0 / totalLen);

        chalkTokens.add(
          ChalkWordToken(word: word, role: role, relativeRect: relRect),
        );
      }
    }

    final annotation = SmartChalkAnnotation(
      id: 'pdf-svo-${DateTime.now().millisecondsSinceEpoch}',
      source: 'pdf',
      pageIndex: pageNumber,
      rawText: rawSentence,
      normalizedBounds: sentenceRect,
      tokens: chalkTokens,
      isVisible: true,
      normalizedOffset: Offset.zero,
    );

    addPdfChalkAnnotation(pageNumber, annotation);
    return true;
  }

  void addTypedChalkAnnotation(String sentence, {Offset? position}) async {
    final cleanText = sentence.trim();
    if (cleanText.isEmpty) return;

    List<ChalkWordToken> buildTokens(List<Map<String, dynamic>> tokens) {
      final list = <ChalkWordToken>[];
      final count = tokens.length;
      final totalLen = math.max(1, cleanText.length);
      double currentX = 0.0;
      for (int i = 0; i < count; i++) {
        final t = tokens[i];
        final word = t['text'] as String;
        final role = t['role'] as String?;
        final relW = (word.length / totalLen).clamp(0.05, 0.95);
        final relRect = Rect.fromLTWH(currentX, 0.0, relW, 1.0);
        currentX += relW + (1.0 / totalLen);
        list.add(ChalkWordToken(word: word, role: role, relativeRect: relRect));
      }
      return list;
    }

    final localData = EnglishSentenceAnalyzer.analyze(text: cleanText);
    final pos = position ?? const Offset(0.20, 0.30);
    final boxWidth = (cleanText.length * 0.015 + 0.12).clamp(0.12, 0.85);
    final boxHeight = 0.06;
    final sentenceRect = Rect.fromLTWH(pos.dx, pos.dy, boxWidth, boxHeight);

    final annotation = SmartChalkAnnotation(
      id: 'typed-svo-${DateTime.now().millisecondsSinceEpoch}',
      source: 'chalkboard',
      pageIndex: page,
      rawText: cleanText,
      normalizedBounds: sentenceRect,
      tokens: buildTokens(localData.tokens),
      isVisible: true,
      normalizedOffset: Offset.zero,
    );

    addChalkAnnotation(annotation);

    try {
      final backendTokens =
          await EnglishSentenceAnalyzer.analyzeTokensWithBackend(cleanText);
      if (backendTokens.isNotEmpty) {
        final updated = annotation.copyWith(tokens: buildTokens(backendTokens));
        final idx = currentChalkAnnotations.indexWhere(
          (a) => a.id == annotation.id,
        );
        if (idx != -1) {
          currentChalkAnnotations[idx] = updated;
          dirty = true;
          _revision++;
          notifyListeners();
        }
      }
    } catch (_) {}
  }
}

