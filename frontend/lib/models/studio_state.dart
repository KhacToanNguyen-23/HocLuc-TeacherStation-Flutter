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
import 'smart_chalk_annotation.dart';
import '../services/stroke_clusterer.dart';
import '../services/english_analyzer.dart';

import 'package:perfect_freehand/perfect_freehand.dart';

part 'studio_board_models.dart';
part 'studio_state_plugins.dart';
part 'studio_state_annotations.dart';

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
  InstalledPlugin? floatingPlugin;
  bool showPluginDrawer = false;
  bool pluginFloating = false;
  Offset pluginFloatingPosition = const Offset(80, 80);
  Size pluginFloatingSize = const Size(420, 560);
  String? activeSubjectTool;
  bool chalkAnnotationsVisible = true;
  Offset subjectPaletteOffset = const Offset(24, 20);
  dynamic pdfViewerController;
  GlobalKey? pdfViewerKey;
  final List<PdfDgnlPassage> _pdfDgnlPassages = [];
  bool isSnippingActive = false;
  String snipTarget = 'dgnl';
  bool _wasFloatingBeforeSnip = false;
  void Function(String text, String target)? onSnippetCapturedForPlugin;
  VoidCallback? onSaveHighlightedPdfRequested;
  VoidCallback? onApplyHighlightToPdfRequested;
  Offset? _pdfWindowPosition;
  Size? _pdfWindowSize;
  bool? _pdfWindowMaximized;
  final List<ImportedDocument> importedDocs = [];
  String? activeDocId;

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

  final Map<int, List<SmartChalkAnnotation>> pageChalkAnnotations = {};
  final Map<int, List<SmartChalkAnnotation>> pdfChalkAnnotations = {};

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
    _currentRedoStack.clear();
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
    _currentRedoStack.clear();
    final w = tool == 'highlight' ? highlighterWidth : strokeWidth;
    list.add(BoardStroke(ink, w, [point]));
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
  bool get canUndo => strokes.isNotEmpty;
  bool get canRedo => _currentRedoStack.isNotEmpty;

  void undo() {
    if (strokes.isNotEmpty) {
      final stroke = strokes.removeLast();
      _currentRedoStack.add(stroke);
      _revision++;
      dirty = true;
      notifyListeners();
    }
  }

  void redo() {
    if (_currentRedoStack.isNotEmpty) {
      final stroke = _currentRedoStack.removeLast();
      strokes.add(stroke);
      _revision++;
      dirty = true;
      notifyListeners();
    }
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
