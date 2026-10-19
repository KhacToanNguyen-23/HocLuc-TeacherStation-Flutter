import 'package:teaching_companion/utils/frontend_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';
import 'package:teaching_companion/core/network/local_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/audio_translation_service.dart';
import 'package:teaching_companion/features/classroom_meet/services/teacher_media_service.dart';
import 'package:teaching_companion/core/platform/desktop_lifecycle.dart';
import 'package:teaching_companion/features/plugin_engine/services/plugin_manager.dart';
import 'package:teaching_companion/features/plugin_engine/services/host_bridge.dart';
import 'board_sticker.dart';
import 'smart_chalk_annotation.dart';
import 'package:teaching_companion/features/studio_board/services/stroke_clusterer.dart';
import 'package:teaching_companion/features/studio_board/services/english_analyzer.dart';
import 'smart_pen_answer_selection.dart';
export 'smart_pen_answer_selection.dart';

part 'studio_board_models.dart';
part 'studio_state_plugins.dart';
part 'studio_state_annotations.dart';
part 'smart_pen_oval_annotation.dart';
part 'studio_state_smart_pen.dart';
part 'studio_state_pdf.dart';

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
  bool get smartSnapEnabled {
    if (_smartSnapEnabled) return true;
    final plugin = activePlugin;
    if (plugin == null || activeSubjectTool == null) return false;
    return plugin.manifest.contributesTools.any(
      (tool) => tool.pdfTapMode && tool.target == activeSubjectTool,
    );
  }

  bool _saveAnswerCirclesEnabled = true;
  bool get saveAnswerCirclesEnabled => _saveAnswerCirclesEnabled;
  static const String saveAnswerCirclesSettingKey = 'pdf_answer_circles.save';
  final Map<String, bool> _contributedToolSettings = {};
  SmartPenAnswerSelection? smartPenAnswerSelection;
  final Map<String, List<_SmartPenHistoryEntry>> _smartPenUndo = {};
  final Map<String, List<_SmartPenHistoryEntry>> _smartPenRedo = {};
  final Map<BoardStroke, int> _boardUndoSequence = {};
  final Map<BoardStroke, int> _boardRedoSequence = {};
  int _historySequence = 0;

  String get _smartPenHistoryKey => activeDocId ?? pdfFilePath ?? 'current-pdf';

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
  bool? _pdfFitWidth = true;
  int? _pdfZoomAction = 0;
  bool _isSpacePressed = false;
  Map<int, List<BoardStroke>>? _pdfAnnotations;
  Map<int, List<BoardStroke>> get pdfAnnotations =>
      _pdfAnnotations ??= <int, List<BoardStroke>>{};
  set pdfAnnotations(Map<int, List<BoardStroke>> map) => _pdfAnnotations = map;

  // Temporary answer overrides are deliberately kept outside pdfAnnotations,
  // which is consumed by lesson serialization, imported-document snapshots,
  // and PDF export. A present key with a null value suppresses a saved answer
  // in the live view only; a BoardStroke value temporarily replaces its group.
  final Map<String, Map<int, Map<String, BoardStroke?>>>
  _temporarySmartPenOverrides = {};

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
    Map<String, dynamic> serializePdfAnnotations(
      Map<int, List<BoardStroke>> annotations,
    ) => annotations.map(
      (page, strokes) => MapEntry(
        page.toString(),
        strokes.map((stroke) => stroke.toJson()).toList(),
      ),
    );

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
      'importedPdfDocuments': importedDocs.map((document) {
        final annotations = document.id == activeDocId
            ? pdfAnnotations
            : document.annotations;
        return {
          'id': document.id,
          'name': document.name,
          'path': document.path,
          'contentFingerprint':
              document.contentFingerprint ??
              (document.bytes == null
                  ? null
                  : _pdfContentFingerprint(document.bytes!)),
          'totalPages': document.id == activeDocId
              ? pdfTotalPages
              : document.totalPages,
          'annotations': serializePdfAnnotations(annotations),
        };
      }).toList(),
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
    // This is a session preference, not lesson data. Loading any lesson starts
    // with the safe default that new answer circles are saved.
    _saveAnswerCirclesEnabled = true;
    // Session-only answer overrides and their undo history belong to the
    // previous lesson/PDF session, even when the incoming lesson has no PDF.
    _temporarySmartPenOverrides.clear();
    _clearSmartPenHistory();
    // A restored lesson may have no active PDF even when this StudioState was
    // previously showing one. Reset the old view before restoring document
    // metadata so a closed-document lesson cannot keep displaying stale bytes.
    pdfFilePath = null;
    pdfBytes = null;
    pdfPage = 1;
    pdfTotalPages = 1;
    pdfAnnotations.clear();
    activeDocId = null;
    importedDocs.clear();
    if (json['importedPdfDocuments'] is List) {
      for (final entry in json['importedPdfDocuments'] as List) {
        if (entry is! Map) continue;
        final documentJson = Map<String, dynamic>.from(entry);
        final name = documentJson['name'] as String?;
        if (name == null || name.isEmpty) continue;
        final document = ImportedDocument(
          id:
              documentJson['id'] as String? ??
              DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          path: documentJson['path'] as String?,
          contentFingerprint: documentJson['contentFingerprint'] as String?,
          totalPages: (documentJson['totalPages'] as num?)?.toInt() ?? 1,
        );
        final annotations = documentJson['annotations'];
        if (annotations is Map) {
          annotations.forEach((key, value) {
            final pageNumber = int.tryParse(key.toString());
            if (pageNumber == null || value is! List) return;
            document.annotations[pageNumber] = value
                .map(
                  (stroke) => BoardStroke.fromJson(
                    Map<String, dynamic>.from(stroke as Map),
                  ),
                )
                .toList();
          });
        }
        importedDocs.add(document);
      }
    }
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
    final restoredActiveDocument = activeDoc;
    if (restoredActiveDocument != null) {
      restoredActiveDocument.annotations
        ..clear()
        ..addAll(
          pdfAnnotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      restoredActiveDocument.totalPages = pdfTotalPages;
    }
    dirty = false;
    _revision++;
    notifyListeners();
  }

  Future<bool> save() async {
    if (saving) return false;
    final lessonSnapshot = exportLessonJson();
    final lessonSnapshotJson = jsonEncode(lessonSnapshot);
    final configSnapshot = {
      'endpoint': endpoint,
      'language': language,
      'microphone': microphone,
      'denoise': denoise,
      'audio': audio.preferences,
    };
    final configSnapshotJson = jsonEncode(configSnapshot);
    saving = true;
    notifyListeners();
    try {
      await service.request('lesson', data: lessonSnapshot);
      await service.request('config', data: configSnapshot);
      final currentConfig = {
        'endpoint': endpoint,
        'language': language,
        'microphone': microphone,
        'denoise': denoise,
        'audio': audio.preferences,
      };
      dirty =
          jsonEncode(exportLessonJson()) != lessonSnapshotJson ||
          jsonEncode(currentConfig) != configSnapshotJson;
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

