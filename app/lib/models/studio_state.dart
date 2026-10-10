import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/local_service.dart';
import '../services/desktop_lifecycle.dart';

import 'package:perfect_freehand/perfect_freehand.dart';

enum StudioViewportMode { fullBoard, fullPdf, split }

class BoardStroke {
  BoardStroke(this.color, this.width, this.points, {this.isEraser = false});
  final Color color;
  final double width;
  final List<Offset> points;
  final bool isEraser;
  Path? _cachedPath;
  Size? _cachedSize;

  Path getPath([Size? size]) {
    if (size == null) {
      if (_cachedPath != null && _cachedSize == null) return _cachedPath!;
      if (points.isEmpty) return Path();
      if (points.length == 1) {
        _cachedSize = null;
        _cachedPath = Path()
          ..addOval(Rect.fromCircle(center: points.first, radius: width / 2));
        return _cachedPath!;
      }
      final pointVectors = points.map((p) => PointVector(p.dx, p.dy)).toList();
      final outline = getStroke(
        pointVectors,
        options: StrokeOptions(
          size: width,
          thinning: 0.35,
          smoothing: 0.65,
          streamline: 0.5,
          isComplete: true,
        ),
      );
      final path = Path();
      if (outline.isNotEmpty) {
        path.moveTo(outline.first.dx, outline.first.dy);
        for (int i = 1; i < outline.length; i++) {
          path.lineTo(outline[i].dx, outline[i].dy);
        }
        path.close();
      }
      _cachedSize = null;
      _cachedPath = path;
      return path;
    }

    if (_cachedSize == size && _cachedPath != null) return _cachedPath!;
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final p = Offset(
        points.first.dx * size.width,
        points.first.dy * size.height,
      );
      _cachedSize = size;
      _cachedPath = Path()
        ..addOval(Rect.fromCircle(center: p, radius: width / 2));
      return _cachedPath!;
    }

    final pointVectors = points
        .map((p) => PointVector(p.dx * size.width, p.dy * size.height))
        .toList();
    final isHighlight = width > 6;
    final outline = getStroke(
      pointVectors,
      options: StrokeOptions(
        size: width,
        thinning: isHighlight ? 0.0 : 0.35,
        smoothing: 0.65,
        streamline: 0.5,
        isComplete: true,
      ),
    );
    final path = Path();
    if (outline.isNotEmpty) {
      path.moveTo(outline.first.dx, outline.first.dy);
      for (int i = 1; i < outline.length; i++) {
        path.lineTo(outline[i].dx, outline[i].dy);
      }
      path.close();
    }
    _cachedSize = size;
    _cachedPath = path;
    return path;
  }

  void invalidatePath() {
    _cachedPath = null;
    _cachedSize = null;
  }

  Map<String, dynamic> toJson() => {
    'color': color.toARGB32(),
    'width': width,
    'isEraser': isEraser,
    'points': points.map((p) => [p.dx, p.dy]).toList(),
  };
  static BoardStroke fromJson(Map<String, dynamic> json) => BoardStroke(
    Color((json['color'] as num).toInt()),
    (json['width'] as num).toDouble(),
    (json['points'] as List)
        .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList(),
    isEraser: json['isEraser'] as bool? ?? false,
  );
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
  StudioState({LocalService? service}) : service = service ?? LocalService();
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
      view = 'board',
      tool = 'pen';
  bool reveal = false, denoise = true;
  int page = 0, seconds = 300;
  Color ink = const Color(0xfff0f3ed);
  double strokeWidth = 3.5;
  Offset? laserOffset;
  StudioViewportMode viewportMode = StudioViewportMode.fullBoard;
  bool pdfOnRight = false;
  double splitRatio = 0.5;
  bool showCameraPip = false;
  bool pipMinimized = false;
  Offset pipPosition = const Offset(16, 16);
  bool showQuestionsDrawer = false;
  int timerInitialSeconds = 300;
  bool hasCustomPdfWindowSize = false;
  bool hasCustomPdfWindowPos = false;

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
    pipPosition = pos;
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

  List<List<BoardStroke>> pages = [[], [], []];
  Timer? _timer;
  String savedAt = '';
  int _revision = 0;
  int get revision => _revision;
  List<BoardStroke> get strokes => pages[page];
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

  bool _pdfFitPage = false;
  bool get pdfFitPage => _pdfFitPage;
  void togglePdfFit() {
    _pdfFitPage = !_pdfFitPage;
    notifyListeners();
  }

  void setPdfFitPage(bool fit) {
    if (_pdfFitPage != fit) {
      _pdfFitPage = fit;
      notifyListeners();
    }
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
        page = ((lesson['page'] as num?)?.toInt() ?? 0).clamp(0, 2);
        if (lesson['pages'] is List && (lesson['pages'] as List).length == 3) {
          pages = (lesson['pages'] as List)
              .map(
                (p) => (p as List)
                    .map((s) => BoardStroke.fromJson(s as Map<String, dynamic>))
                    .toList(),
              )
              .toList();
        }
        endpoint = config['endpoint'] as String? ?? '';
        language = config['language'] as String? ?? 'English';
        microphone = config['microphone'] as String? ?? '';
        if (microphone.isNotEmpty &&
            !microphones.any((m) => m['id'] == microphone)) {
          microphone = '';
        }
        denoise = config['denoise'] as bool? ?? true;
        dirty = false;
      }
      online = true;
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
    final w = tool == 'highlight' ? 20.0 : strokeWidth;
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
    list.removeWhere(
      (stroke) => stroke.points.any((p) => (p - point).distance < .035),
    );
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

  void addPage() {
    pages.add([]);
    page = pages.length - 1;
    notifyListeners();
  }

  void setPage(int p) {
    if (p >= 0 && p < pages.length && p != page) {
      page = p;
      notifyListeners();
    }
  }

  void clearPage() {
    if (strokes.isNotEmpty) {
      _currentRedoStack.addAll(strokes);
      change(() => strokes.clear());
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

  Future<bool> save() async {
    if (saving) return false;
    final revision = _revision;
    final lessonSnapshot = {
      'title': title,
      'subject': subject,
      'notes': notes,
      'question': question,
      'page': page,
      'pages': pages.map((p) => p.map((s) => s.toJson()).toList()).toList(),
    };
    final configSnapshot = {
      'endpoint': endpoint,
      'language': language,
      'microphone': microphone,
      'denoise': denoise,
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
    service.dispose();
    super.dispose();
  }
}
