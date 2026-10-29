import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../../domain/models/board_sticker.dart';
import '../../domain/models/smart_chalk_annotation.dart';
import '../../domain/models/studio_board_models.dart';

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

  void erase(
    Offset point, {
    List<BoardStroke>? target,
    void Function(BoardStroke stroke, int index)? onErased,
  }) {
    final list = target ?? currentStrokes;
    final r = eraserRadius;
    final int beforeCount = list.length;

    // Collect all candidate strokes that hit this point
    final hits = <BoardStroke>[];
    for (final stroke in list) {
      if (stroke.hitTest(point, r)) {
        hits.add(stroke);
      }
    }

    if (hits.isNotEmpty) {
      // Deterministic selection:
      // If multiple strokes hit, prioritize:
      // 1) Strokes with bounding rect: smallest area first (inner specific word)
      // 2) Topmost stroke / last drawn
      hits.sort((a, b) {
        if (a.rect != null && b.rect != null) {
          final areaA = a.rect!.width * a.rect!.height;
          final areaB = b.rect!.width * b.rect!.height;
          return areaA.compareTo(areaB);
        }
        if (a.rect != null) return -1;
        if (b.rect != null) return 1;
        return 0;
      });

      final strokeToRemove = hits.first;
      final index = list.indexOf(strokeToRemove);
      if (index != -1) {
        list.removeAt(index);
        onErased?.call(strokeToRemove, index);
      }
    }

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

  void addTypedChalkAnnotation(String sentence, {Offset? position}) {
    final cleanText = sentence.trim();
    if (cleanText.isEmpty) return;
    final words = cleanText.split(RegExp(r'\s+'));
    final totalLength = math.max(1, cleanText.length);
    var x = 0.0;
    final tokens = <ChalkWordToken>[];
    for (final word in words) {
      final width = (word.length / totalLength).clamp(0.05, 0.95);
      tokens.add(
        ChalkWordToken(word: word, relativeRect: Rect.fromLTWH(x, 0, width, 1)),
      );
      x += width + 1 / totalLength;
    }
    final pos = position ?? const Offset(0.20, 0.30);
    addChalkAnnotation(
      SmartChalkAnnotation(
        id: 'typed-note-${DateTime.now().millisecondsSinceEpoch}',
        source: 'chalkboard',
        pageIndex: page,
        rawText: cleanText,
        normalizedBounds: Rect.fromLTWH(
          pos.dx,
          pos.dy,
          (cleanText.length * 0.015 + 0.12).clamp(0.12, 0.85),
          0.06,
        ),
        tokens: tokens,
        isVisible: true,
        normalizedOffset: Offset.zero,
      ),
    );
  }

  @override
  void dispose() {
    laserOffsetNotifier.dispose();
    super.dispose();
  }
}
