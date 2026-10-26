import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import '../../../../core/network/local_service.dart';
import '../../../../core/platform/desktop_lifecycle.dart';
import '../../../../core/theme/glass_preset.dart';
import '../../../../core/utils/adaptive_glassmorphism.dart';
import '../../../classroom_meet/services/audio_translation_service.dart';
import '../../../plugin_engine/domain/models/plugin_manifest.dart';
import '../../../plugin_engine/services/host_bridge.dart';
import '../../../plugin_engine/services/plugin_manager.dart';
import '../../../plugin_engine/services/process_supervisor.dart';
import '../../services/controllers/audio_sync_controller.dart';
import '../../services/controllers/canvas_drawing_controller.dart';
import '../../services/controllers/pdf_smart_pen_controller.dart';
import '../../services/controllers/studio_plugin_bridge_controller.dart';
import '../../services/controllers/studio_workspace_coordinator.dart';
import 'board_sticker.dart';
import 'smart_chalk_annotation.dart';
import 'smart_pen_answer_selection.dart';
import 'studio_board_models.dart';

export 'board_sticker.dart';
export 'smart_chalk_annotation.dart';
export 'smart_pen_answer_selection.dart';
export 'smart_pen_oval_annotation.dart';
export 'studio_board_models.dart';
export '../../../../core/utils/adaptive_glassmorphism.dart';

part 'studio_state_board_pages.dart';
part 'studio_state_plugin_annotations.dart';
part 'studio_state_plugin_facade.dart';

/// Backward-compatible Facade coordinating all board sub-systems:
/// Canvas Drawing, PDF & Smart Pen, WASAPI Audio, and Plugin Host Bridge.
class StudioState extends ChangeNotifier {
  StudioState({LocalService? service}) {
    coordinator = StudioWorkspaceCoordinator(service: service);
    coordinator.addListener(_onCoordinatorChanged);
  }

  late final StudioWorkspaceCoordinator coordinator;

  void _onCoordinatorChanged() {
    // Controllers mutate shared stroke lists in place. Advance the paint token
    // before forwarding the change so cached ink is invalidated this frame.
    // Do not mark dirty here: temporary PDF annotations also use this path.
    _revision++;
    notifyListeners();
  }

  LocalService get service => coordinator.service;
  CanvasDrawingController get canvas => coordinator.canvas;
  PdfSmartPenController get pdf => coordinator.pdf;
  AudioSyncController get audioController => coordinator.audio;
  StudioPluginBridgeController get pluginBridge => coordinator.plugins;
  AudioTranslationService get audio => coordinator.audio.audio;

  // --- Session Metadata & State ---
  String get title => coordinator.title;
  set title(String val) => coordinator.title = val;
  String get subject => coordinator.subject;
  set subject(String val) => coordinator.subject = val;
  String get notes => coordinator.notes;
  set notes(String val) => coordinator.notes = val;
  String get question => coordinator.question;
  set question(String val) => coordinator.question = val;
  String get endpoint => coordinator.endpoint;
  set endpoint(String val) => coordinator.endpoint = val;
  String get view => coordinator.view;
  set view(String val) => coordinator.view = val;
  bool get dirty => coordinator.dirty;
  set dirty(bool val) => coordinator.dirty = val;
  bool get saving => coordinator.saving;
  set saving(bool val) => coordinator.saving = val;
  bool get online => coordinator.online;
  set online(bool val) => coordinator.online = val;
  bool get loading => coordinator.loading;
  set loading(bool val) => coordinator.loading = val;
  String? get error => coordinator.error;
  set error(String? val) => coordinator.error = val;

  Map<String, dynamic> capabilities = {};
  int pdfContentGeneration = 0;
  final Map<String, List<_PdfAnnotationHistoryEntry>> _pdfAnnotationUndo = {};
  final Map<String, List<_PdfAnnotationHistoryEntry>> _pdfAnnotationRedo = {};
  final Map<String, Map<int, Map<String, BoardStroke?>>>
  _temporaryPdfAnnotationOverrides = {};
  final Map<BoardStroke, int> _boardUndoSequence = {};
  final Map<BoardStroke, int> _boardRedoSequence = {};
  Map<int, List<BoardStroke>>? _redoPages;
  int _historySequence = 0;
  int _revision = 0;
  int get revision => _revision;
  void bumpRevision() {
    _revision++;
    dirty = true;
    notifyListeners();
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

  StudioViewportMode get viewportMode {
    if (view == 'pdf') return StudioViewportMode.fullPdf;
    if (view == 'split') return StudioViewportMode.split;
    return StudioViewportMode.fullBoard;
  }

  void setViewportMode(StudioViewportMode mode) {
    switch (mode) {
      case StudioViewportMode.fullBoard:
        view = 'board';
        break;
      case StudioViewportMode.fullPdf:
        view = 'pdf';
        break;
      case StudioViewportMode.split:
        view = 'split';
        break;
    }
    notifyListeners();
  }

  // --- Audio Properties ---
  String get language => coordinator.audio.language;
  set language(String val) => coordinator.audio.setLanguage(val);
  String get microphone => coordinator.audio.microphone;
  set microphone(String val) => coordinator.audio.microphone = val;
  List<Map<String, dynamic>> get microphones => coordinator.audio.microphones;
  set microphones(List<Map<String, dynamic>> val) =>
      coordinator.audio.microphones = val;
  bool get isMicActive => coordinator.audio.isMicActive;

  // --- Canvas Drawing Properties ---
  int get page => canvas.page;
  set page(int p) => canvas.page = p;

  List<List<BoardStroke>> get pages => canvas.pages;
  set pages(List<List<BoardStroke>> val) {
    canvas.pages.clear();
    canvas.pages.addAll(val);
    notifyListeners();
  }

  List<String> get pageTitles => canvas.pageTitles;
  List<String> get pageNotes => canvas.pageNotes;
  Map<int, List<BoardSticker>> get pageStickers => canvas.pageStickers;
  Map<int, List<SmartChalkAnnotation>> get pageChalkAnnotations =>
      canvas.pageChalkAnnotations;

  String get tool => canvas.tool;
  set tool(String val) {
    if (canvas.tool != val || activeSubjectTool != null) {
      canvas.tool = val;
      pluginBridge.activeSubjectTool = null;
      notifyListeners();
    }
  }

  Color get ink => canvas.ink;
  set ink(Color val) => canvas.ink = val;
  double get strokeWidth => canvas.strokeWidth;
  set strokeWidth(double val) => canvas.strokeWidth = val;
  double get highlighterWidth => canvas.highlighterWidth;
  set highlighterWidth(double val) => canvas.highlighterWidth = val;
  double get eraserRadius => canvas.eraserRadius;
  set eraserRadius(double val) => canvas.eraserRadius = val;
  double get currentToolSize => canvas.currentToolSize;
  void setCurrentToolSize(double val) => canvas.setCurrentToolSize(val);
  Color? get customColor => canvas.customColor;
  set customColor(Color? val) => canvas.customColor = val;
  List<Color> get recentColors => canvas.recentColors;
  void setCustomColor(Color color) {
    canvas.setCustomColor(color);
    dirty = true;
    _revision++;
  }

  Offset? get laserOffset => canvas.laserOffset;
  set laserOffset(Offset? val) => canvas.laserOffset = val;

  /// Live laser pointer position. Listen to this instead of the whole
  /// [StudioState] to repaint only the laser layer on pointer moves.
  ValueListenable<Offset?> get laserOffsetListenable =>
      canvas.laserOffsetNotifier;
  void setLaserOffset(Offset? val) {
    canvas.laserOffset = val;
  }

  List<BoardStroke> get strokes => canvas.currentStrokes;
  void addStroke(BoardStroke stroke, {List<BoardStroke>? target}) {
    if (target != null) {
      target.add(stroke);
      coordinator.recordPdfAction(target);
      dirty = true;
      _revision++;
      notifyListeners();
    } else {
      canvas.addStroke(stroke);
      coordinator.recordBoardAction(stroke);
      dirty = true;
      _revision++;
    }
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
    final stroke = BoardStroke(ink, w, [
      point,
    ], isHighlighter: tool == 'highlight');
    list.add(stroke);
    if (target != null) {
      coordinator.recordPdfAction(list);
    } else {
      coordinator.recordBoardAction(stroke);
    }
    dirty = true;
    _revision++;
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
    if (list.isNotEmpty) {
      list.last.points.add(point);
      list.last.invalidatePath();
      dirty = true;
      _revision++;
      notifyListeners();
    }
  }

  void erase(Offset point, {List<BoardStroke>? target}) {
    canvas.erase(point, target: target);
    dirty = true;
    _revision++;
  }

  void undo() {
    final history = _pdfAnnotationUndo[_pdfAnnotationHistoryKey];
    if (history != null &&
        history.isNotEmpty &&
        history.last.sequence > coordinator.undoSequence) {
      final entry = history.removeLast();
      _applyPdfAnnotationHistory(entry, entry.before);
      _historySequence = pdf.smartPenManager.historySequence;
      entry.redoSequence = ++_historySequence;
      pdf.smartPenManager.historySequence = _historySequence;
      _pdfAnnotationRedo
          .putIfAbsent(_pdfAnnotationHistoryKey, () => [])
          .add(entry);
      _revision++;
      if (entry.persistedChanged) dirty = true;
      notifyListeners();
      return;
    }
    coordinator.undo();
  }

  void redo() {
    final history = _pdfAnnotationRedo[_pdfAnnotationHistoryKey];
    if (history != null &&
        history.isNotEmpty &&
        history.last.redoSequence > coordinator.redoSequence) {
      final entry = history.removeLast();
      _applyPdfAnnotationHistory(entry, entry.after);
      _historySequence = pdf.smartPenManager.historySequence;
      entry.sequence = ++_historySequence;
      pdf.smartPenManager.historySequence = _historySequence;
      _pdfAnnotationUndo
          .putIfAbsent(_pdfAnnotationHistoryKey, () => [])
          .add(entry);
      _revision++;
      if (entry.persistedChanged) dirty = true;
      notifyListeners();
      return;
    }
    coordinator.redo();
  }

  bool get canUndo =>
      (_pdfAnnotationUndo[_pdfAnnotationHistoryKey]?.isNotEmpty ?? false) ||
      coordinator.canUndo;
  bool get canRedo =>
      (_pdfAnnotationRedo[_pdfAnnotationHistoryKey]?.isNotEmpty ?? false) ||
      coordinator.canRedo;

  void nextPage() => canvas.nextPage();
  void prevPage() => canvas.prevPage();
  void setPage(int p) => canvas.setPage(p);

  // --- Sticker & Chalk Annotations ---
  List<BoardSticker> get currentStickers => canvas.currentStickers;
  void addSticker(BoardSticker sticker) => canvas.addSticker(sticker);
  void removeSticker(String id) => canvas.removeSticker(id);
  void updateStickerRect(String id, Rect newRect) =>
      canvas.updateStickerRect(id, newRect);

  String get currentPageNote => canvas.currentPageNote;

  bool showSpeakerNotes = false;

  void setSpeakerNotesOpen(bool open) {
    showSpeakerNotes = open;
    notifyListeners();
  }

  void toggleSpeakerNotes() {
    showSpeakerNotes = !showSpeakerNotes;
    notifyListeners();
  }

  List<SmartChalkAnnotation> get currentChalkAnnotations =>
      canvas.currentChalkAnnotations;
  void addChalkAnnotation(SmartChalkAnnotation annotation) =>
      canvas.addChalkAnnotation(annotation);
  void addSmartChalkAnnotation(SmartChalkAnnotation annotation) =>
      canvas.addSmartChalkAnnotation(annotation);
  void removeChalkAnnotation(String id) {
    if (canvas.removeChalkAnnotation(id) || pdf.removeChalkAnnotation(id)) {
      dirty = true;
      _revision++;
    }
  }

  void updateChalkAnnotationOffset(String id, Offset newOffset) {
    if (canvas.updateChalkAnnotationOffset(id, newOffset) ||
        pdf.updateChalkAnnotationOffset(id, newOffset)) {
      dirty = true;
      _revision++;
    }
  }

  void clearChalkAnnotationsForPage(int pageIndex) =>
      canvas.clearChalkAnnotationsForPage(pageIndex);
  void clearBoardChalkAnnotations() => canvas.clearBoardChalkAnnotations();
  String? get chalkDraftText => canvas.chalkDraftText;
  void setChalkDraftText(String? text) => canvas.setChalkDraftText(text);
  void clearChalkDraft() => canvas.clearChalkDraft();

  List<SmartChalkAnnotation> getPdfChalkAnnotations(int pageNumber) =>
      pdfChalkAnnotations.putIfAbsent(pageNumber, () => []);

  void addPdfChalkAnnotation(int pageNumber, SmartChalkAnnotation annotation) {
    getPdfChalkAnnotations(pageNumber).add(annotation);
    dirty = true;
    _revision++;
    notifyListeners();
  }

  void removePdfChalkAnnotation(int pageNumber, String id) {
    getPdfChalkAnnotations(pageNumber).removeWhere((a) => a.id == id);
    dirty = true;
    _revision++;
    notifyListeners();
  }

  bool analyzeHandwritingAt(Offset touchPoint, {String? hintText}) {
    final res = canvas.analyzeHandwritingAt(touchPoint, hintText: hintText);
    if (res) {
      dirty = true;
      _revision++;
    }
    return res;
  }

  Future<bool> analyzeHandwritingWithVerifiedText(
    Offset touchPoint,
    String verifiedText,
  ) async {
    final res = await canvas.analyzeHandwritingWithVerifiedText(
      touchPoint,
      verifiedText,
    );
    if (res) {
      dirty = true;
      _revision++;
    }
    return res;
  }

  bool analyzePdfSentenceAt(
    int pageNumber,
    Offset normPoint, {
    String? sampleText,
    Rect? targetRect,
  }) {
    final res = pdf.analyzePdfSentenceAt(
      pageNumber,
      normPoint,
      sampleText: sampleText,
      targetRect: targetRect,
    );
    if (res) {
      dirty = true;
      _revision++;
    }
    return res;
  }

  void addTypedChalkAnnotation(String sentence, {Offset? position}) {
    canvas.addTypedChalkAnnotation(sentence, position: position);
    dirty = true;
    _revision++;
  }

  // --- PDF & Smart Pen Properties ---
  int get pdfPage => pdf.pdfPage;
  set pdfPage(int page) => pdf.setPdfPage(page);

  int get pdfTotalPages => pdf.pdfTotalPages;
  set pdfTotalPages(int total) => pdf.setPdfTotalPages(total);

  String? get pdfFilePath => pdf.pdfFilePath;
  set pdfFilePath(String? path) => pdf.pdfFilePath = path;

  Uint8List? get pdfBytes => pdf.pdfBytes;
  set pdfBytes(Uint8List? bytes) => pdf.pdfBytes = bytes;

  Map<int, List<BoardStroke>> get pdfAnnotations => pdf.pdfAnnotations;
  Map<int, List<SmartChalkAnnotation>> get pdfChalkAnnotations =>
      pdf.pdfChalkAnnotations;

  List<BoardStroke> pdfAnnotationsForPage(int pageNumber) {
    final visible = List<BoardStroke>.of(pdf.pdfAnnotationsForPage(pageNumber));
    final overrides =
        _temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey]?[pageNumber];
    if (overrides == null || overrides.isEmpty) return visible;
    visible.removeWhere(
      (stroke) =>
          stroke.isGroupedPdfAnnotation &&
          overrides.containsKey(stroke.groupedAnnotationGroupId),
    );
    visible.addAll(overrides.values.whereType<BoardStroke>());
    return visible;
  }

  String get _pdfAnnotationHistoryKey =>
      activeDocId ?? pdfFilePath ?? 'current-pdf';

  List<BoardStroke> get currentPdfStrokes => pdf.currentPdfStrokes;

  void setPdfFile(String? path, [Uint8List? bytes]) {
    final replacedDocumentId = _pdfAnnotationHistoryKey;
    pdfContentGeneration++;
    clearTemporarySmartPenAnswers(documentId: replacedDocumentId);
    _clearPdfAnnotationHistory(documentId: replacedDocumentId);
    pdf.setPdfFile(path, bytes);
  }

  void closePdf() {
    final replacedDocumentId = _pdfAnnotationHistoryKey;
    pdfContentGeneration++;
    clearTemporarySmartPenAnswers(documentId: replacedDocumentId);
    _clearPdfAnnotationHistory(documentId: replacedDocumentId);
    pdf.closePdf();
  }

  void nextPdfPage() => pdf.nextPdfPage();
  void prevPdfPage() => pdf.prevPdfPage();
  void setPdfPage(int page) => pdf.setPdfPage(page);
  void setPdfTotalPages(int total) => pdf.setPdfTotalPages(total);
  void addPdfAnnotation(int page, BoardStroke stroke) =>
      pdf.addPdfAnnotation(page, stroke);
  void clearPdfAnnotationsForPage(int page) =>
      pdf.clearPdfAnnotationsForPage(page);

  bool get smartSnapEnabled => pdf.smartSnapEnabled;
  set smartSnapEnabled(bool val) => pdf.setSmartSnapEnabled(val);
  void setSmartSnapEnabled(bool enabled) => pdf.setSmartSnapEnabled(enabled);

  bool get saveAnswerCirclesEnabled => pdf.saveAnswerCirclesEnabled;
  set saveAnswerCirclesEnabled(bool val) =>
      pdf.setSaveAnswerCirclesEnabled(val);
  void setSaveAnswerCirclesEnabled(bool enabled) =>
      pdf.setSaveAnswerCirclesEnabled(enabled);

  static const String saveAnswerCirclesSettingKey = 'pdf_answer_circles.save';
  final Map<String, bool> _contributedToolSettings = {};
  bool contributedToolSetting(String key, {bool defaultValue = false}) {
    if (key == saveAnswerCirclesSettingKey) return saveAnswerCirclesEnabled;
    return _contributedToolSettings[key] ?? defaultValue;
  }

  void toggleContributedToolSetting(String key, {bool defaultValue = false}) {
    final next = !contributedToolSetting(key, defaultValue: defaultValue);
    if (key == saveAnswerCirclesSettingKey) {
      setSaveAnswerCirclesEnabled(next);
      return;
    }
    _contributedToolSettings[key] = next;
    notifyListeners();
  }

  SmartPenAnswerSelection? get smartPenAnswerSelection =>
      pdf.smartPenAnswerSelection;
  set smartPenAnswerSelection(SmartPenAnswerSelection? val) =>
      pdf.smartPenAnswerSelection = val;

  void toggleSmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) => pdf.toggleSmartPenAnswer(
    selection,
    pageSize,
    affectedPages: affectedPages,
  );

  void toggleTemporarySmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) {
    pdf.toggleTemporarySmartPenAnswer(
      selection,
      pageSize,
      affectedPages: affectedPages,
    );
    notifyListeners();
  }

  void clearTemporarySmartPenAnswers({String? documentId}) {
    pdf.clearTemporarySmartPenAnswers(documentId: documentId);
    if (documentId == null) {
      _temporaryPdfAnnotationOverrides.clear();
    } else {
      _temporaryPdfAnnotationOverrides.remove(documentId);
    }
  }

  void clearTemporarySmartPenAnswer(int pageNumber, String groupId) =>
      pdf.clearTemporarySmartPenAnswers();

  void clearAllSmartPenAnswersForPage(int pageNumber) =>
      pdf.clearAllSmartPenAnswersForPage(pageNumber);

  void migrateSmartPenAnswerGroup(
    String provisionalId,
    String canonicalId, {
    required List<int> affectedPages,
  }) {
    pdf.migrateSmartPenAnswerGroup(
      provisionalId,
      canonicalId,
      affectedPages: affectedPages,
    );
    notifyListeners();
  }

  // --- PDF Window & Split View ---
  Offset get pdfWindowPosition => pdf.pdfWindowPosition ?? const Offset(0, 0);
  set pdfWindowPosition(Offset pos) => pdf.pdfWindowPosition = pos;
  Size get pdfWindowSize => pdf.pdfWindowSize ?? const Size(540, 720);
  set pdfWindowSize(Size s) => pdf.pdfWindowSize = s;
  bool get pdfWindowMaximized => pdf.pdfWindowMaximized;
  set pdfWindowMaximized(bool val) => pdf.pdfWindowMaximized = val;
  bool get hasCustomPdfWindowPos => pdf.hasCustomPdfWindowPos;
  bool get hasCustomPdfWindowSize => pdf.hasCustomPdfWindowSize;
  void setPdfWindowPosition(Offset pos) => pdf.setPdfWindowPosition(pos);
  void setPdfWindowSize(Size s) => pdf.setPdfWindowSize(s);
  void togglePdfWindowMaximized() => pdf.togglePdfWindowMaximized();
  void resetPdfWindowSize() => pdf.resetPdfWindowSize();

  bool pdfOnRight = true;
  double splitRatio = 0.5;

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

  bool get pdfFitWidth => pdf.pdfFitWidth;
  bool get pdfFitPage => pdf.pdfFitPage;
  void togglePdfFit() => pdf.togglePdfFit();

  int get pdfZoomAction => pdf.pdfZoomAction;
  set pdfZoomAction(int val) => pdf.pdfZoomAction = val;
  void zoomInPdf() => pdf.zoomInPdf();
  void zoomOutPdf() => pdf.zoomOutPdf();

  dynamic pdfViewerController;
  GlobalKey? pdfViewerKey;
  bool isSpacePressed = false;
  void setSpacePressed(bool val) {
    if (isSpacePressed != val) {
      isSpacePressed = val;
      notifyListeners();
    }
  }

  void clearPdfPage() => pdf.clearPdfPage();
  void closeDocOnBoard() => setViewportMode(StudioViewportMode.fullBoard);
  void updatePdfBytesInPlace(Uint8List newBytes) {
    final replacedDocumentId = _pdfAnnotationHistoryKey;
    pdfContentGeneration++;
    clearTemporarySmartPenAnswers(documentId: replacedDocumentId);
    _clearPdfAnnotationHistory(documentId: replacedDocumentId);
    pdf.updatePdfBytesInPlace(newBytes);
  }

  Future<void> importPdfDialog() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result.isNotEmpty) {
        final f = result.first;
        final bytes = await f.readAsBytes();
        addImportedDoc(f.name, f.path, bytes);
      }
    } catch (_) {}
  }

  List<PdfDgnlPassage> get pdfDgnlPassages => pdf.pdfDgnlPassages;
  List<PdfDgnlPassage> getPdfDgnlPassagesForPage(int pageNumber) =>
      pdf.getPdfDgnlPassagesForPage(pageNumber);
  void addPdfDgnlPassage(PdfDgnlPassage passage) =>
      pdf.addPdfDgnlPassage(passage);
  void removePdfDgnlPassage(String id) => pdf.removePdfDgnlPassage(id);

  // --- Document Snapshots ---
  List<ImportedDocument> get importedDocs => pdf.importedDocs;
  String? get activeDocId => pdf.activeDocId;
  set activeDocId(String? id) => pdf.activeDocId = id;
  ImportedDocument? get activeDoc => pdf.activeDoc;

  void addImportedDoc(String name, String? path, Uint8List? bytes) {
    pdfContentGeneration++;
    pdf.addImportedDoc(name, path, bytes);
    dirty = true;
    _revision++;
  }

  void selectDoc(String id, {StudioViewportMode? targetMode}) {
    if (activeDocId != id && importedDocs.any((doc) => doc.id == id)) {
      pdfContentGeneration++;
    }
    pdf.selectDoc(id);
    if (targetMode != null) {
      setViewportMode(targetMode);
    } else if (viewportMode == StudioViewportMode.fullBoard) {
      setViewportMode(StudioViewportMode.split);
    }
    dirty = true;
    _revision++;
  }

  void removeDoc(String id) {
    clearTemporarySmartPenAnswers(documentId: id);
    _clearPdfAnnotationHistory(documentId: id);
    if (activeDocId == id) pdfContentGeneration++;
    pdf.removeDoc(id);
    if (importedDocs.isEmpty) {
      setViewportMode(StudioViewportMode.fullBoard);
    }
    dirty = true;
    _revision++;
  }

  // --- Plugin Host Properties ---
  GlassPreset glassPreset = GlassPreset.frosted;

  Future<void> highlightPdfPassageFromAnalysis(
    String rawText,
    List<Map<String, dynamic>> rawHighlights, {
    Map<String, dynamic> metrics = const {},
  }) async {
    notifyListeners();
  }

  // --- UI Accessories: PIP, Timer, Questions Drawer ---
  bool showCameraPip = false;
  bool pipMinimized = false;
  Offset pipPosition = const Offset(0.76, 0.04);
  double pipWidthFraction = 0.22;
  bool showQuestionsDrawer = false;
  int timerInitialSeconds = 300;
  int seconds = 300;
  Timer? _timer;
  bool get timerRunning => _timer != null;
  bool reveal = false;
  bool denoise = false;
  String savedAt = '';

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

  void toggleTimer() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (seconds > 0) {
          seconds--;
          notifyListeners();
        } else {
          t.cancel();
          _timer = null;
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  // --- Lifecycle, Save & Serialization ---
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
        coordinator.restoreFromJson(lesson);
        endpoint = config['endpoint'] as String? ?? '';
        audio.restore(config);
        language = audio.language == 'en' ? 'English' : 'Tiếng Việt';
        microphone = config['microphone'] as String? ?? '';
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

  Map<String, dynamic> exportLessonJson() => coordinator.exportLessonJson();
  void restoreFromJson(Map<String, dynamic> json) =>
      coordinator.restoreFromJson(json);

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
    error = null;
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
      return true;
    } catch (_) {
      error = 'Lưu bài thất bại';
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    coordinator.removeListener(_onCoordinatorChanged);
    coordinator.dispose();
    super.dispose();
  }
}
