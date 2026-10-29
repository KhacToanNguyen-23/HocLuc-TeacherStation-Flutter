import 'dart:async';
import 'dart:collection';
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/smart_chalk_annotation.dart';
import '../../domain/models/smart_pen_answer_selection.dart';
import '../../domain/models/studio_board_models.dart';
import '../pdf_annotation_save_diagnostics.dart';
import '../pdf_annotation_storage_service.dart';
import 'smart_pen_answer_manager.dart';

part 'pdf_smart_pen_persistence.dart';

/// Single-responsibility controller managing PDF document state,
/// page navigation, per-page annotations, window geometry, and Smart Pen oval snapping.
class PdfSmartPenController extends ChangeNotifier {
  PdfSmartPenController({
    VoidCallback? onMarkDirty,
    PdfAnnotationStorageService Function()? storageServiceFactory,
  }) : _storageServiceFactory =
           storageServiceFactory ?? PdfAnnotationStorageService.new {
    smartPenManager = SmartPenAnswerManager(
      getPdfAnnotations: () => pdfAnnotations,
      getHistoryKey: () => _historyKey,
      onChanged: notifyListeners,
      onMarkDirty: onMarkDirty ?? () {},
    );
  }

  late final SmartPenAnswerManager smartPenManager;
  final PdfAnnotationStorageService Function() _storageServiceFactory;
  int _documentGeneration = 0;
  int _storageIdentityGeneration = -1;
  String? _storageIdentityPath;
  String? _storageIdentityAppDocumentId;
  Uint8List? _storageIdentityBytes;
  Future<String>? _storageIdentityFuture;
  final LinkedHashMap<String, _PendingPdfAnnotationSave> _pendingSaves =
      LinkedHashMap<String, _PendingPdfAnnotationSave>();
  Future<void>? _persistenceDrain;
  bool isPersistingAnnotations = false;
  String? annotationPersistenceError;
  bool _isDisposed = false;
  int _contentFingerprintComputations = 0;

  @visibleForTesting
  int get contentFingerprintComputations => _contentFingerprintComputations;

  PdfAnnotationStorageService _newStorageService() => _storageServiceFactory();

  VoidCallback? get onMarkDirty => smartPenManager.onMarkDirty;
  set onMarkDirty(VoidCallback? cb) => smartPenManager.onMarkDirty = cb;

  final List<ImportedDocument> importedDocs = [];
  String? activeDocId;
  String? pdfFilePath;
  Uint8List? pdfBytes;

  int _pdfPage = 1;
  int get pdfPage => _pdfPage;

  int _pdfTotalPages = 1;
  int get pdfTotalPages => _pdfTotalPages;

  final Map<int, List<BoardStroke>> pdfAnnotations = {};
  final Map<int, List<SmartChalkAnnotation>> pdfChalkAnnotations = {};

  List<SmartChalkAnnotation> getPdfChalkAnnotations(int pageNumber) =>
      pdfChalkAnnotations.putIfAbsent(pageNumber, () => []);

  void addPdfChalkAnnotation(int pageNumber, SmartChalkAnnotation annotation) {
    getPdfChalkAnnotations(pageNumber).add(annotation);
    notifyListeners();
  }

  bool removeChalkAnnotation(String id) {
    for (final list in pdfChalkAnnotations.values) {
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
    for (final list in pdfChalkAnnotations.values) {
      final idx = list.indexWhere((s) => s.id == id);
      if (idx != -1) {
        list[idx].normalizedOffset = newOffset;
        notifyListeners();
        return true;
      }
    }
    return false;
  }

  /// Callback provided by Coordinator to check if an active plugin has activated a pdf tap mode tool.
  bool Function()? isPluginSmartSnapActive;

  bool get smartSnapEnabled =>
      smartPenManager.smartSnapEnabled ||
      (isPluginSmartSnapActive?.call() ?? false);
  set smartSnapEnabled(bool val) {
    smartPenManager.smartSnapEnabled = val;
    notifyListeners();
  }

  void setSmartSnapEnabled(bool enabled) => smartSnapEnabled = enabled;

  bool get saveAnswerCirclesEnabled => smartPenManager.saveAnswerCirclesEnabled;
  set saveAnswerCirclesEnabled(bool val) {
    smartPenManager.saveAnswerCirclesEnabled = val;
    notifyListeners();
  }

  void setSaveAnswerCirclesEnabled(bool enabled) =>
      saveAnswerCirclesEnabled = enabled;

  SmartPenAnswerSelection? get smartPenAnswerSelection =>
      smartPenManager.smartPenAnswerSelection;
  set smartPenAnswerSelection(SmartPenAnswerSelection? val) {
    smartPenManager.smartPenAnswerSelection = val;
    notifyListeners();
  }

  void dispatchSmartPenAnswer(SmartPenAnswerSelection selection) {
    smartPenAnswerSelection = selection;
  }

  bool pdfWindowMaximized = false;
  Offset? pdfWindowPosition;
  Size? pdfWindowSize;
  bool hasCustomPdfWindowPos = false;
  bool hasCustomPdfWindowSize = false;

  ImportedDocument? get activeDoc {
    if (activeDocId == null) return null;
    try {
      return importedDocs.firstWhere((d) => d.id == activeDocId);
    } catch (_) {
      return null;
    }
  }

  String get _historyKey => activeDocId ?? pdfFilePath ?? 'current-pdf';
  String get historyKey => _historyKey;

  void setPdfTotalPages(int total) {
    _pdfTotalPages = total < 1 ? 1 : total;
    notifyListeners();
  }

  void setPdfPage(int page) {
    final next = page.clamp(1, _pdfTotalPages);
    if (_pdfPage != next) {
      _pdfPage = next;
      notifyListeners();
    }
  }

  void nextPdfPage() {
    if (_pdfPage < _pdfTotalPages) {
      _pdfPage++;
      notifyListeners();
    }
  }

  void prevPdfPage() {
    if (_pdfPage > 1) {
      _pdfPage--;
      notifyListeners();
    }
  }

  List<BoardStroke> get currentPdfStrokes =>
      pdfAnnotations.putIfAbsent(_pdfPage, () => []);

  bool pdfHighlightsVisible = true;
  final List<_PdfAnnotationHistoryItem> _annotationUndoStack = [];
  final List<_PdfAnnotationHistoryItem> _annotationRedoStack = [];

  bool get canUndoAnnotation => _annotationUndoStack.isNotEmpty;
  bool get canRedoAnnotation => _annotationRedoStack.isNotEmpty;
  int get annotationUndoSequence =>
      _annotationUndoStack.isEmpty ? -1 : _annotationUndoStack.last.sequence;
  int get annotationRedoSequence => _annotationRedoStack.isEmpty
      ? -1
      : _annotationRedoStack.last.redoSequence;

  void clearAnnotationRedo() => _annotationRedoStack.clear();

  void _pushAnnotationUndo(_PdfAnnotationHistoryItem item) {
    item.sequence = ++smartPenManager.historySequence;
    _annotationUndoStack.add(item);
    _annotationRedoStack.clear();
  }

  void setPdfHighlightsVisible(bool val) {
    if (pdfHighlightsVisible != val) {
      pdfHighlightsVisible = val;
      savePersistentAnnotations();
      notifyListeners();
    }
  }

  Future<bool> flushPendingAnnotationPersistence() async {
    final drain = _persistenceDrain;
    if (drain != null) await drain;
    return annotationPersistenceError == null;
  }

  Future<bool> retryAnnotationPersistence() => savePersistentAnnotations();

  void _notifyPersistenceListeners() => notifyListeners();

  void togglePdfHighlightsVisible() {
    pdfHighlightsVisible = !pdfHighlightsVisible;
    savePersistentAnnotations();
    notifyListeners();
  }

  void clearPdfHighlights({int? pageNumber}) {
    if (pageNumber != null) {
      final strokes = pdfAnnotations[pageNumber];
      if (strokes != null && strokes.isNotEmpty) {
        final removed = strokes.where((s) => s.category != null).toList();
        if (removed.isNotEmpty) {
          strokes.removeWhere((s) => s.category != null);
          _pushAnnotationUndo(
            _PdfAnnotationHistoryItem(
              pageNumber: pageNumber,
              clearedStrokes: removed,
              isClear: true,
            ),
          );
          _annotationRedoStack.clear();
          savePersistentAnnotations();
          notifyListeners();
        }
      }
    } else {
      var anyRemoved = false;
      for (final entry in pdfAnnotations.entries) {
        final removed = entry.value.where((s) => s.category != null).toList();
        if (removed.isNotEmpty) {
          entry.value.removeWhere((s) => s.category != null);
          _pushAnnotationUndo(
            _PdfAnnotationHistoryItem(
              pageNumber: entry.key,
              clearedStrokes: removed,
              isClear: true,
            ),
          );
          anyRemoved = true;
        }
      }
      if (anyRemoved) {
        savePersistentAnnotations();
        notifyListeners();
      }
    }
  }

  void recordAnnotationAdded(int page, BoardStroke stroke) {
    unawaited(
      recordAnnotationsAdded({
        page: [stroke],
      }),
    );
  }

  /// Commits an annotation batch as one undoable action and one persistence
  /// request. Existing geometry and stroke objects are preserved as supplied.
  Future<bool> recordAnnotationsAdded(
    Map<int, List<BoardStroke>> additions, {
    String? operationId,
  }) {
    final saveOperationId =
        operationId ?? PdfAnnotationSaveDiagnostics.newOperationId('batch');
    final commitTimer = Stopwatch()..start();
    final accepted = <int, List<BoardStroke>>{};
    for (final entry in additions.entries) {
      if (entry.key < 1 || entry.value.isEmpty) continue;

      final current = pdfAnnotations[entry.key] ?? const <BoardStroke>[];
      final ids = <String>{
        for (final stroke in current)
          if (stroke.id != null) stroke.id!,
      };
      final rects = <Rect>{
        for (final stroke in current)
          if (stroke.rect != null) stroke.rect!,
      };
      final identitySet = HashSet<BoardStroke>.identity()..addAll(current);
      final pageAdditions = <BoardStroke>[];

      for (final stroke in entry.value) {
        if (stroke.id != null && !ids.add(stroke.id!)) continue;
        if (stroke.rect != null && !rects.add(stroke.rect!)) continue;
        if (!identitySet.add(stroke)) continue;
        pageAdditions.add(stroke);
      }
      if (pageAdditions.isNotEmpty) accepted[entry.key] = pageAdditions;
    }

    if (accepted.isEmpty) return Future<bool>.value(true);

    for (final entry in accepted.entries) {
      pdfAnnotations.putIfAbsent(entry.key, () => []).addAll(entry.value);
    }
    final historyTimer = Stopwatch()..start();
    _pushAnnotationUndo(
      _PdfAnnotationHistoryItem(
        pageNumber: accepted.keys.first,
        addedAnnotations: accepted,
      ),
    );
    PdfAnnotationSaveDiagnostics.log(
      saveOperationId,
      'undo_history_update',
      duration: historyTimer.elapsed,
      fields: {'undoEntries': 1, 'pages': accepted.length},
    );

    // This single notification also publishes the pending-save state.
    PdfAnnotationSaveDiagnostics.log(
      saveOperationId,
      'annotation_commit',
      duration: commitTimer.elapsed,
      fields: {
        'annotations': accepted.values.fold<int>(
          0,
          (total, strokes) => total + strokes.length,
        ),
        'pages': accepted.length,
      },
    );
    final persistence = _queueAnnotationPersistence(
      notifyOnStart: false,
      operationId: saveOperationId,
    );
    notifyListeners();
    return persistence;
  }

  void recordAnnotationRemoved(int page, BoardStroke stroke, int index) {
    _pushAnnotationUndo(
      _PdfAnnotationHistoryItem(
        pageNumber: page,
        stroke: stroke,
        index: index,
        isDeletion: true,
      ),
    );
    savePersistentAnnotations();
  }

  bool undoAnnotation() {
    if (_annotationUndoStack.isEmpty) return false;
    final entry = _annotationUndoStack.removeLast();
    if (entry.addedAnnotations != null) {
      for (final page in entry.addedAnnotations!.entries) {
        final list = pdfAnnotations[page.key];
        list?.removeWhere(page.value.contains);
      }
    } else if (entry.isClear && entry.clearedStrokes != null) {
      final list = pdfAnnotations.putIfAbsent(entry.pageNumber, () => []);
      list.addAll(entry.clearedStrokes!);
    } else if (entry.isDeletion && entry.stroke != null) {
      final list = pdfAnnotations.putIfAbsent(entry.pageNumber, () => []);
      final idx = entry.index != null && entry.index! <= list.length
          ? entry.index!
          : list.length;
      list.insert(idx, entry.stroke!);
    } else if (!entry.isDeletion && entry.stroke != null) {
      final list = pdfAnnotations[entry.pageNumber];
      list?.remove(entry.stroke);
    }
    entry.redoSequence = ++smartPenManager.historySequence;
    _annotationRedoStack.add(entry);
    savePersistentAnnotations();
    notifyListeners();
    return true;
  }

  bool redoAnnotation() {
    if (_annotationRedoStack.isEmpty) return false;
    final entry = _annotationRedoStack.removeLast();
    if (entry.addedAnnotations != null) {
      for (final page in entry.addedAnnotations!.entries) {
        pdfAnnotations.putIfAbsent(page.key, () => []).addAll(page.value);
      }
    } else if (entry.isClear && entry.clearedStrokes != null) {
      final list = pdfAnnotations[entry.pageNumber];
      list?.removeWhere((s) => entry.clearedStrokes!.contains(s));
    } else if (entry.isDeletion && entry.stroke != null) {
      final list = pdfAnnotations[entry.pageNumber];
      list?.remove(entry.stroke);
    } else if (!entry.isDeletion && entry.stroke != null) {
      final list = pdfAnnotations.putIfAbsent(entry.pageNumber, () => []);
      list.add(entry.stroke!);
    }
    entry.sequence = ++smartPenManager.historySequence;
    _annotationUndoStack.add(entry);
    savePersistentAnnotations();
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> restorePersistentAnnotations() async {
    if (pdfFilePath == null && pdfBytes == null) return;
    final generation = _documentGeneration;
    final documentId = activeDocId;
    final filePath = pdfFilePath;
    final bytes = pdfBytes;
    final operationId = PdfAnnotationSaveDiagnostics.newOperationId('restore');
    try {
      final storage = _newStorageService();
      final storageDocumentId = await _storageDocumentIdForCurrentPdf(
        operationId,
      );
      final layer = await storage.loadAnnotations(
        filePath: filePath,
        bytes: bytes,
        documentId: storageDocumentId,
      );
      if (generation != _documentGeneration ||
          documentId != activeDocId ||
          filePath != pdfFilePath ||
          !identical(bytes, pdfBytes)) {
        return;
      }
      if (layer != null && layer.annotations.isNotEmpty) {
        for (final entry in layer.annotations.entries) {
          final targetList = pdfAnnotations.putIfAbsent(entry.key, () => []);
          for (final stroke in entry.value) {
            final exists = targetList.any(
              (s) =>
                  (s.id != null && s.id == stroke.id) ||
                  (s.rect != null && s.rect == stroke.rect),
            );
            if (!exists) {
              targetList.add(stroke);
            }
          }
          activeDoc?.annotations[entry.key] = List.of(targetList);
        }
        pdfHighlightsVisible = layer.highlightsVisible;
        notifyListeners();
      }
    } catch (_) {}
  }

  List<BoardStroke> pdfAnnotationsForPage(int pageNumber) {
    final persisted = pdfAnnotations[pageNumber] ?? const <BoardStroke>[];
    final base = smartPenManager.filterVisibleAnnotations(
      pageNumber,
      persisted,
    );
    if (!pdfHighlightsVisible) {
      return base.where((s) => s.category == null).toList();
    }
    return base;
  }

  void addPdfAnnotation(int page, BoardStroke stroke) {
    final list = pdfAnnotations.putIfAbsent(page, () => []);
    list.add(stroke);
    notifyListeners();
  }

  void clearPdfAnnotationsForPage(int page) {
    pdfAnnotations[page]?.clear();
    pdfChalkAnnotations[page]?.clear();
    smartPenManager.clearTemporaryAnswers(documentId: _historyKey);
    notifyListeners();
  }

  String _pdfContentFingerprint(Uint8List bytes) {
    _contentFingerprintComputations++;
    return sha256.convert(bytes).toString();
  }

  bool _samePdfBytes(Uint8List left, Uint8List right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void setPdfFile(String? path, [Uint8List? bytes]) {
    _freezePendingAnnotationSaves();
    _documentGeneration++;
    annotationPersistenceError = null;
    final replacedDocumentId = _historyKey;
    smartPenManager.clearTemporaryAnswers(documentId: replacedDocumentId);

    final currentDocument = activeDoc;
    if (currentDocument != null) {
      currentDocument.annotations
        ..clear()
        ..addAll(
          pdfAnnotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      currentDocument.totalPages = _pdfTotalPages;
    }

    pdfFilePath = path;
    pdfBytes = bytes;
    _pdfPage = 1;
    _pdfTotalPages = 1;
    pdfAnnotations.clear();
    smartPenManager.clearHistory(documentId: replacedDocumentId);
    smartPenAnswerSelection = null;

    if (path != null || bytes != null) {
      final incomingFingerprint = bytes == null
          ? null
          : _pdfContentFingerprint(bytes);
      final name = path != null
          ? path.split(RegExp(r'[\\/]')).last
          : 'Tài liệu.pdf';
      final exactPathMatch = path == null
          ? null
          : importedDocs.where((doc) => doc.path == path).firstOrNull;
      final nameMatch = importedDocs
          .where(
            (doc) =>
                doc.name == name &&
                bytes != null &&
                doc.contentFingerprint == incomingFingerprint,
          )
          .firstOrNull;
      final existing = exactPathMatch ?? nameMatch;
      if (existing == null) {
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final doc = ImportedDocument(
          id: id,
          name: name,
          path: path,
          bytes: bytes,
          contentFingerprint: incomingFingerprint,
        );
        importedDocs.add(doc);
        activeDocId = id;
      } else {
        activeDocId = existing.id;
        if (bytes != null &&
            ((existing.contentFingerprint != null &&
                    existing.contentFingerprint != incomingFingerprint) ||
                (existing.bytes != null &&
                    !_samePdfBytes(bytes, existing.bytes!)))) {
          existing.annotations.clear();
          existing.totalPages = 1;
        }
        existing.path = path ?? existing.path;
        existing.bytes = bytes ?? existing.bytes;
        existing.contentFingerprint = bytes == null
            ? existing.contentFingerprint
            : incomingFingerprint;
        pdfAnnotations.addAll(existing.annotations);
        _pdfTotalPages = existing.totalPages > 0 ? existing.totalPages : 1;
      }
    } else {
      activeDocId = null;
    }
    restorePersistentAnnotations();
    notifyListeners();
  }

  void addImportedDoc(String name, String? path, Uint8List? bytes) {
    final incomingFingerprint = bytes == null
        ? null
        : _pdfContentFingerprint(bytes);
    final exactPathMatch = path == null
        ? null
        : importedDocs.where((doc) => doc.path == path).firstOrNull;
    final nameMatch = importedDocs
        .where(
          (doc) =>
              doc.name == name &&
              incomingFingerprint != null &&
              doc.contentFingerprint == incomingFingerprint,
        )
        .firstOrNull;
    final existing = exactPathMatch ?? nameMatch;
    if (existing != null) {
      var contentChanged = false;
      if (bytes != null &&
          ((existing.contentFingerprint != null &&
                  existing.contentFingerprint != incomingFingerprint) ||
              (existing.bytes != null &&
                  !_samePdfBytes(bytes, existing.bytes!)))) {
        existing.annotations.clear();
        existing.totalPages = 1;
        contentChanged = true;
      }
      existing.path = path ?? existing.path;
      existing.bytes = bytes ?? existing.bytes;
      existing.contentFingerprint =
          incomingFingerprint ?? existing.contentFingerprint;
      if (existing.id == activeDocId) {
        if (contentChanged) {
          _freezePendingAnnotationSaves();
          _documentGeneration++;
          annotationPersistenceError = null;
          smartPenManager.clearTemporaryAnswers(documentId: existing.id);
          smartPenManager.clearHistory(documentId: existing.id);
          smartPenAnswerSelection = null;
          pdfAnnotations.clear();
          _pdfPage = 1;
          _pdfTotalPages = 1;
        } else {
          existing.annotations
            ..clear()
            ..addAll(
              pdfAnnotations.map(
                (page, strokes) => MapEntry(page, List.of(strokes)),
              ),
            );
          existing.totalPages = _pdfTotalPages;
        }
        pdfFilePath = existing.path;
        pdfBytes = existing.bytes;
        notifyListeners();
        return;
      }
      selectDoc(existing.id);
      return;
    }
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final doc = ImportedDocument(
      id: id,
      name: name,
      path: path,
      bytes: bytes,
      contentFingerprint: incomingFingerprint,
    );
    importedDocs.add(doc);
    selectDoc(id);
  }

  void selectDoc(String id) {
    final doc = importedDocs.where((d) => d.id == id).firstOrNull;
    if (doc == null) return;

    if (activeDocId != id) _freezePendingAnnotationSaves();
    if (activeDoc != null && activeDoc!.id != id) {
      activeDoc!.annotations.clear();
      activeDoc!.annotations.addAll(pdfAnnotations);
      activeDoc!.totalPages = _pdfTotalPages;
    }

    _documentGeneration++;
    activeDocId = id;
    pdfFilePath = doc.path;
    pdfBytes = doc.bytes;
    _pdfPage = 1;
    _pdfTotalPages = doc.totalPages > 0 ? doc.totalPages : 1;
    pdfAnnotations.clear();
    pdfAnnotations.addAll(doc.annotations);
    notifyListeners();
  }

  void removeDoc(String id) {
    final index = importedDocs.indexWhere((d) => d.id == id);
    if (index == -1) return;
    smartPenManager.clearTemporaryAnswers(documentId: id);
    smartPenManager.clearHistory(documentId: id);
    importedDocs.removeAt(index);
    if (activeDocId == id) {
      if (importedDocs.isNotEmpty) {
        selectDoc(importedDocs.last.id);
      } else {
        activeDocId = null;
        setPdfFile(null, null);
      }
    }
    notifyListeners();
  }

  void closePdf() {
    _freezePendingAnnotationSaves();
    _documentGeneration++;
    annotationPersistenceError = null;
    pdfFilePath = null;
    pdfBytes = null;
    activeDocId = null;
    _pdfPage = 1;
    _pdfTotalPages = 1;
    pdfAnnotations.clear();
    pdfChalkAnnotations.clear();
    smartPenManager.clearTemporaryAnswers();
    notifyListeners();
  }

  void updatePdfBytesInPlace(Uint8List newBytes) {
    _freezePendingAnnotationSaves();
    _documentGeneration++;
    annotationPersistenceError = null;
    final replacedDocumentId = _historyKey;
    smartPenManager.clearTemporaryAnswers(documentId: replacedDocumentId);
    pdfBytes = newBytes;
    activeDoc?.bytes = newBytes;
    activeDoc?.contentFingerprint = _pdfContentFingerprint(newBytes);
    smartPenManager.clearHistory(documentId: replacedDocumentId);
    notifyListeners();
  }

  void setPdfWindowPosition(Offset position) {
    pdfWindowPosition = position;
    hasCustomPdfWindowPos = true;
    notifyListeners();
  }

  void setPdfWindowSize(Size size) {
    pdfWindowSize = size;
    hasCustomPdfWindowSize = true;
    notifyListeners();
  }

  void togglePdfWindowMaximized() {
    pdfWindowMaximized = !pdfWindowMaximized;
    notifyListeners();
  }

  void resetPdfWindowSize() {
    pdfWindowSize = null;
    pdfWindowPosition = null;
    pdfWindowMaximized = false;
    hasCustomPdfWindowPos = false;
    hasCustomPdfWindowSize = false;
    notifyListeners();
  }

  void toggleSmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) {
    smartPenManager.toggleSmartPenAnswer(
      selection,
      pageSize,
      affectedPages: affectedPages,
    );
  }

  void toggleTemporarySmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) {
    smartPenManager.toggleTemporarySmartPenAnswer(
      selection,
      pageSize,
      affectedPages: affectedPages,
    );
  }

  void clearTemporarySmartPenAnswer(int pageNumber, String groupId) {
    smartPenManager.clearTemporaryAnswer(pageNumber, groupId);
  }

  void clearTemporarySmartPenAnswers({String? documentId}) {
    smartPenManager.clearTemporaryAnswers(documentId: documentId);
  }

  void clearAllSmartPenAnswersForPage(int pageNumber) {
    pdfAnnotations[pageNumber]?.removeWhere((s) => s.isSmartPenOval);
    smartPenManager.clearTemporaryAnswers(documentId: _historyKey);
    notifyListeners();
  }

  void migrateSmartPenAnswerGroup(
    String provisionalId,
    String canonicalId, {
    required List<int> affectedPages,
  }) {
    smartPenManager.migrateSmartPenAnswerGroup(
      provisionalId,
      canonicalId,
      affectedPages: affectedPages,
    );
  }

  void clearSmartPenHistory({String? documentId}) {
    smartPenManager.clearHistory(documentId: documentId);
  }

  int pdfZoomAction = 0;
  void zoomInPdf() {
    pdfZoomAction++;
    notifyListeners();
  }

  void zoomOutPdf() {
    pdfZoomAction--;
    notifyListeners();
  }

  bool _pdfFitWidth = true;
  bool get pdfFitWidth => _pdfFitWidth;
  bool get pdfFitPage => !_pdfFitWidth;
  void togglePdfFit() {
    _pdfFitWidth = !_pdfFitWidth;
    notifyListeners();
  }

  void setPdfFitWidth(bool fitWidth) {
    if (_pdfFitWidth != fitWidth) {
      _pdfFitWidth = fitWidth;
      notifyListeners();
    }
  }

  void setPdfFitPage(bool fit) => setPdfFitWidth(!fit);

  void clearPdfPage([int? page]) {
    final p = page ?? _pdfPage;
    pdfAnnotations[p]?.clear();
    pdfChalkAnnotations[p]?.clear();
    smartPenManager.clearTemporaryAnswers(documentId: _historyKey);
    smartPenManager.smartPenUndo[_historyKey]?.removeWhere(
      (entry) => entry.affectedPages.contains(p),
    );
    smartPenManager.smartPenRedo[_historyKey]?.removeWhere(
      (entry) => entry.affectedPages.contains(p),
    );
    notifyListeners();
  }

  bool? _pdfModeOverride;
  bool? get pdfModeOverride => _pdfModeOverride;
  set pdfModeOverride(bool? val) {
    if (_pdfModeOverride != val) {
      _pdfModeOverride = val;
      notifyListeners();
    }
  }

  final List<PdfDgnlPassage> pdfDgnlPassages = [];
  List<PdfDgnlPassage> getPdfDgnlPassagesForPage(int pageNumber) =>
      pdfDgnlPassages.where((p) => p.pageNumber == pageNumber).toList();
  void addPdfDgnlPassage(PdfDgnlPassage passage) {
    pdfDgnlPassages.add(passage);
    notifyListeners();
  }

  void removePdfDgnlPassage(String id) {
    pdfDgnlPassages.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  PedagogicalHighlightPolicy pedagogicalPolicy =
      const PedagogicalHighlightPolicy();
  void setPedagogicalPolicy(PedagogicalHighlightPolicy policy) {
    if (pedagogicalPolicy != policy) {
      pedagogicalPolicy = policy;
      notifyListeners();
    }
  }
}

class _PdfAnnotationHistoryItem {
  _PdfAnnotationHistoryItem({
    required this.pageNumber,
    this.stroke,
    this.addedAnnotations,
    this.index,
    this.isDeletion = false,
    this.isClear = false,
    this.clearedStrokes,
  });

  final int pageNumber;
  final BoardStroke? stroke;
  final Map<int, List<BoardStroke>>? addedAnnotations;
  final int? index;
  final bool isDeletion;
  final bool isClear;
  final List<BoardStroke>? clearedStrokes;
  int sequence = 0;
  int redoSequence = 0;
}
