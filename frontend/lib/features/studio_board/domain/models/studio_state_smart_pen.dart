// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

class _SmartPenGroupSnapshot {
  _SmartPenGroupSnapshot({
    required this.persisted,
    required this.hasTemporaryOverride,
    required this.temporaryOverride,
  });

  final List<BoardStroke> persisted;
  final bool hasTemporaryOverride;
  BoardStroke? temporaryOverride;

  _SmartPenGroupSnapshot copy() => _SmartPenGroupSnapshot(
    persisted: persisted.map((stroke) => stroke.copy()).toList(),
    hasTemporaryOverride: hasTemporaryOverride,
    temporaryOverride: temporaryOverride?.copy(),
  );
}

class _SmartPenHistoryEntry {
  _SmartPenHistoryEntry({
    required this.affectedPages,
    required this.groupId,
    required this.before,
    required this.after,
    required this.persistedChanged,
    required this.sequence,
  });

  List<int> affectedPages;
  String groupId;
  final Map<int, _SmartPenGroupSnapshot> before;
  final Map<int, _SmartPenGroupSnapshot> after;
  final bool persistedChanged;
  int sequence;
  int redoSequence = 0;
}

extension StudioStateSmartPenExt on StudioState {
  void setSmartSnapEnabled(bool enabled) {
    if (_smartSnapEnabled == enabled) return;
    _smartSnapEnabled = enabled;
    notifyListeners();
  }

  void setSaveAnswerCirclesEnabled(bool enabled) {
    if (_saveAnswerCirclesEnabled == enabled) return;
    _saveAnswerCirclesEnabled = enabled;
    notifyListeners();
  }

  bool contributedToolSetting(String key, {bool defaultValue = false}) {
    if (key == StudioState.saveAnswerCirclesSettingKey) {
      return saveAnswerCirclesEnabled;
    }
    return _contributedToolSettings[key] ?? defaultValue;
  }

  void toggleContributedToolSetting(String key, {bool defaultValue = false}) {
    final next = !contributedToolSetting(key, defaultValue: defaultValue);
    if (key == StudioState.saveAnswerCirclesSettingKey) {
      setSaveAnswerCirclesEnabled(next);
      return;
    }
    _contributedToolSettings[key] = next;
    notifyListeners();
  }

  void dispatchSmartPenAnswer(SmartPenAnswerSelection selection) {
    smartPenAnswerSelection = selection;
    notifyListeners();
  }

  void toggleSmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) {
    final pages = _normalizeAffectedPages(selection.pageNumber, affectedPages);
    if (!_saveAnswerCirclesEnabled) {
      toggleTemporarySmartPenAnswer(selection, pageSize, affectedPages: pages);
      return;
    }
    final before = _captureSmartPenGroups(pages, selection.groupId);
    final isSameAnswer = pages.any(
      (pageNumber) => pdfAnnotationsForPage(pageNumber).any(
        (stroke) =>
            stroke.isSmartPenOval &&
            stroke.smartPenGroupId == selection.groupId &&
            stroke.smartPenLabel == selection.label,
      ),
    );
    for (final pageNumber in pages) {
      pdfAnnotations[pageNumber]?.removeWhere(
        (stroke) =>
            stroke.isSmartPenOval &&
            stroke.smartPenGroupId == selection.groupId,
      );
      _removeTemporarySmartPenOverride(pageNumber, selection.groupId);
    }
    if (!isSameAnswer) {
      final oval = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: pageSize,
        color: Colors.red,
        width: strokeWidth,
      );
      pdfAnnotations
          .putIfAbsent(selection.pageNumber, () => <BoardStroke>[])
          .add(oval.toBoardStroke());
    }
    smartPenAnswerSelection = selection;
    final persistedChanged = pages.any((pageNumber) {
      final beforeStrokes = before[pageNumber]!.persisted;
      final afterStrokes = (pdfAnnotations[pageNumber] ?? const <BoardStroke>[])
          .where(
            (stroke) =>
                stroke.isSmartPenOval &&
                stroke.smartPenGroupId == selection.groupId,
          )
          .toList();
      return jsonEncode(
            beforeStrokes.map((stroke) => stroke.toJson()).toList(),
          ) !=
          jsonEncode(afterStrokes.map((stroke) => stroke.toJson()).toList());
    });
    _finishSmartPenGroupEdit(
      selection,
      pages,
      before,
      persistedChanged: persistedChanged,
    );
  }

  void toggleTemporarySmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
  }) {
    final pages = _normalizeAffectedPages(selection.pageNumber, affectedPages);
    final before = _captureSmartPenGroups(pages, selection.groupId);
    final currentLabel =
        <BoardStroke>[
              for (final page in pages) ...?pdfAnnotations[page],
              for (final page in pages)
                ...?_temporarySmartPenOverrides[_smartPenHistoryKey]?[page]
                    ?.values
                    .whereType<BoardStroke>(),
            ]
            .where(
              (stroke) =>
                  stroke.isSmartPenOval &&
                  stroke.smartPenGroupId == selection.groupId,
            )
            .lastOrNull
            ?.smartPenLabel;
    final isSameAnswer = currentLabel == selection.label;
    final hadTemporaryOverride = pages.any(
      (page) =>
          _temporarySmartPenOverrides[_smartPenHistoryKey]?[page]?.containsKey(
            selection.groupId,
          ) ??
          false,
    );
    final documentOverrides = _temporarySmartPenOverrides.putIfAbsent(
      _smartPenHistoryKey,
      () => <int, Map<String, BoardStroke?>>{},
    );
    for (final page in pages) {
      documentOverrides[page]?.remove(selection.groupId);
      if (!hadTemporaryOverride && isSameAnswer) {
        final hasSavedAnswer =
            pdfAnnotations[page]?.any(
              (stroke) =>
                  stroke.isSmartPenOval &&
                  stroke.smartPenGroupId == selection.groupId,
            ) ??
            false;
        if (hasSavedAnswer) {
          documentOverrides.putIfAbsent(
            page,
            () => <String, BoardStroke?>{},
          )[selection.groupId] = null;
        }
      } else if (!isSameAnswer) {
        // Suppress persisted circles on all linked pages in this live session.
        documentOverrides.putIfAbsent(
          page,
          () => <String, BoardStroke?>{},
        )[selection.groupId] = null;
      }
    }
    if (!isSameAnswer) {
      documentOverrides[selection.pageNumber]![selection.groupId] =
          SmartPenOvalAnnotation.fromSelection(
            selection: selection,
            pageSize: pageSize,
            color: Colors.red,
            width: strokeWidth,
          ).toBoardStroke();
    }
    _pruneTemporaryOverrides(documentOverrides);
    smartPenAnswerSelection = selection;
    _finishSmartPenGroupEdit(selection, pages, before, persistedChanged: false);
  }

  void clearTemporarySmartPenAnswer(int pageNumber, String groupId) {
    if (!_removeTemporarySmartPenOverride(pageNumber, groupId)) return;
    _revision++;
    notifyListeners();
  }

  /// Rekeys an answer group after progressive indexing links a page-edge
  /// fragment to its neighbor. This is metadata migration and does not create
  /// a new undo step or mark the lesson dirty.
  void migrateSmartPenAnswerGroup(
    String provisionalId,
    String canonicalId, {
    required List<int> affectedPages,
  }) {
    if (provisionalId == canonicalId) return;
    final pageSet = affectedPages.toSet();
    final isCurrentSelection =
        smartPenAnswerSelection?.groupId == provisionalId;
    final canonicalAlreadyHasAnswer = pageSet.any((page) {
      final saved =
          pdfAnnotations[page]?.any(
            (stroke) =>
                stroke.isSmartPenOval && stroke.smartPenGroupId == canonicalId,
          ) ??
          false;
      final temporary =
          _temporarySmartPenOverrides[_smartPenHistoryKey]?[page]?[canonicalId]
              ?.isSmartPenOval ??
          false;
      return saved || temporary;
    });
    final overrides = _temporarySmartPenOverrides[_smartPenHistoryKey];
    final provisionalHasSavedAnswer = pageSet.any(
      (page) =>
          pdfAnnotations[page]?.any(
            (stroke) =>
                stroke.isSmartPenOval &&
                stroke.smartPenGroupId == provisionalId,
          ) ??
          false,
    );
    final provisionalHasTemporaryOverride = pageSet.any(
      (page) => overrides?[page]?.containsKey(provisionalId) ?? false,
    );
    // If separate pages were selected before their edge fragments linked,
    // keep the latest selection and collapse the earlier provisional circle.
    final replaceCanonical =
        isCurrentSelection &&
        canonicalAlreadyHasAnswer &&
        (provisionalHasSavedAnswer || provisionalHasTemporaryOverride);
    final history = _smartPenUndo[_smartPenHistoryKey] ?? const [];
    final selectionHistoryEntry = replaceCanonical
        ? history
              .where((entry) => entry.groupId == provisionalId)
              .fold<_SmartPenHistoryEntry?>(
                null,
                (latest, entry) =>
                    latest == null || entry.sequence > latest.sequence
                    ? entry
                    : latest,
              )
        : null;
    final canonicalBefore = replaceCanonical
        ? _captureSmartPenGroups(pageSet.toList(), canonicalId)
        : const <int, _SmartPenGroupSnapshot>{};
    final preserveCanonical = canonicalAlreadyHasAnswer && !isCurrentSelection;
    for (final page in pageSet) {
      final strokes = pdfAnnotations[page];
      if (strokes == null) continue;
      if (replaceCanonical && provisionalHasSavedAnswer) {
        strokes.removeWhere(
          (stroke) =>
              stroke.isSmartPenOval && stroke.smartPenGroupId == canonicalId,
        );
      }
      if (preserveCanonical) {
        strokes.removeWhere(
          (stroke) =>
              stroke.isSmartPenOval && stroke.smartPenGroupId == provisionalId,
        );
      } else {
        for (var i = 0; i < strokes.length; i++) {
          final stroke = strokes[i];
          if (stroke.isSmartPenOval &&
              stroke.smartPenGroupId == provisionalId) {
            strokes[i] = _copySmartPenStroke(stroke, canonicalId);
          }
        }
      }
    }
    if (overrides != null) {
      for (final page in pageSet) {
        final values = overrides[page];
        if (values == null) continue;
        if (replaceCanonical && provisionalHasSavedAnswer) {
          // A saved latest choice supersedes any earlier session-only circle.
          values.remove(canonicalId);
        } else if (replaceCanonical && provisionalHasTemporaryOverride) {
          // Keep persisted data intact; the temporary choice shadows it in the
          // visible session while removing any older temporary canonical oval.
          final hasSavedCanonical =
              pdfAnnotations[page]?.any(
                (stroke) =>
                    stroke.isSmartPenOval &&
                    stroke.smartPenGroupId == canonicalId,
              ) ??
              false;
          if (hasSavedCanonical) {
            values[canonicalId] = null;
          } else {
            values.remove(canonicalId);
          }
        }
        if (!values.containsKey(provisionalId)) continue;
        final value = values.remove(provisionalId);
        if (!preserveCanonical || !values.containsKey(canonicalId)) {
          values[canonicalId] = value == null
              ? null
              : _copySmartPenStroke(value, canonicalId);
        }
      }
    }
    for (final stacks in [_smartPenUndo, _smartPenRedo]) {
      for (final entry in stacks[_smartPenHistoryKey] ?? const []) {
        if (entry.groupId != provisionalId) continue;
        entry.groupId = canonicalId;
        for (final snapshots in [entry.before, entry.after]) {
          for (final snapshot in snapshots.values) {
            for (var i = 0; i < snapshot.persisted.length; i++) {
              snapshot.persisted[i] = _copySmartPenStroke(
                snapshot.persisted[i],
                canonicalId,
              );
            }
            final temporary = snapshot.temporaryOverride;
            if (temporary != null) {
              snapshot.temporaryOverride = _copySmartPenStroke(
                temporary,
                canonicalId,
              );
            }
          }
        }
      }
    }
    if (selectionHistoryEntry != null) {
      for (final page in pageSet) {
        selectionHistoryEntry.before.putIfAbsent(
          page,
          () => canonicalBefore[page]!.copy(),
        );
        selectionHistoryEntry.after[page] = _captureSmartPenGroup(
          page,
          canonicalId,
        );
      }
      selectionHistoryEntry.affectedPages = {
        ...selectionHistoryEntry.affectedPages,
        ...pageSet,
      }.toList()..sort();
    }
    final selection = smartPenAnswerSelection;
    if (selection?.groupId == provisionalId) {
      smartPenAnswerSelection = SmartPenAnswerSelection(
        pageNumber: selection!.pageNumber,
        label: selection.label,
        bounds: selection.bounds,
        groupId: canonicalId,
      );
    }
  }

  BoardStroke _copySmartPenStroke(BoardStroke stroke, String groupId) =>
      BoardStroke(
        stroke.color,
        stroke.width,
        List.of(stroke.points),
        isEraser: stroke.isEraser,
        rect: stroke.rect,
        isHollow: stroke.isHollow,
        smartPenGroupId: groupId,
        smartPenLabel: stroke.smartPenLabel,
      );

  bool _removeTemporarySmartPenOverride(int pageNumber, String groupId) {
    final documentOverrides = _temporarySmartPenOverrides[_smartPenHistoryKey];
    final pageOverrides = documentOverrides?[pageNumber];
    if (pageOverrides == null || !pageOverrides.containsKey(groupId)) {
      return false;
    }
    pageOverrides.remove(groupId);
    if (pageOverrides.isEmpty) documentOverrides!.remove(pageNumber);
    if (documentOverrides!.isEmpty) {
      _temporarySmartPenOverrides.remove(_smartPenHistoryKey);
    }
    return true;
  }

  List<int> _normalizeAffectedPages(int selectedPage, List<int>? pages) =>
      (pages ?? [selectedPage]).where((page) => page > 0).toSet().toList()
        ..sort();

  Map<int, _SmartPenGroupSnapshot> _captureSmartPenGroups(
    List<int> pages,
    String groupId,
  ) => {for (final page in pages) page: _captureSmartPenGroup(page, groupId)};

  _SmartPenGroupSnapshot _captureSmartPenGroup(int pageNumber, String groupId) {
    final persisted = (pdfAnnotations[pageNumber] ?? const <BoardStroke>[])
        .where(
          (stroke) =>
              stroke.isSmartPenOval && stroke.smartPenGroupId == groupId,
        )
        .map((stroke) => stroke.copy())
        .toList();
    final overrides =
        _temporarySmartPenOverrides[_smartPenHistoryKey]?[pageNumber];
    final hasOverride = overrides?.containsKey(groupId) ?? false;
    return _SmartPenGroupSnapshot(
      persisted: persisted,
      hasTemporaryOverride: hasOverride,
      temporaryOverride: hasOverride ? overrides![groupId]?.copy() : null,
    );
  }

  void _finishSmartPenGroupEdit(
    SmartPenAnswerSelection selection,
    List<int> pages,
    Map<int, _SmartPenGroupSnapshot> before, {
    required bool persistedChanged,
  }) {
    final after = _captureSmartPenGroups(pages, selection.groupId);
    _smartPenUndo
        .putIfAbsent(_smartPenHistoryKey, () => [])
        .add(
          _SmartPenHistoryEntry(
            affectedPages: List.of(pages),
            groupId: selection.groupId,
            before: before,
            after: after,
            persistedChanged: persistedChanged,
            sequence: ++_historySequence,
          ),
        );
    _smartPenRedo[_smartPenHistoryKey]?.clear();
    _currentRedoStack.clear();
    _revision++;
    if (persistedChanged) dirty = true;
    notifyListeners();
  }

  void _pruneTemporaryOverrides(Map<int, Map<String, BoardStroke?>> overrides) {
    overrides.removeWhere((_, groups) => groups.isEmpty);
    if (overrides.isEmpty) {
      _temporarySmartPenOverrides.remove(_smartPenHistoryKey);
    }
  }

  void clearTemporarySmartPenAnswers({String? documentId}) {
    if (documentId == null) {
      if (_temporarySmartPenOverrides.isEmpty) return;
      _temporarySmartPenOverrides.clear();
      _revision++;
      notifyListeners();
      return;
    }
    if (_temporarySmartPenOverrides.remove(documentId) != null) {
      _revision++;
      notifyListeners();
    }
  }

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
      if (entry.persistedChanged) dirty = true;
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
      if (entry.persistedChanged) dirty = true;
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

  void _clearSmartPenHistory({String? documentId}) {
    if (documentId == null) {
      _smartPenUndo.clear();
      _smartPenRedo.clear();
      return;
    }
    _smartPenUndo.remove(documentId);
    _smartPenRedo.remove(documentId);
  }

  void _applySmartPenHistory(
    _SmartPenHistoryEntry entry,
    Map<int, _SmartPenGroupSnapshot> snapshots,
  ) {
    final docOverrides = _temporarySmartPenOverrides.putIfAbsent(
      _smartPenHistoryKey,
      () => <int, Map<String, BoardStroke?>>{},
    );
    for (final pageNumber in entry.affectedPages) {
      final snapshot = snapshots[pageNumber];
      if (snapshot == null) continue;
      final pageStrokes = pdfAnnotations[pageNumber];
      if (pageStrokes != null || snapshot.persisted.isNotEmpty) {
        final target = pageStrokes ?? <BoardStroke>[];
        target.removeWhere(
          (stroke) =>
              stroke.isSmartPenOval && stroke.smartPenGroupId == entry.groupId,
        );
        target.addAll(snapshot.persisted.map((stroke) => stroke.copy()));
        if (target.isEmpty) {
          pdfAnnotations.remove(pageNumber);
        } else if (pageStrokes == null) {
          pdfAnnotations[pageNumber] = target;
        }
      }
      final pageOverrides = docOverrides.putIfAbsent(
        pageNumber,
        () => <String, BoardStroke?>{},
      );
      if (snapshot.hasTemporaryOverride) {
        pageOverrides[entry.groupId] = snapshot.temporaryOverride?.copy();
      } else {
        pageOverrides.remove(entry.groupId);
      }
      if (pageOverrides.isEmpty) docOverrides.remove(pageNumber);
    }
    if (docOverrides.isEmpty) {
      _temporarySmartPenOverrides.remove(_smartPenHistoryKey);
    }
  }
}
