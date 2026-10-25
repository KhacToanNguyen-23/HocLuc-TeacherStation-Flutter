import 'dart:math' as math;
import 'dart:ui';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/smart_chalk_annotation.dart';
import '../../domain/models/smart_pen_answer_selection.dart';
import '../../domain/models/studio_board_models.dart';
import '../english_analyzer.dart';
import 'smart_pen_answer_manager.dart';

/// Single-responsibility controller managing PDF document state,
/// page navigation, per-page annotations, window geometry, and Smart Pen oval snapping.
class PdfSmartPenController extends ChangeNotifier {
  PdfSmartPenController({VoidCallback? onMarkDirty}) {
    smartPenManager = SmartPenAnswerManager(
      getPdfAnnotations: () => pdfAnnotations,
      getHistoryKey: () => _historyKey,
      onChanged: notifyListeners,
      onMarkDirty: onMarkDirty ?? () {},
    );
  }

  late final SmartPenAnswerManager smartPenManager;

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
  void setSaveAnswerCirclesEnabled(bool enabled) => saveAnswerCirclesEnabled = enabled;

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

  List<BoardStroke> pdfAnnotationsForPage(int pageNumber) {
    final persisted = pdfAnnotations[pageNumber] ?? const <BoardStroke>[];
    return smartPenManager.filterVisibleAnnotations(pageNumber, persisted);
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

  String _pdfContentFingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

  bool _samePdfBytes(Uint8List left, Uint8List right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  void setPdfFile(String? path, [Uint8List? bytes]) {
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
                doc.contentFingerprint == _pdfContentFingerprint(bytes),
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
          contentFingerprint:
              bytes == null ? null : _pdfContentFingerprint(bytes),
        );
        importedDocs.add(doc);
        activeDocId = id;
      } else {
        activeDocId = existing.id;
        final incomingFingerprint =
            bytes == null ? null : _pdfContentFingerprint(bytes);
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
    notifyListeners();
  }

  void addImportedDoc(String name, String? path, Uint8List? bytes) {
    final incomingFingerprint =
        bytes == null ? null : _pdfContentFingerprint(bytes);
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

    if (activeDoc != null && activeDoc!.id != id) {
      activeDoc!.annotations.clear();
      activeDoc!.annotations.addAll(pdfAnnotations);
      activeDoc!.totalPages = _pdfTotalPages;
    }

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
}
