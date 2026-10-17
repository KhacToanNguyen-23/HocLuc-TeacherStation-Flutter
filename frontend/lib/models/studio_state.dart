import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/local_service.dart';
import '../services/audio_translation_service.dart';
import '../services/teacher_media_service.dart';
import '../services/desktop_lifecycle.dart';
import '../services/plugin_manager.dart';
import '../services/host_bridge.dart';
import 'board_sticker.dart';
import 'board_stroke.dart';
import 'smart_pen_answer_selection.dart';
import 'smart_pen_oval_annotation.dart';
export 'board_stroke.dart';
export 'smart_pen_answer_selection.dart';
import 'smart_chalk_annotation.dart';
import '../services/stroke_clusterer.dart';
import '../services/english_analyzer.dart';

enum StudioViewportMode { fullBoard, fullPdf, split }

class _SmartPenHistoryEntry {
  _SmartPenHistoryEntry({
    required this.pageNumber,
    required this.groupId,
    required this.before,
    required this.after,
    required this.sequence,
  });

  final int pageNumber;
  final String groupId;
  final List<BoardStroke> before;
  final List<BoardStroke> after;
  int sequence;
  int redoSequence = 0;
}

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

class ImportedDocument {
  ImportedDocument({
    required this.id,
    required this.name,
    this.path,
    this.bytes,
    this.totalPages = 1,
  });

  final String id;
  final String name;
  final String? path;
  final Uint8List? bytes;
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

class StudioState extends ChangeNotifier {
  StudioState({LocalService? service}) : service = service ?? LocalService() {
    audio = AudioTranslationService(
      service: LocalService(base: this.service.base),
      manageRuntime: true,
    );
    TeacherMediaService().addListener(_syncAudioMute);
    _syncAudioMute();
  }
  late final AudioTranslationService audio;
  void _syncAudioMute() {
    final muted = !TeacherMediaService().isMicActive;
    if (audio.muted != muted) unawaited(audio.setMuted(muted));
  }

  final LocalService service;
  bool online = false, loading = true, saving = false, dirty = false;
  String? error;
  Map<String, dynamic> capabilities = {};
  List<Map<String, dynamic>> microphones = [];
  String title = 'Không gian giảng dạy',
      subject = 'Chung',
      notes = '',
      question = 'Câu hỏi thảo luận cho cả lớp',
      endpoint = '',
      language = 'Tiếng Việt',
      microphone = '',
      view = 'board';
  String _tool = 'pen';
  String get tool => _tool;
  set tool(String val) {
    if (_tool != val || activeSubjectTool != null) {
      _tool = val;
      activeSubjectTool = null;
      notifyListeners();
    }
  }

  bool _smartSnapEnabled = false;
  bool get smartSnapEnabled => _smartSnapEnabled;
  SmartPenAnswerSelection? smartPenAnswerSelection;
  final Map<String, List<_SmartPenHistoryEntry>> _smartPenUndo = {};
  final Map<String, List<_SmartPenHistoryEntry>> _smartPenRedo = {};
  final Map<BoardStroke, int> _boardUndoSequence = {};
  final Map<BoardStroke, int> _boardRedoSequence = {};
  int _historySequence = 0;

  String get _smartPenHistoryKey => activeDocId ?? pdfFilePath ?? 'current-pdf';

  void setSmartSnapEnabled(bool enabled) {
    if (_smartSnapEnabled == enabled) return;
    _smartSnapEnabled = enabled;
    notifyListeners();
  }

  void dispatchSmartPenAnswer(SmartPenAnswerSelection selection) {
    smartPenAnswerSelection = selection;
    notifyListeners();
  }

  void toggleSmartPenAnswer(SmartPenAnswerSelection selection, Size pageSize) {
    final pageStrokes = pdfAnnotations.putIfAbsent(
      selection.pageNumber,
      () => <BoardStroke>[],
    );
    final before = pageStrokes
        .where(
          (stroke) =>
              stroke.isSmartPenOval &&
              stroke.smartPenGroupId == selection.groupId,
        )
        .map((stroke) => stroke.copy())
        .toList();
    final isSameAnswer = before.any(
      (stroke) => stroke.smartPenLabel == selection.label,
    );
    if (isSameAnswer) {
      pageStrokes.removeWhere(
        (stroke) =>
            stroke.isSmartPenOval &&
            stroke.smartPenGroupId == selection.groupId,
      );
    } else {
      pageStrokes.removeWhere(
        (stroke) =>
            stroke.isSmartPenOval &&
            stroke.smartPenGroupId == selection.groupId,
      );
      final oval = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: pageSize,
        color: ink,
        width: strokeWidth,
      );
      pageStrokes.add(oval.toBoardStroke());
    }
    final after = pageStrokes
        .where(
          (stroke) =>
              stroke.isSmartPenOval &&
              stroke.smartPenGroupId == selection.groupId,
        )
        .map((stroke) => stroke.copy())
        .toList();
    _smartPenUndo
        .putIfAbsent(_smartPenHistoryKey, () => [])
        .add(
          _SmartPenHistoryEntry(
            pageNumber: selection.pageNumber,
            groupId: selection.groupId,
            before: before,
            after: after,
            sequence: ++_historySequence,
          ),
        );
    _smartPenRedo[_smartPenHistoryKey]?.clear();
    _currentRedoStack.clear();
    smartPenAnswerSelection = selection;
    _revision++;
    dirty = true;
    notifyListeners();
  }

  bool reveal = false, denoise = false;
  int _page = 0, seconds = 300;
  int get page => _page;
  set page(int p) {
    final next = p < 0 ? 0 : p;
    while (pages.length <= next) {
      pages.add([]);
      pageTitles.add('Trang ${pages.length}');
    }
    _page = next;
  }

  Color ink = const Color(0xfff0f3ed);
  double strokeWidth = 3.5;
  double highlighterWidth = 20.0;
  double eraserRadius = 0.04;
  Offset? laserOffset;
  Color? customColor;
  List<Color> recentColors = [];

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
    dirty = true;
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
    dirty = true;
    notifyListeners();
  }

  StudioViewportMode viewportMode = StudioViewportMode.fullBoard;
  bool pdfOnRight = false;
  double splitRatio = 0.5;
  bool showCameraPip = false;
  bool pipMinimized = false;
  // Fraction of the available travel distance; stable across board resizing.
  Offset pipPosition = const Offset(0.98, 0.02);
  double pipWidthFraction = 0.22;
  bool showQuestionsDrawer = false;
  int timerInitialSeconds = 300;
  bool hasCustomPdfWindowSize = false;
  bool hasCustomPdfWindowPos = false;

  InstalledPlugin? activePlugin;
  bool showPluginDrawer = false;
  bool pluginFloating = false;
  Offset pluginFloatingPosition = const Offset(80, 80);
  Size pluginFloatingSize = const Size(420, 560);

  String? activeSubjectTool;
  bool chalkAnnotationsVisible = true;
  Offset subjectPaletteOffset = const Offset(24, 20);

  void setActiveSubjectTool(String? t) {
    activeSubjectTool = t;
    notifyListeners();
  }

  void toggleChalkAnnotationsVisibility() {
    chalkAnnotationsVisible = !chalkAnnotationsVisible;
    notifyListeners();
  }

  void setSubjectPaletteOffset(Offset offset) {
    subjectPaletteOffset = offset;
    notifyListeners();
  }

  void openPlugin(InstalledPlugin plugin, {bool openModal = false}) {
    activePlugin = plugin;
    showPluginDrawer = openModal;
    pluginFloating = false;
    showQuestionsDrawer = false;
    notifyListeners();
  }

  void closePlugin() {
    activePlugin = null;
    showPluginDrawer = false;
    pluginFloating = false;
    activeSubjectTool = null;
    notifyListeners();
  }

  void togglePluginFloating() {
    pluginFloating = !pluginFloating;
    notifyListeners();
  }

  void setPluginFloatingPosition(Offset pos) {
    pluginFloatingPosition = pos;
    notifyListeners();
  }

  void setPluginFloatingSize(Size s) {
    pluginFloatingSize = s;
    notifyListeners();
  }

  dynamic pdfViewerController;
  GlobalKey? pdfViewerKey;

  final List<PdfDgnlPassage> _pdfDgnlPassages = [];
  List<PdfDgnlPassage> get pdfDgnlPassages => _pdfDgnlPassages;

  List<PdfDgnlPassage> getPdfDgnlPassagesForPage(int pageNumber) =>
      _pdfDgnlPassages
          .where((p) => p.pageNumber == pageNumber && p.isVisible)
          .toList();

  void addPdfDgnlPassage(PdfDgnlPassage passage) {
    _pdfDgnlPassages.removeWhere(
      (p) =>
          p.pageNumber == passage.pageNumber &&
          p.normalizedBounds.overlaps(passage.normalizedBounds),
    );
    _pdfDgnlPassages.add(passage);
    notifyListeners();
  }

  void removePdfDgnlPassage(String id) {
    _pdfDgnlPassages.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  void togglePdfDgnlPassageVisibility(String id) {
    for (final p in _pdfDgnlPassages) {
      if (p.id == id) {
        p.isVisible = !p.isVisible;
        break;
      }
    }
    notifyListeners();
  }

  void clearPdfDgnlPassages() {
    _pdfDgnlPassages.clear();
    notifyListeners();
  }

  /// Tự động định vị và tạo Highlight trực tiếp trên đề PDF từ kết quả phân tích DGNL
  Future<void> highlightPdfPassageFromAnalysis(
    String rawText,
    List<Map<String, dynamic>> rawHighlights, {
    Map<String, dynamic> metrics = const {},
  }) async {
    final ctrl = pdfViewerController;
    if (ctrl == null || !ctrl.isReady || ctrl.pages.isEmpty) return;

    final targetPageNum = pdfPage.clamp(1, ctrl.pages.length);
    final page = ctrl.pages[targetPageNum - 1];

    try {
      final pageText = await page.loadText();
      if (pageText == null || pageText.fullText.isEmpty) return;

      final full = pageText.fullText;
      final fullLower = full.toLowerCase();

      final snippetClean = rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
      final snippetWords = snippetClean.split(' ');
      final leadPhrase = snippetWords.take(5).join(' ').toLowerCase();

      int passStartIdx = fullLower.indexOf(leadPhrase);
      if (passStartIdx == -1 && snippetWords.isNotEmpty) {
        passStartIdx = fullLower.indexOf(snippetWords.first.toLowerCase());
      }
      passStartIdx = passStartIdx.clamp(0, math.max(0, full.length - 1));

      final passEndIdx = math.min(
        full.length - 1,
        passStartIdx + snippetClean.length,
      );
      final passCharBoxes = <Rect>[];
      for (
        int i = passStartIdx;
        i <= passEndIdx && i < pageText.charRects.length;
        i++
      ) {
        final r = pageText.charRects[i];
        final rFlutter = r.toRect(page: page);
        passCharBoxes.add(
          Rect.fromLTRB(
            (rFlutter.left / page.width).clamp(0.0, 1.0),
            (rFlutter.top / page.height).clamp(0.0, 1.0),
            (rFlutter.right / page.width).clamp(0.0, 1.0),
            (rFlutter.bottom / page.height).clamp(0.0, 1.0),
          ),
        );
      }

      Rect passBounds = const Rect.fromLTWH(0.05, 0.2, 0.9, 0.5);
      if (passCharBoxes.isNotEmpty) {
        double minX = passCharBoxes.first.left;
        double maxX = passCharBoxes.first.right;
        double minY = passCharBoxes.first.top;
        double maxY = passCharBoxes.first.bottom;
        for (final b in passCharBoxes) {
          minX = math.min(minX, b.left);
          maxX = math.max(maxX, b.right);
          minY = math.min(minY, b.top);
          maxY = math.max(maxY, b.bottom);
        }
        passBounds = Rect.fromLTRB(
          (minX - 0.02).clamp(0.0, 1.0),
          (minY - 0.01).clamp(0.0, 1.0),
          (maxX + 0.02).clamp(0.0, 1.0),
          (maxY + 0.01).clamp(0.0, 1.0),
        );
      }

      final spans = <PdfDgnlHighlightSpan>[];
      for (final hl in rawHighlights) {
        final hlText = hl['text']?.toString().trim() ?? '';
        if (hlText.isEmpty) continue;
        final category = hl['category']?.toString() ?? 'grammar';
        final level = hl['level']?.toString() ?? 'B2';
        final type = hl['type']?.toString() ?? category.toUpperCase();
        final note = hl['note']?.toString() ?? '';

        final hlLower = hlText.toLowerCase();
        int sIdx = passStartIdx;
        while ((sIdx = fullLower.indexOf(hlLower, sIdx)) != -1 &&
            sIdx <= passEndIdx + 300) {
          final eIdx = sIdx + hlLower.length;
          final matchedBoxes = <Rect>[];
          for (
            int ci = sIdx;
            ci < eIdx && ci < pageText.charRects.length;
            ci++
          ) {
            final r = pageText.charRects[ci];
            final rFlutter = r.toRect(page: page);
            matchedBoxes.add(
              Rect.fromLTRB(
                (rFlutter.left / page.width).clamp(0.0, 1.0),
                (rFlutter.top / page.height).clamp(0.0, 1.0),
                (rFlutter.right / page.width).clamp(0.0, 1.0),
                (rFlutter.bottom / page.height).clamp(0.0, 1.0),
              ),
            );
          }

          if (matchedBoxes.isNotEmpty) {
            final lines = <List<Rect>>[];
            for (final b in matchedBoxes) {
              bool added = false;
              for (final line in lines) {
                final ref = line.first;
                if ((ref.top - b.top).abs() < 0.015 ||
                    (b.top <= ref.bottom && b.bottom >= ref.top)) {
                  line.add(b);
                  added = true;
                  break;
                }
              }
              if (!added) lines.add([b]);
            }
            final lineRects = <Rect>[];
            for (final line in lines) {
              double lx1 = line.first.left, lx2 = line.first.right;
              double ly1 = line.first.top, ly2 = line.first.bottom;
              for (final r in line) {
                lx1 = math.min(lx1, r.left);
                lx2 = math.max(lx2, r.right);
                ly1 = math.min(ly1, r.top);
                ly2 = math.max(ly2, r.bottom);
              }
              lineRects.add(
                Rect.fromLTRB(
                  lx1,
                  (ly1 - 0.001).clamp(0.0, 1.0),
                  lx2,
                  (ly2 + 0.001).clamp(0.0, 1.0),
                ),
              );
            }

            spans.add(
              PdfDgnlHighlightSpan(
                text: hlText,
                category: category,
                level: level,
                type: type,
                note: note,
                normalizedRects: lineRects,
              ),
            );
          }
          sIdx = eIdx;
        }
      }

      final passage = PdfDgnlPassage(
        id: 'dgnl-${DateTime.now().millisecondsSinceEpoch}',
        pageNumber: targetPageNum.toInt(),
        rawText: snippetClean,
        normalizedBounds: passBounds,
        spans: spans,
        metrics: metrics,
        clozeQuestions: const [],
      );

      addPdfDgnlPassage(passage);
    } catch (e) {
      FrontendLogger.write(
        '[StudioState] highlightPdfPassageFromAnalysis error: $e',
      );
    }
  }

  bool isSnippingActive = false;
  String snipTarget = 'dgnl';

  bool _wasFloatingBeforeSnip = false;
  void Function(String text, String target)? onSnippetCapturedForPlugin;
  VoidCallback? onSaveHighlightedPdfRequested;
  VoidCallback? onApplyHighlightToPdfRequested;

  void startSnipping({String target = 'dgnl'}) {
    _wasFloatingBeforeSnip = pluginFloating;
    showPluginDrawer = false;
    pluginFloating = false;
    isSnippingActive = true;
    snipTarget = target;
    notifyListeners();
  }

  void stopSnipping() {
    isSnippingActive = false;
    showPluginDrawer = false;
    if (_wasFloatingBeforeSnip) {
      pluginFloating = true;
    }
    notifyListeners();
  }

  void sendSnippetToPlugin(String text, {String? target}) {
    final t = target ?? snipTarget;
    stopSnipping();
    final clean = text.trim();
    if (clean.isNotEmpty) {
      if (activePlugin != null && _wasFloatingBeforeSnip) {
        pluginFloating = true;
      }
      onSnippetCapturedForPlugin?.call(clean, t);
      notifyListeners();
    }
  }

  void handlePluginMessage(
    dynamic message, {
    void Function(String jsScript)? executeJs,
  }) {
    HostBridge.instance.handleMessage(
      rawMessage: message,
      studio: this,
      manifest: activePlugin?.manifest,
      executeJs: executeJs,
    );
  }

  Offset? _pdfWindowPosition;
  Offset get pdfWindowPosition => _pdfWindowPosition ?? const Offset(0, 0);
  set pdfWindowPosition(Offset pos) => _pdfWindowPosition = pos;

  Size? _pdfWindowSize;
  Size get pdfWindowSize => _pdfWindowSize ?? const Size(540, 720);
  set pdfWindowSize(Size s) => _pdfWindowSize = s;

  bool? _pdfWindowMaximized;
  bool get pdfWindowMaximized => _pdfWindowMaximized ?? false;
  set pdfWindowMaximized(bool val) => _pdfWindowMaximized = val;

  void setPdfWindowPosition(Offset pos) {
    hasCustomPdfWindowPos = true;
    pdfWindowPosition = pos;
    notifyListeners();
  }

  void setPdfWindowSize(Size s) {
    hasCustomPdfWindowSize = true;
    pdfWindowSize = s;
    notifyListeners();
  }

  void togglePdfWindowMaximized() {
    pdfWindowMaximized = !pdfWindowMaximized;
    notifyListeners();
  }

  void togglePdfPosition() {
    pdfOnRight = !pdfOnRight;
    notifyListeners();
  }

  void setPdfOnRight(bool onRight) {
    if (pdfOnRight != onRight) {
      pdfOnRight = onRight;
      notifyListeners();
    }
  }

  void setSplitRatio(double ratio) {
    final clamped = ratio.clamp(0.2, 0.8);
    if ((splitRatio - clamped).abs() > 0.002) {
      splitRatio = clamped;
      notifyListeners();
    }
  }

  final List<ImportedDocument> importedDocs = [];
  String? activeDocId;

  ImportedDocument? get activeDoc {
    if (activeDocId == null) return null;
    return importedDocs.where((d) => d.id == activeDocId).firstOrNull;
  }

  void addImportedDoc(String name, String? path, Uint8List? bytes) {
    final existing = importedDocs
        .where((d) => d.name == name || (path != null && d.path == path))
        .firstOrNull;
    if (existing != null) {
      selectDoc(existing.id);
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final doc = ImportedDocument(id: id, name: name, path: path, bytes: bytes);
    importedDocs.add(doc);
    selectDoc(id);
  }

  void selectDoc(String id, {StudioViewportMode? targetMode}) {
    final doc = importedDocs.where((d) => d.id == id).firstOrNull;
    if (doc == null) return;

    if (activeDoc != null && activeDoc!.id != id) {
      activeDoc!.annotations.clear();
      activeDoc!.annotations.addAll(pdfAnnotations);
      activeDoc!.totalPages = pdfTotalPages;
    }

    activeDocId = id;
    pdfFilePath = doc.path;
    pdfBytes = doc.bytes;
    pdfPage = 1;
    pdfTotalPages = doc.totalPages > 0 ? doc.totalPages : 1;
    pdfAnnotations.clear();
    pdfAnnotations.addAll(doc.annotations);

    if (targetMode != null) {
      viewportMode = targetMode;
    } else if (viewportMode == StudioViewportMode.fullBoard) {
      viewportMode = StudioViewportMode.split;
    }
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void removeDoc(String id) {
    final index = importedDocs.indexWhere((d) => d.id == id);
    if (index == -1) return;
    importedDocs.removeAt(index);
    if (activeDocId == id) {
      if (importedDocs.isNotEmpty) {
        selectDoc(importedDocs.last.id);
      } else {
        activeDocId = null;
        setPdfFile(null, null);
        viewportMode = StudioViewportMode.fullBoard;
      }
    }
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void closeDocOnBoard() {
    hasCustomPdfWindowSize = false;
    hasCustomPdfWindowPos = false;
    if (viewportMode != StudioViewportMode.fullBoard) {
      viewportMode = StudioViewportMode.fullBoard;
      notifyListeners();
    }
  }

  Future<void> importPdfDialog() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (files.isNotEmpty) {
        for (final file in files) {
          final bytes = await file.readAsBytes();
          final name = file.name;
          addImportedDoc(name, file.path, bytes);
        }
        setViewportMode(StudioViewportMode.split);
      }
    } catch (_) {}
  }

  void setViewportMode(StudioViewportMode mode) {
    if (viewportMode != mode) {
      viewportMode = mode;
      notifyListeners();
    }
  }

  void toggleCameraPip() {
    showCameraPip = !showCameraPip;
    notifyListeners();
  }

  void togglePipMinimized() {
    pipMinimized = !pipMinimized;
    notifyListeners();
  }

  void setPipPosition(Offset pos) {
    pipPosition = Offset(pos.dx.clamp(0, 1), pos.dy.clamp(0, 1));
    notifyListeners();
  }

  void setPipWidth(double fraction) {
    pipWidthFraction = fraction.clamp(0.12, 0.4);
    notifyListeners();
  }

  void toggleQuestionsDrawer() {
    showQuestionsDrawer = !showQuestionsDrawer;
    notifyListeners();
  }

  void setQuestionsDrawer(bool open) {
    if (showQuestionsDrawer != open) {
      showQuestionsDrawer = open;
      notifyListeners();
    }
  }

  void setTimerSeconds(int sec) {
    timerInitialSeconds = sec;
    seconds = sec;
    notifyListeners();
  }

  void addTimerMinute() {
    seconds += 60;
    notifyListeners();
  }

  void resetTimer([int? sec]) {
    _timer?.cancel();
    _timer = null;
    seconds = sec ?? timerInitialSeconds;
    notifyListeners();
  }

  List<List<BoardStroke>> pages = [[]];
  List<String> pageTitles = ['Khám phá bài học'];
  List<String> pageNotes = [''];
  final Map<int, List<BoardSticker>> pageStickers = {};

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

  final Map<int, List<SmartChalkAnnotation>> pageChalkAnnotations = {};
  final Map<int, List<SmartChalkAnnotation>> pdfChalkAnnotations = {};

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
    // 1. Generate local annotation if touchPoint is near strokes
    final annotation = StrokeClusterer.clusterAndAnalyze(
      touchPoint: touchPoint,
      strokes: strokes,
      pageIndex: page,
      hintText: hintText,
    );
    if (annotation == null) {
      // User touched empty space without strokes, do NOT create phantom annotation
      return false;
    }

    // 2. Deduplicate only when a valid stroke cluster exists
    currentChalkAnnotations.removeWhere((a) {
      final center = a.normalizedBounds.center;
      return (center.dy - touchPoint.dy).abs() < 0.12 &&
          (center.dx - touchPoint.dx).abs() < 0.35;
    });

    addChalkAnnotation(annotation);

    // 3. Asynchronously refine with RapidOCR + spaCy backend
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

    // 1. Phân tích văn bản chuẩn xác qua spaCy backend
    final tokensData = await EnglishSentenceAnalyzer.analyzeTokensWithBackend(
      cleanText,
    );
    if (tokensData.isEmpty) return false;

    // 2. Gom nhóm nét vẽ tại touchPoint
    final annotation = StrokeClusterer.clusterAndAnalyze(
      touchPoint: touchPoint,
      strokes: strokes,
      pageIndex: page,
      hintText: cleanText,
    );
    if (annotation == null) return false;

    // 3. Khớp chính xác từng token từ spaCy vào các cụm nét vẽ
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

    // 4. Xóa annotation cũ cùng vùng và thêm annotation mới
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
        // OCR produced noise/gibberish (e.g. 'ase Wc') that spaCy cannot parse.
        // Keep all physical stroke clusters intact so teacher can edit/confirm.
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
        // totalTokens > annotation.tokens.length:
        // Map available physical clusters first, then position remaining tokens cleanly to the right
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
    // Deduplicate in same vicinity on that page
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

    // Use actual text bounding box if available, otherwise estimate
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
      // Standalone single word on PDF (e.g. "CONTENTS")
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

    // 1. Quick initial token layout
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

    // 2. Refine syntax via spaCy backend
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

  Timer? _timer;
  String savedAt = '';
  int _revision = 0;
  int get revision => _revision;
  void bumpRevision() {
    _revision++;
    dirty = true;
    notifyListeners();
  }

  List<BoardStroke> get strokes {
    while (pages.length <= _page) {
      pages.add([]);
      pageTitles.add('Trang ${pages.length}');
    }
    return pages[_page];
  }

  bool get timerRunning => _timer != null;

  String? pdfFilePath;
  Uint8List? pdfBytes;
  int pdfPage = 1;
  int pdfTotalPages = 1;
  Map<int, List<BoardStroke>>? _pdfAnnotations;
  Map<int, List<BoardStroke>> get pdfAnnotations =>
      _pdfAnnotations ??= <int, List<BoardStroke>>{};
  set pdfAnnotations(Map<int, List<BoardStroke>> map) => _pdfAnnotations = map;

  List<BoardStroke> get currentPdfStrokes =>
      pdfAnnotations.putIfAbsent(pdfPage, () => []);

  void setPdfFile(String? path, [Uint8List? bytes]) {
    pdfFilePath = path;
    pdfBytes = bytes;
    pdfPage = 1;
    pdfTotalPages = 1;
    pdfAnnotations.clear();
    _clearSmartPenHistory();
    smartPenAnswerSelection = null;
    if (path != null || bytes != null) {
      final name = path != null
          ? path.split(RegExp(r'[\\/]')).last
          : 'Tài liệu.pdf';
      final existing = importedDocs.where((d) => d.name == name).firstOrNull;
      if (existing == null) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final doc = ImportedDocument(
          id: id,
          name: name,
          path: path,
          bytes: bytes,
        );
        importedDocs.add(doc);
        activeDocId = id;
      } else {
        activeDocId = existing.id;
      }
    }
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void updatePdfBytesInPlace(Uint8List newBytes) {
    pdfBytes = newBytes;
    _clearSmartPenHistory();
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void setPdfPage(int p) {
    final next = p.clamp(1, pdfTotalPages > 0 ? pdfTotalPages : 1);
    if (next != pdfPage) {
      pdfPage = next;
      notifyListeners();
    }
  }

  void setPdfTotalPages(int total) {
    if (total > 0 && total != pdfTotalPages) {
      pdfTotalPages = total;
      if (activeDoc != null) {
        activeDoc!.totalPages = total;
      }
      notifyListeners();
    }
  }

  bool? _pdfFitWidth = true;
  bool get pdfFitWidth => _pdfFitWidth ?? true;
  bool get pdfFitPage => !pdfFitWidth;

  void togglePdfFit() {
    _pdfFitWidth = !pdfFitWidth;
    notifyListeners();
  }

  void setPdfFitWidth(bool fitWidth) {
    if (_pdfFitWidth != fitWidth) {
      _pdfFitWidth = fitWidth;
      notifyListeners();
    }
  }

  void setPdfFitPage(bool fit) {
    setPdfFitWidth(!fit);
  }

  int? _pdfZoomAction = 0;
  int get pdfZoomAction => _pdfZoomAction ?? 0;
  void zoomInPdf() {
    _pdfZoomAction = pdfZoomAction + 1;
    notifyListeners();
  }

  void zoomOutPdf() {
    _pdfZoomAction = pdfZoomAction - 1;
    notifyListeners();
  }

  void resetPdfZoom() {
    _pdfFitWidth = true;
    _pdfZoomAction = 999;
    notifyListeners();
  }

  bool _isSpacePressed = false;
  bool get isSpacePressed => _isSpacePressed;
  void setSpacePressed(bool pressed) {
    if (_isSpacePressed != pressed) {
      _isSpacePressed = pressed;
      notifyListeners();
    }
  }

  void clearPdfPage() {
    pdfAnnotations[pdfPage]?.clear();
    pdfChalkAnnotations[pdfPage]?.clear();
    _smartPenUndo[_smartPenHistoryKey]?.removeWhere(
      (entry) => entry.pageNumber == pdfPage,
    );
    _smartPenRedo[_smartPenHistoryKey]?.removeWhere(
      (entry) => entry.pageNumber == pdfPage,
    );
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void setLaserOffset(Offset? offset) {
    laserOffset = offset;
  }

  void finishStroke({List<BoardStroke>? target}) {
    final list = target ?? strokes;
    if (list.isNotEmpty) {
      list.last.invalidatePath();
    }
  }

  Future<void> initialize() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      await service.connect();
      final result = await Future.wait([
        service.request('capabilities'),
        service.request('devices'),
        service.request('lesson'),
        service.request('config'),
      ]);
      capabilities = result[0];
      microphones = (result[1]['microphones'] as List)
          .cast<Map<String, dynamic>>();
      final lesson = result[2], config = result[3];
      if (!dirty) {
        title = lesson['title'] as String? ?? title;
        subject = lesson['subject'] as String? ?? subject;
        notes = lesson['notes'] as String? ?? notes;
        question = lesson['question'] as String? ?? question;
        page = ((lesson['page'] as num?)?.toInt() ?? 0).clamp(0, 999);
        if (lesson['pages'] is List && (lesson['pages'] as List).isNotEmpty) {
          pages = (lesson['pages'] as List)
              .map(
                (p) => (p as List)
                    .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                    .toList(),
              )
              .toList();
          if (lesson['pageTitles'] is List) {
            pageTitles = (lesson['pageTitles'] as List).cast<String>();
          } else {
            pageTitles = List.generate(
              pages.length,
              (i) => i == 0 ? 'Khám phá bài học' : 'Trang ${i + 1}',
            );
          }
          if (lesson['pageNotes'] is List) {
            pageNotes = (lesson['pageNotes'] as List)
                .map((e) => e.toString())
                .toList();
          } else {
            pageNotes = List.generate(pages.length, (i) => i == 0 ? notes : '');
          }
          while (pageNotes.length < pages.length) {
            pageNotes.add('');
          }
          page = page.clamp(0, pages.length - 1);
        }
        endpoint = config['endpoint'] as String? ?? '';
        audio.restore(config);
        language = audio.language == 'en' ? 'English' : 'Tiếng Việt';
        microphone = config['microphone'] as String? ?? '';
        if (microphone.isNotEmpty &&
            !microphones.any((m) => m['id'] == microphone)) {
          microphone = '';
        }
        denoise = false;
        dirty = false;
      }
      online = true;
      unawaited(audio.refreshDevices());
    } catch (_) {
      online = false;
      error =
          'Chưa kết nối dịch vụ Java. Có thể thử giao diện; lưu bài cần dịch vụ chạy.';
    } finally {
      loading = false;
      notifyListeners();
      if (online) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => notifyDesktopReady(),
        );
      }
    }
  }

  void change(VoidCallback update, {bool persist = true}) {
    update();
    if (persist) {
      dirty = true;
      _revision++;
    }
    notifyListeners();
  }

  void setView(String next) => change(() => view = next, persist: false);
  void addStroke(BoardStroke stroke, {List<BoardStroke>? target}) {
    final list = target ?? strokes;
    list.add(stroke);
    if (target == null) {
      _recordBoardAction(stroke);
    } else {
      _recordPdfAction(list);
    }
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void startStroke(Offset point, {List<BoardStroke>? target}) {
    if (tool == 'laser') {
      setLaserOffset(point);
      return;
    }
    final list = target ?? strokes;
    if (tool == 'erase') {
      erase(point, target: list);
      return;
    }
    final w = tool == 'highlight' ? highlighterWidth : strokeWidth;
    final stroke = BoardStroke(ink, w, [point]);
    list.add(stroke);
    if (target == null) {
      _recordBoardAction(stroke);
    }
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void extendStroke(Offset point, {List<BoardStroke>? target}) {
    if (tool == 'laser') {
      setLaserOffset(point);
      return;
    }
    final list = target ?? strokes;
    if (tool == 'erase') {
      erase(point, target: list);
      return;
    }
    if (list.isEmpty) return;
    list.last.points.add(point);
    list.last.invalidatePath();
    _revision++;
    dirty = true;
    notifyListeners();
  }

  void erase(Offset point, {List<BoardStroke>? target}) {
    final list = target ?? strokes;
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
          final hasRemainingStrokes = strokes.any(
            (s) => !s.isEraser && s.points.any((p) => b.contains(p)),
          );
          return !hasRemainingStrokes;
        });
      }
    } else {
      // Direct hit on PDF annotations for the active page
      final pdfAnns = getPdfChalkAnnotations(pdfPage);
      pdfAnns.removeWhere((ann) {
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
    }

    _revision++;
    dirty = true;
    notifyListeners();
  }

  Map<int, List<BoardStroke>>? _redoPages;
  Map<int, List<BoardStroke>> get redoPages =>
      _redoPages ??= <int, List<BoardStroke>>{};
  List<BoardStroke> get _currentRedoStack =>
      redoPages.putIfAbsent(page, () => []);
  bool get canUndo =>
      (_smartPenUndo[_smartPenHistoryKey]?.isNotEmpty ?? false) ||
      strokes.isNotEmpty;
  bool get canRedo =>
      (_smartPenRedo[_smartPenHistoryKey]?.isNotEmpty ?? false) ||
      _currentRedoStack.isNotEmpty;

  void undo() {
    final pdfHistory = _smartPenUndo[_smartPenHistoryKey];
    final boardSequence = strokes.isEmpty
        ? -1
        : (_boardUndoSequence[strokes.last] ?? 0);
    final pdfSequence = pdfHistory == null || pdfHistory.isEmpty
        ? -1
        : pdfHistory.last.sequence;
    if (pdfHistory != null &&
        pdfHistory.isNotEmpty &&
        pdfSequence > boardSequence) {
      final entry = pdfHistory.removeLast();
      _applySmartPenHistory(entry, entry.before);
      entry.redoSequence = ++_historySequence;
      _smartPenRedo.putIfAbsent(_smartPenHistoryKey, () => []).add(entry);
      _revision++;
      dirty = true;
      notifyListeners();
      return;
    }
    if (strokes.isNotEmpty) {
      final stroke = strokes.removeLast();
      _currentRedoStack.add(stroke);
      _boardRedoSequence[stroke] = ++_historySequence;
      _revision++;
      dirty = true;
      notifyListeners();
    }
  }

  void redo() {
    final pdfHistory = _smartPenRedo[_smartPenHistoryKey];
    final boardSequence = _currentRedoStack.isEmpty
        ? -1
        : (_boardRedoSequence[_currentRedoStack.last] ?? 0);
    final pdfSequence = pdfHistory == null || pdfHistory.isEmpty
        ? -1
        : pdfHistory.last.redoSequence;
    if (pdfHistory != null &&
        pdfHistory.isNotEmpty &&
        pdfSequence > boardSequence) {
      final entry = pdfHistory.removeLast();
      _applySmartPenHistory(entry, entry.after);
      entry.sequence = ++_historySequence;
      _smartPenUndo.putIfAbsent(_smartPenHistoryKey, () => []).add(entry);
      _revision++;
      dirty = true;
      notifyListeners();
      return;
    }
    if (_currentRedoStack.isNotEmpty) {
      final stroke = _currentRedoStack.removeLast();
      strokes.add(stroke);
      _boardUndoSequence[stroke] = ++_historySequence;
      _revision++;
      dirty = true;
      notifyListeners();
    }
  }

  void _recordBoardAction(BoardStroke stroke) {
    _boardUndoSequence[stroke] = ++_historySequence;
    _currentRedoStack.clear();
    _smartPenRedo[_smartPenHistoryKey]?.clear();
  }

  void _recordPdfAction(List<BoardStroke> target) {
    final isPdfTarget = pdfAnnotations.values.any(
      (annotations) => identical(annotations, target),
    );
    if (!isPdfTarget) return;
    _currentRedoStack.clear();
    _smartPenRedo[_smartPenHistoryKey]?.clear();
  }

  void _clearSmartPenHistory() {
    _smartPenUndo.clear();
    _smartPenRedo.clear();
  }

  void _applySmartPenHistory(
    _SmartPenHistoryEntry entry,
    List<BoardStroke> snapshot,
  ) {
    final pageStrokes = pdfAnnotations.putIfAbsent(
      entry.pageNumber,
      () => <BoardStroke>[],
    );
    pageStrokes.removeWhere(
      (stroke) =>
          stroke.isSmartPenOval && stroke.smartPenGroupId == entry.groupId,
    );
    pageStrokes.addAll(snapshot.map((stroke) => stroke.copy()));
  }

  void nextPage() {
    if (page < pages.length - 1) {
      page++;
      notifyListeners();
    } else {
      addPage();
    }
  }

  void prevPage() {
    if (page > 0) {
      page--;
      notifyListeners();
    }
  }

  void addPage([String? title]) {
    pages.add([]);
    pageTitles.add(title ?? 'Trang ${pages.length}');
    pageNotes.add('');
    page = pages.length - 1;
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void deletePage(int index) {
    if (index < 0 || index >= pages.length) return;
    if (pages.length <= 1) {
      // Giữ lại ít nhất 1 trang trắng
      pages[0].clear();
      _redoPages?[0]?.clear();
      pageTitles[0] = 'Khám phá bài học';
      pageNotes[0] = '';
      dirty = true;
      _revision++;
      notifyListeners();
      return;
    }
    pages.removeAt(index);
    if (index < pageTitles.length) {
      pageTitles.removeAt(index);
    }
    if (index < pageNotes.length) {
      pageNotes.removeAt(index);
    }
    if (pageNotes.isEmpty) {
      pageNotes.add('');
    }
    final newRedo = <int, List<BoardStroke>>{};
    _redoPages?.forEach((k, v) {
      if (k < index) {
        newRedo[k] = v;
      } else if (k > index) {
        newRedo[k - 1] = v;
      }
    });
    _redoPages = newRedo;

    final newStickers = <int, List<BoardSticker>>{};
    pageStickers.forEach((k, v) {
      if (k < index) {
        newStickers[k] = v;
      } else if (k > index) {
        newStickers[k - 1] = v;
      }
    });
    pageStickers
      ..clear()
      ..addAll(newStickers);

    if (page >= pages.length) {
      page = pages.length - 1;
    } else if (page > index) {
      page--;
    }
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void renamePage(int index, String title) {
    if (index >= 0 && index < pageTitles.length) {
      final trimmed = title.trim();
      pageTitles[index] = trimmed.isEmpty ? 'Trang ${index + 1}' : trimmed;
      dirty = true;
      notifyListeners();
    }
  }

  void setPage(int p) {
    if (p >= 0 && p < pages.length && p != page) {
      page = p;
      notifyListeners();
    }
  }

  void clearPage() {
    bool changed = false;
    if (strokes.isNotEmpty) {
      _currentRedoStack.addAll(strokes);
      strokes.clear();
      changed = true;
    }
    if (currentChalkAnnotations.isNotEmpty) {
      currentChalkAnnotations.clear();
      changed = true;
    }
    if (changed) {
      _revision++;
      dirty = true;
      notifyListeners();
    }
  }

  void toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      if (seconds == 0) seconds = 120;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (seconds > 0) seconds--;
        if (seconds == 0) {
          _timer?.cancel();
          _timer = null;
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Map<String, dynamic> exportLessonJson() {
    return {
      'title': title,
      'subject': subject,
      'notes': notes,
      'question': question,
      'page': page,
      'pages': pages.map((p) => p.map((s) => s.toJson()).toList()).toList(),
      'pageTitles': pageTitles,
      'pageNotes': pageNotes,
      'stickers': pageStickers.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'smartChalkAnnotations': pageChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfChalkAnnotations': pdfChalkAnnotations.map(
        (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()),
      ),
      'pdfAnnotations': pdfAnnotations.map(
        (k, v) =>
            MapEntry(k.toString(), v.map((stroke) => stroke.toJson()).toList()),
      ),
      'pdfFilePath': pdfFilePath,
      'pdfPage': pdfPage,
      'pdfWindowMaximized': _pdfWindowMaximized,
      'hasCustomPdfWindowPos': hasCustomPdfWindowPos,
      'pdfWindowX': _pdfWindowPosition?.dx,
      'pdfWindowY': _pdfWindowPosition?.dy,
      'hasCustomPdfWindowSize': hasCustomPdfWindowSize,
      'pdfWindowW': _pdfWindowSize?.width,
      'pdfWindowH': _pdfWindowSize?.height,
    };
  }

  void restoreFromJson(Map<String, dynamic> json) {
    if (json.containsKey('title')) title = json['title'] as String? ?? title;
    if (json.containsKey('subject')) {
      subject = json['subject'] as String? ?? subject;
    }
    if (json.containsKey('notes')) {
      notes = json['notes'] as String? ?? notes;
    }
    if (json.containsKey('question')) {
      question = json['question'] as String? ?? question;
    }
    if (json.containsKey('page')) page = (json['page'] as num?)?.toInt() ?? 0;
    if (json.containsKey('pdfFilePath') && json['pdfFilePath'] is String) {
      final p = json['pdfFilePath'] as String;
      if (p.isNotEmpty) {
        setPdfFile(p);
      }
    }
    if (json.containsKey('pdfPage') && json['pdfPage'] is num) {
      pdfPage = (json['pdfPage'] as num).toInt();
    }
    if (json.containsKey('pdfWindowMaximized') &&
        json['pdfWindowMaximized'] is bool) {
      _pdfWindowMaximized = json['pdfWindowMaximized'] as bool;
    }
    if (json.containsKey('hasCustomPdfWindowPos') &&
        json['hasCustomPdfWindowPos'] == true) {
      final x = (json['pdfWindowX'] as num?)?.toDouble() ?? 0.0;
      final y = (json['pdfWindowY'] as num?)?.toDouble() ?? 0.0;
      setPdfWindowPosition(Offset(x, y));
    }
    if (json.containsKey('hasCustomPdfWindowSize') &&
        json['hasCustomPdfWindowSize'] == true) {
      final w = (json['pdfWindowW'] as num?)?.toDouble() ?? 540.0;
      final h = (json['pdfWindowH'] as num?)?.toDouble() ?? 720.0;
      setPdfWindowSize(Size(w, h));
    }
    if (json.containsKey('pageTitles') && json['pageTitles'] is List) {
      pageTitles
        ..clear()
        ..addAll((json['pageTitles'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pageNotes') && json['pageNotes'] is List) {
      pageNotes
        ..clear()
        ..addAll((json['pageNotes'] as List).map((e) => e.toString()));
    }
    if (json.containsKey('pages') && json['pages'] is List) {
      pages.clear();
      for (final p in json['pages'] as List) {
        if (p is List) {
          pages.add(
            p
                .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                .toList(),
          );
        }
      }
    }
    while (pageNotes.length < pages.length) {
      pageNotes.add('');
    }
    if (json.containsKey('stickers') && json['stickers'] is Map) {
      pageStickers.clear();
      final map = json['stickers'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          pageStickers[pageIdx] = v
              .map(
                (s) =>
                    BoardSticker.fromJson(Map<String, dynamic>.from(s as Map)),
              )
              .toList();
        }
      });
    }
    if (json.containsKey('smartChalkAnnotations') &&
        json['smartChalkAnnotations'] is Map) {
      pageChalkAnnotations.clear();
      final map = json['smartChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 0;
        if (v is List) {
          pageChalkAnnotations[pageIdx] = v
              .map(
                (s) => SmartChalkAnnotation.fromJson(
                  Map<String, dynamic>.from(s as Map),
                ),
              )
              .toList();
        }
      });
    }
    if (json.containsKey('pdfChalkAnnotations') &&
        json['pdfChalkAnnotations'] is Map) {
      pdfChalkAnnotations.clear();
      final map = json['pdfChalkAnnotations'] as Map;
      map.forEach((k, v) {
        final pageIdx = int.tryParse(k.toString()) ?? 1;
        if (v is List) {
          pdfChalkAnnotations[pageIdx] = v
              .map(
                (s) => SmartChalkAnnotation.fromJson(
                  Map<String, dynamic>.from(s as Map),
                ),
              )
              .toList();
        }
      });
    }
    if (json.containsKey('pdfAnnotations') && json['pdfAnnotations'] is Map) {
      pdfAnnotations.clear();
      final map = json['pdfAnnotations'] as Map;
      map.forEach((key, value) {
        final pageNumber = int.tryParse(key.toString()) ?? 1;
        if (value is List) {
          pdfAnnotations[pageNumber] = value
              .map(
                (stroke) => BoardStroke.fromJson(
                  Map<String, dynamic>.from(stroke as Map),
                ),
              )
              .toList();
        }
      });
    }
    dirty = false;
    _revision++;
    notifyListeners();
  }

  Future<bool> save() async {
    if (saving) return false;
    final revision = _revision;
    final lessonSnapshot = exportLessonJson();
    final configSnapshot = {
      'endpoint': endpoint,
      'language': language,
      'microphone': microphone,
      'denoise': denoise,
      'audio': audio.preferences,
    };
    saving = true;
    notifyListeners();
    try {
      await service.request('lesson', data: lessonSnapshot);
      await service.request('config', data: configSnapshot);
      dirty = _revision != revision;
      final now = DateTime.now();
      savedAt =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      online = true;
      return true;
    } catch (_) {
      online = false;
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    TeacherMediaService().removeListener(_syncAudioMute);
    audio.dispose();
    service.dispose();
    super.dispose();
  }
}
