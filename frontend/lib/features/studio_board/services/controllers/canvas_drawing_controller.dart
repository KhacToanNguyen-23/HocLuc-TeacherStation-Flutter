import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../domain/models/board_sticker.dart';
import '../../domain/models/smart_chalk_annotation.dart';
import '../../domain/models/studio_board_models.dart';
import '../english_analyzer.dart';
import '../stroke_clusterer.dart';

/// Single-responsibility controller managing freehand drawing strokes,
/// undo/redo history stacks, page collections, and board stickers/chalk.
class CanvasDrawingController extends ChangeNotifier {
  CanvasDrawingController() {
    pages.add([]);
    pageTitles.add('Khám phá bài học');
    pageNotes.add('');
  }

  int _page = 0;
  int get page => _page;
  set page(int p) {
    final next = p < 0 ? 0 : p;
    while (pages.length <= next) {
      pages.add([]);
      pageTitles.add('Trang ${pages.length}');
      pageNotes.add('');
    }
    _page = next;
    notifyListeners();
  }

  final List<List<BoardStroke>> pages = [];
  final List<String> pageTitles = [];
  final List<String> pageNotes = [];
  final Map<int, List<BoardSticker>> pageStickers = {};
  final Map<int, List<SmartChalkAnnotation>> pageChalkAnnotations = {};

  final Map<int, List<BoardStroke>> _redoStacks = {};

  String _tool = 'pen';
  String get tool => _tool;
  set tool(String val) {
    if (_tool != val) {
      _tool = val;
      notifyListeners();
    }
  }

  Color ink = const Color(0xfff0f3ed);
  double strokeWidth = 3.5;
  double highlighterWidth = 20.0;
  double eraserRadius = 0.04;

  /// Laser pointer position, published through its own [ValueNotifier] so that
  /// per-pointer-move updates repaint only the laser layer and never notify the
  /// aggregate controller listeners (which would rebuild the whole screen).
  final ValueNotifier<Offset?> laserOffsetNotifier = ValueNotifier<Offset?>(
    null,
  );
  Offset? get laserOffset => laserOffsetNotifier.value;
  set laserOffset(Offset? val) => laserOffsetNotifier.value = val;
  Color? customColor;
  final List<Color> recentColors = [];
  String? chalkDraftText;

  List<BoardStroke> get currentStrokes =>
      _page < pages.length ? pages[_page] : [];

  List<BoardSticker> get currentStickers =>
      pageStickers.putIfAbsent(_page, () => []);

  List<SmartChalkAnnotation> get currentChalkAnnotations =>
      pageChalkAnnotations.putIfAbsent(_page, () => []);

  String get currentPageNote =>
      (_page >= 0 && _page < pageNotes.length) ? pageNotes[_page] : '';

  bool get canUndo => currentStrokes.isNotEmpty;
  bool get canRedo => currentRedoStack.isNotEmpty;

  double get currentToolSize {
    if (tool == 'highlight') return highlighterWidth;
    if (tool == 'erase') return eraserRadius;
    return strokeWidth;
  }

  void setCurrentToolSize(double val) {
    if (tool == 'highlight') {
      highlighterWidth = val;
    } else if (tool == 'erase') {
      eraserRadius = val;
    } else {
      strokeWidth = val;
    }
    notifyListeners();
  }

  void setCustomColor(Color color) {
    customColor = color;
    ink = color;
    if (!recentColors.contains(color)) {
      recentColors.insert(0, color);
      if (recentColors.length > 8) {
        recentColors.removeLast();
      }
    }
    notifyListeners();
  }

  void setPageNote(int index, String note) {
    while (pageNotes.length <= index) {
      pageNotes.add('');
    }
    if (pageNotes[index] != note) {
      pageNotes[index] = note;
      notifyListeners();
    }
  }

  void addPage([String? title]) {
    pages.add([]);
    pageTitles.add(title ?? 'Trang ${pages.length}');
    pageNotes.add('');
    _page = pages.length - 1;
    notifyListeners();
  }

  void deletePage(int index) {
    if (index < 0 || index >= pages.length) return;
    if (pages.length == 1) {
      pages[0].clear();
      _redoStacks.clear();
      pageStickers.clear();
      pageChalkAnnotations.clear();
      pageTitles[0] = 'Khám phá bài học';
      pageNotes[0] = '';
      _page = 0;
      notifyListeners();
      return;
    }
    pages.removeAt(index);
    if (index < pageTitles.length) pageTitles.removeAt(index);
    if (index < pageNotes.length) pageNotes.removeAt(index);
    _reindexPages(_redoStacks, index);
    _reindexPages(pageStickers, index);
    _reindexPages(pageChalkAnnotations, index);
    for (final entry in pageChalkAnnotations.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        entry.value[i] = entry.value[i].copyWith(pageIndex: entry.key);
      }
    }
    if (_page > index) _page--;
    if (_page >= pages.length) _page = pages.length - 1;
    notifyListeners();
  }

  void _reindexPages<T>(Map<int, List<T>> items, int removed) {
    final kept = items.entries
        .where((entry) => entry.key != removed)
        .map(
          (entry) => MapEntry(
            entry.key > removed ? entry.key - 1 : entry.key,
            entry.value,
          ),
        )
        .toList();
    items
      ..clear()
      ..addEntries(kept);
  }

  void renamePage(int index, String newTitle) {
    if (index >= 0 && index < pageTitles.length) {
      final trimmed = newTitle.trim();
      pageTitles[index] = trimmed.isEmpty ? 'Trang ${index + 1}' : trimmed;
      notifyListeners();
    }
  }

  void nextPage() {
    if (_page < pages.length - 1) {
      _page++;
      notifyListeners();
    }
  }

  void prevPage() {
    if (_page > 0) {
      _page--;
      notifyListeners();
    }
  }

  void setPage(int p) {
    if (p >= 0 && p < pages.length && p != _page) {
      _page = p;
      notifyListeners();
    }
  }

  void addStroke(BoardStroke stroke) {
    while (pages.length <= _page) {
      pages.add([]);
      pageTitles.add('Trang ${pages.length}');
      pageNotes.add('');
    }
    pages[_page].add(stroke);
    _redoStacks[_page]?.clear();
    notifyListeners();
  }

  void undo() {
    if (currentStrokes.isEmpty) return;
    final lastStroke = currentStrokes.removeLast();
    currentRedoStack.add(lastStroke);
    notifyListeners();
  }

  void redo() {
    if (currentRedoStack.isEmpty) return;
    final strokeToRestore = currentRedoStack.removeLast();
    currentStrokes.add(strokeToRestore);
    notifyListeners();
  }

  void clearPage([int? targetPage]) {
    final p = targetPage ?? _page;
    if (p < pages.length) {
      pages[p].clear();
      _redoStacks[p]?.clear();
      pageStickers[p]?.clear();
      pageChalkAnnotations[p]?.clear();
      notifyListeners();
    }
  }

  List<BoardStroke> get currentRedoStack =>
      _redoStacks.putIfAbsent(_page, () => []);
  void clearRedo() => _redoStacks[_page]?.clear();

  void clearBoard() => clearPage();

  void erase(Offset point, {List<BoardStroke>? target}) {
    final list = target ?? currentStrokes;
    final r = eraserRadius;
    final int beforeCount = list.length;
    list.removeWhere(
      (stroke) => stroke.points.any((p) => (p - point).distance < r),
    );
    final bool strokesRemoved = list.length < beforeCount;

    if (target == null) {
      // 1. Direct hit on chalkboard annotations (bounds + underline + badges)
      currentChalkAnnotations.removeWhere((ann) {
        final b = ann.normalizedBounds;
        final off = ann.normalizedOffset;
        final effectiveRect = Rect.fromLTRB(
          b.left + off.dx,
          b.top + off.dy,
          b.right + off.dx,
          b.bottom + off.dy + 0.055,
        );
        return effectiveRect.inflate(r).contains(point);
      });

      // 2. Auto-clean orphan chalkboard annotations when all their handwriting strokes are erased
      if (strokesRemoved) {
        currentChalkAnnotations.removeWhere((ann) {
          if (ann.source != 'chalkboard') return false;
          final b = ann.normalizedBounds.inflate(0.025);
          final hasRemainingStrokes = currentStrokes.any(
            (s) => !s.isEraser && s.points.any((p) => b.contains(p)),
          );
          return !hasRemainingStrokes;
        });
      }
    }

    notifyListeners();
  }

  void clearPageStrokes([int? targetPage]) {
    final p = targetPage ?? _page;
    if (p < pages.length) {
      pages[p].clear();
      _redoStacks[p]?.clear();
      notifyListeners();
    }
  }

  void addSticker(BoardSticker sticker) {
    currentStickers.add(sticker);
    notifyListeners();
  }

  void updateSticker(BoardSticker updated) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      notifyListeners();
    }
  }

  void removeSticker(String id) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list.removeAt(idx);
      notifyListeners();
    }
  }

  void updateStickerRect(String id, Rect newRect) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list[idx].normalizedRect = newRect;
      notifyListeners();
    }
  }

  void updateStickerRotation(String id, double rotation) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(rotation: rotation);
      notifyListeners();
    }
  }

  void duplicateSticker(String id) {
    final list = currentStickers;
    final idx = list.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final orig = list[idx];
      final r = orig.normalizedRect;
      final offsetRect = Rect.fromLTWH(
        (r.left + 0.03).clamp(0.0, 0.9),
        (r.top + 0.03).clamp(0.0, 0.9),
        r.width,
        r.height,
      );
      final copy = orig.copyWith(
        id: 'sticker-${DateTime.now().millisecondsSinceEpoch}',
        normalizedRect: offsetRect,
      );
      list.add(copy);
      notifyListeners();
    }
  }

  void addChalkAnnotation(SmartChalkAnnotation annotation) {
    currentChalkAnnotations.add(annotation);
    notifyListeners();
  }

  void addSmartChalkAnnotation(SmartChalkAnnotation annotation) =>
      addChalkAnnotation(annotation);

  bool removeChalkAnnotation(String id) {
    for (final list in pageChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list.removeAt(idx);
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  bool updateChalkAnnotationOffset(String id, Offset newOffset) {
    for (final list in pageChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list[idx].normalizedOffset = newOffset;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  void clearChalkAnnotationsForPage(int pageIndex) {
    pageChalkAnnotations[pageIndex]?.clear();
    notifyListeners();
  }

  void clearBoardChalkAnnotations() {
    pageChalkAnnotations.clear();
    notifyListeners();
  }

  void setChalkDraftText(String? text) {
    chalkDraftText = text;
    notifyListeners();
  }

  void clearChalkDraft() {
    chalkDraftText = null;
    notifyListeners();
  }

  bool hasStrokesNear(Offset touchPoint) {
    return currentStrokes.any((s) {
      if (s.isEraser || s.points.isEmpty) return false;
      return s.points.any(
        (p) =>
            (p.dy - touchPoint.dy).abs() < 0.12 &&
            (p.dx - touchPoint.dx).abs() < 0.35,
      );
    });
  }

  bool analyzeHandwritingAt(Offset touchPoint, {String? hintText}) {
    final annotation = StrokeClusterer.clusterAndAnalyze(
      touchPoint: touchPoint,
      strokes: currentStrokes,
      pageIndex: page,
      hintText: hintText,
    );
    if (annotation == null) return false;

    currentChalkAnnotations.removeWhere((a) {
      final center = a.normalizedBounds.center;
      return (center.dy - touchPoint.dy).abs() < 0.12 &&
          (center.dx - touchPoint.dx).abs() < 0.35;
    });

    addChalkAnnotation(annotation);
    _refineAnnotationWithOcr(annotation, touchPoint);
    return true;
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
      strokes: currentStrokes,
      pageIndex: page,
      hintText: cleanText,
    );
    if (annotation == null) return false;

    final chalkTokens = <ChalkWordToken>[];
    for (int i = 0; i < tokensData.length; i++) {
      final t = tokensData[i];
      final rect = i < annotation.tokens.length
          ? annotation.tokens[i].relativeRect
          : const Rect.fromLTWH(0, 0, 1, 1);
      chalkTokens.add(
        ChalkWordToken(
          word: t['text'] as String,
          role: t['role'] as String?,
          relativeRect: rect,
        ),
      );
    }
    final updated = annotation.copyWith(
      rawText: cleanText,
      tokens: chalkTokens,
    );
    addChalkAnnotation(updated);
    return true;
  }

  void _refineAnnotationWithOcr(
    SmartChalkAnnotation annotation,
    Offset touchPoint,
  ) async {
    try {
      final lineStrokes = currentStrokes.where((s) {
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
      if (!hasValidGrammarRoles) return;

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
        notifyListeners();
      }
    } catch (_) {}
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
    const boxHeight = 0.06;
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
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    laserOffsetNotifier.dispose();
    super.dispose();
  }
}
