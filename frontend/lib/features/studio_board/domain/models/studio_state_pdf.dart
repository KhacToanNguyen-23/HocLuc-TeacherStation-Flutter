// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

extension StudioStatePdfExt on StudioState {
  List<BoardStroke> pdfAnnotationsForPage(int pageNumber) {
    final persisted = pdfAnnotations[pageNumber] ?? const <BoardStroke>[];
    final overrides =
        _temporarySmartPenOverrides[_smartPenHistoryKey]?[pageNumber];
    if (overrides == null || overrides.isEmpty) return List.of(persisted);

    final visible = persisted.where((stroke) {
      final groupId = stroke.smartPenGroupId;
      return !stroke.isSmartPenOval ||
          groupId == null ||
          !overrides.containsKey(groupId);
    }).toList();
    visible.addAll(overrides.values.whereType<BoardStroke>());
    return visible;
  }

  List<BoardStroke> get currentPdfStrokes =>
      pdfAnnotations.putIfAbsent(pdfPage, () => []);

  void setPdfFile(String? path, [Uint8List? bytes]) {
    final replacedDocumentId = _smartPenHistoryKey;
    clearTemporarySmartPenAnswers(documentId: replacedDocumentId);

    // Keep the persisted annotations with their document before clearing the
    // active view. Session-only Smart Pen overrides are stored separately and
    // intentionally disappear when a PDF is closed or replaced.
    final currentDocument = activeDoc;
    if (currentDocument != null) {
      currentDocument.annotations
        ..clear()
        ..addAll(
          pdfAnnotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      currentDocument.totalPages = pdfTotalPages;
    }

    pdfFilePath = path;
    pdfBytes = bytes;
    pdfPage = 1;
    pdfTotalPages = 1;
    pdfAnnotations.clear();
    _clearSmartPenHistory(documentId: replacedDocumentId);
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
        final id = _newPageId();
        final doc = ImportedDocument(
          id: id,
          name: name,
          path: path,
          bytes: bytes,
          contentFingerprint: bytes == null
              ? null
              : _pdfContentFingerprint(bytes),
        );
        importedDocs.add(doc);
        activeDocId = id;
      } else {
        activeDocId = existing.id;
        final incomingFingerprint = bytes == null
            ? null
            : _pdfContentFingerprint(bytes);
        if (bytes != null &&
            ((existing.contentFingerprint != null &&
                    existing.contentFingerprint != incomingFingerprint) ||
                (existing.bytes != null &&
                    !_samePdfBytes(bytes, existing.bytes!)))) {
          // The same path can point to a replaced PDF. Do not carry its saved
          // annotations into the new file contents.
          existing.annotations.clear();
          existing.totalPages = 1;
        }
        existing.path = path ?? existing.path;
        existing.bytes = bytes ?? existing.bytes;
        existing.contentFingerprint = bytes == null
            ? existing.contentFingerprint
            : incomingFingerprint;
        pdfTotalPages = existing.totalPages > 0 ? existing.totalPages : 1;
        pdfAnnotations.addAll(
          existing.annotations.map(
            (page, strokes) => MapEntry(page, List.of(strokes)),
          ),
        );
      }
    } else {
      activeDocId = null;
    }
    dirty = true;
    _revision++;
    notifyListeners();
  }

  bool _samePdfBytes(Uint8List left, Uint8List right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  String _pdfContentFingerprint(Uint8List bytes) =>
      sha256.convert(bytes).toString();

  void updatePdfBytesInPlace(Uint8List newBytes) {
    final replacedDocumentId = _smartPenHistoryKey;
    clearTemporarySmartPenAnswers(documentId: replacedDocumentId);
    pdfBytes = newBytes;
    activeDoc?.bytes = newBytes;
    activeDoc?.contentFingerprint = _pdfContentFingerprint(newBytes);
    _clearSmartPenHistory(documentId: replacedDocumentId);
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

  bool get isSpacePressed => _isSpacePressed;
  void setSpacePressed(bool pressed) {
    if (_isSpacePressed != pressed) {
      _isSpacePressed = pressed;
      notifyListeners();
    }
  }

  void clearPdfPage() {
    pdfAnnotations[pdfPage]?.clear();
    final pageOverrides =
        _temporarySmartPenOverrides[_smartPenHistoryKey]?[pdfPage];
    pageOverrides?.clear();
    final documentOverrides = _temporarySmartPenOverrides[_smartPenHistoryKey];
    documentOverrides?.remove(pdfPage);
    if (documentOverrides?.isEmpty == true) {
      _temporarySmartPenOverrides.remove(_smartPenHistoryKey);
    }
    pdfChalkAnnotations[pdfPage]?.clear();
    _smartPenUndo[_smartPenHistoryKey]?.removeWhere(
      (entry) => entry.affectedPages.contains(pdfPage),
    );
    _smartPenRedo[_smartPenHistoryKey]?.removeWhere(
      (entry) => entry.affectedPages.contains(pdfPage),
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
}
