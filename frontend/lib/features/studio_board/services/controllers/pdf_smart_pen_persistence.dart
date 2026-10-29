part of 'pdf_smart_pen_controller.dart';

extension PdfSmartPenPersistence on PdfSmartPenController {
  Future<bool> savePersistentAnnotations() =>
      _queueAnnotationPersistence(notifyOnStart: true);

  Future<bool> _queueAnnotationPersistence({
    required bool notifyOnStart,
    String? operationId,
  }) {
    final saveOperationId =
        operationId ?? PdfAnnotationSaveDiagnostics.newOperationId();
    final requestTimer = Stopwatch()..start();
    final generation = _documentGeneration;
    final filePath = pdfFilePath;
    final bytes = pdfBytes;
    final appDocumentId = activeDocId;
    final storageDocumentId = _storageDocumentIdForCurrentPdf(saveOperationId);
    final key =
        '$generation|$appDocumentId|$filePath|${identityHashCode(bytes)}';
    final completer = Completer<bool>();
    final waiter = _PdfSaveWaiter(
      operationId: saveOperationId,
      completer: completer,
      queueTimer: Stopwatch()..start(),
      requestTimer: requestTimer,
    );
    final pending = _pendingSaves[key];
    if (pending == null) {
      _pendingSaves[key] = _PendingPdfAnnotationSave(
        operationId: saveOperationId,
        documentId: storageDocumentId,
        generation: generation,
        filePath: filePath,
        pdfBytesLength: bytes?.length,
        annotations: null,
        highlightsVisible: pdfHighlightsVisible,
        waiters: [waiter],
      );
    } else {
      pending
        ..highlightsVisible = pdfHighlightsVisible
        ..waiters.add(waiter);
      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'save_coalesced',
        fields: {
          'intoOperationId': pending.operationId,
          'queuedRequests': pending.waiters.length,
        },
      );
    }
    PdfAnnotationSaveDiagnostics.log(
      saveOperationId,
      'persistence_queued',
      fields: {
        'cacheKeyGeneration': generation,
        'pdfBytes': bytes?.length ?? 'unknown',
        'coalesced': pending != null,
      },
    );

    if (!isPersistingAnnotations) {
      isPersistingAnnotations = true;
      if (notifyOnStart) _notifyPersistenceListeners();
    }
    _schedulePersistenceDrain();
    return completer.future.then((succeeded) {
      PdfAnnotationSaveDiagnostics.log(
        saveOperationId,
        'persistence_request_total',
        duration: requestTimer.elapsed,
        fields: {'status': succeeded ? 'success' : 'error'},
      );
      return succeeded;
    });
  }

  /// Freezes pending state before a synchronous document transition.
  void prepareForDocumentReplacement() => _freezePendingAnnotationSaves();

  void _freezePendingAnnotationSaves() {
    if (!_pendingSaves.values.any(
      (pending) =>
          pending.generation == _documentGeneration &&
          pending.annotations == null,
    )) {
      return;
    }
    final snapshot = _snapshotAnnotations();
    for (final pending in _pendingSaves.values) {
      if (pending.generation == _documentGeneration &&
          pending.annotations == null) {
        pending.annotations = snapshot;
      }
    }
  }

  Map<int, List<BoardStroke>> _snapshotAnnotations() => {
    for (final entry in pdfAnnotations.entries)
      if (entry.value.isNotEmpty) entry.key: List<BoardStroke>.of(entry.value),
  };

  Future<String> _storageDocumentIdForCurrentPdf(String operationId) {
    final generation = _documentGeneration;
    final path = pdfFilePath;
    final bytes = pdfBytes;
    final appDocumentId = activeDocId;
    final lookupTimer = Stopwatch()..start();
    if (_storageIdentityFuture != null &&
        _storageIdentityGeneration == generation &&
        _storageIdentityPath == path &&
        _storageIdentityAppDocumentId == appDocumentId &&
        identical(_storageIdentityBytes, bytes)) {
      PdfAnnotationSaveDiagnostics.log(
        operationId,
        'document_identity_lookup',
        duration: lookupTimer.elapsed,
        fields: {'cache': 'hit', 'pdfBytes': bytes?.length ?? 'unknown'},
      );
      return _storageIdentityFuture!;
    }

    final storage = _newStorageService();
    final knownFingerprint = bytes != null && identical(activeDoc?.bytes, bytes)
        ? activeDoc?.contentFingerprint
        : null;
    _storageIdentityGeneration = generation;
    _storageIdentityPath = path;
    _storageIdentityAppDocumentId = appDocumentId;
    _storageIdentityBytes = bytes;
    _storageIdentityFuture = storage.computeDocumentId(
      filePath: path,
      bytes: bytes,
      contentSha256: knownFingerprint,
      contentLength: bytes?.length,
      operationId: operationId,
    );
    PdfAnnotationSaveDiagnostics.log(
      operationId,
      'document_identity_lookup',
      duration: lookupTimer.elapsed,
      fields: {
        'cache': 'miss',
        'pdfBytes': bytes?.length ?? 'unknown',
        'cachedFingerprint': knownFingerprint != null,
      },
    );
    return _storageIdentityFuture!;
  }

  void _schedulePersistenceDrain() {
    if (_persistenceDrain != null) return;
    final drain = Completer<void>();
    _persistenceDrain = drain.future;
    scheduleMicrotask(() async {
      try {
        await _drainPersistenceQueue();
      } finally {
        if (!drain.isCompleted) drain.complete();
      }
    });
  }

  Future<void> _drainPersistenceQueue() async {
    try {
      while (_pendingSaves.isNotEmpty) {
        final key = _pendingSaves.keys.first;
        final pending = _pendingSaves.remove(key)!;
        var succeeded = false;
        String? failure;
        for (final waiter in pending.waiters) {
          PdfAnnotationSaveDiagnostics.log(
            waiter.operationId,
            'persistence_queue_wait',
            duration: waiter.queueTimer.elapsed,
            fields: {
              'coalescedRequests': pending.waiters.length,
              'writerOperationId': pending.operationId,
            },
          );
        }
        try {
          final annotations = pending.annotations ?? _snapshotAnnotations();
          final documentId = await pending.documentId;
          succeeded = await _newStorageService().saveAnnotations(
            documentId: documentId,
            filePath: pending.filePath,
            annotations: annotations,
            highlightsVisible: pending.highlightsVisible,
            operationId: pending.operationId,
            pdfBytesLength: pending.pdfBytesLength,
          );
          if (!succeeded) failure = 'Annotation storage rejected the save.';
        } catch (error) {
          failure = error.toString();
        }

        if (pending.generation == _documentGeneration) {
          annotationPersistenceError = failure;
        }
        for (final waiter in pending.waiters) {
          if (!waiter.completer.isCompleted) {
            waiter.completer.complete(succeeded);
          }
        }
      }
    } finally {
      _persistenceDrain = null;
      if (_pendingSaves.isNotEmpty) {
        _schedulePersistenceDrain();
      } else if (isPersistingAnnotations) {
        isPersistingAnnotations = false;
        if (!_isDisposed) _notifyPersistenceListeners();
      }
    }
  }
}

class _PendingPdfAnnotationSave {
  _PendingPdfAnnotationSave({
    required this.operationId,
    required this.documentId,
    required this.generation,
    required this.filePath,
    required this.pdfBytesLength,
    required this.annotations,
    required this.highlightsVisible,
    required this.waiters,
  });

  final String operationId;
  final Future<String> documentId;
  final int generation;
  final String? filePath;
  final int? pdfBytesLength;
  Map<int, List<BoardStroke>>? annotations;
  bool highlightsVisible;
  final List<_PdfSaveWaiter> waiters;
}

class _PdfSaveWaiter {
  const _PdfSaveWaiter({
    required this.operationId,
    required this.completer,
    required this.queueTimer,
    required this.requestTimer,
  });

  final String operationId;
  final Completer<bool> completer;
  final Stopwatch queueTimer;
  final Stopwatch requestTimer;
}
