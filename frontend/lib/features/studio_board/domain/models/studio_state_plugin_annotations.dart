// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'studio_state.dart';

class _PdfAnnotationGroupSnapshot {
  _PdfAnnotationGroupSnapshot({
    required this.persisted,
    required this.hasTemporaryOverride,
    required this.temporaryOverride,
  });

  final List<BoardStroke> persisted;
  final bool hasTemporaryOverride;
  BoardStroke? temporaryOverride;

  _PdfAnnotationGroupSnapshot copy() => _PdfAnnotationGroupSnapshot(
    persisted: persisted.map((stroke) => stroke.copy()).toList(),
    hasTemporaryOverride: hasTemporaryOverride,
    temporaryOverride: temporaryOverride?.copy(),
  );
}

class _PdfAnnotationHistoryEntry {
  _PdfAnnotationHistoryEntry({
    required this.affectedPages,
    required this.groupId,
    required this.before,
    required this.after,
    required this.persistedChanged,
    required this.sequence,
    this.persistOperation,
  });

  List<int> affectedPages;
  String groupId;
  final Map<int, _PdfAnnotationGroupSnapshot> before;
  final Map<int, _PdfAnnotationGroupSnapshot> after;
  bool persistedChanged;
  final bool? persistOperation;
  int sequence;
  int redoSequence = 0;
}

/// Host storage for plugin-provided closed paths. Geometry and style belong to
/// the plugin; the Host provides group replacement, persistence and undo.
extension StudioStatePluginAnnotationsExt on StudioState {
  void togglePluginPdfAnnotation({
    required int pageNumber,
    required BoardStroke annotation,
    required bool persist,
    required List<int> affectedPages,
  }) {
    final groupId = annotation.annotationGroupId;
    final itemId = annotation.annotationItemId;
    if (groupId == null ||
        itemId == null ||
        !annotation.isGroupedPdfAnnotation) {
      throw ArgumentError('A plugin annotation needs group and item metadata.');
    }
    final pages = _normalizeAffectedPages(pageNumber, [
      pageNumber,
      ...affectedPages,
      for (final entry in pdfAnnotations.entries)
        if (entry.value.any((stroke) => stroke.annotationGroupId == groupId))
          entry.key,
      for (final entry
          in (_temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey] ??
                  <int, Map<String, BoardStroke?>>{})
              .entries)
        if (entry.value.containsKey(groupId)) entry.key,
    ]);
    final before = _capturePdfAnnotationGroups(pages, groupId);
    final sameItem = pages.any(
      (page) => pdfAnnotationsForPage(page).any(
        (stroke) =>
            stroke.annotationGroupId == groupId &&
            stroke.annotationItemId == itemId,
      ),
    );
    final overrides = _temporaryPdfAnnotationOverrides.putIfAbsent(
      _pdfAnnotationHistoryKey,
      () => <int, Map<String, BoardStroke?>>{},
    );
    for (final page in pages) {
      overrides[page]?.remove(groupId);
      if (persist) {
        pdfAnnotations[page]?.removeWhere(
          (stroke) => stroke.annotationGroupId == groupId,
        );
      } else {
        // A null override hides the persisted group for this session.
        overrides.putIfAbsent(page, () => <String, BoardStroke?>{})[groupId] =
            null;
      }
    }
    if (!sameItem) {
      if (persist) {
        pdfAnnotations.putIfAbsent(pageNumber, () => []).add(annotation.copy());
      } else {
        overrides[pageNumber]![groupId] = annotation.copy();
      }
    }
    _pruneTemporaryOverrides(overrides);
    final changed =
        persist &&
        pages.any((page) {
          final after = _capturePdfAnnotationGroup(page, groupId);
          return jsonEncode(
                before[page]!.persisted.map((s) => s.toJson()).toList(),
              ) !=
              jsonEncode(after.persisted.map((s) => s.toJson()).toList());
        });
    _finishPdfAnnotationGroupEdit(
      groupId,
      pages,
      before,
      persistedChanged: changed,
      persistOperation: persist,
    );
  }
}

extension StudioStatePdfAnnotationHistoryExt on StudioState {
  List<int> _normalizeAffectedPages(int selectedPage, List<int>? pages) =>
      (pages ?? [selectedPage]).where((page) => page > 0).toSet().toList()
        ..sort();

  Map<int, _PdfAnnotationGroupSnapshot> _capturePdfAnnotationGroups(
    List<int> pages,
    String groupId,
  ) => {
    for (final page in pages) page: _capturePdfAnnotationGroup(page, groupId),
  };

  _PdfAnnotationGroupSnapshot _capturePdfAnnotationGroup(
    int pageNumber,
    String groupId,
  ) {
    final persisted = (pdfAnnotations[pageNumber] ?? const <BoardStroke>[])
        .where(
          (stroke) =>
              stroke.isGroupedPdfAnnotation &&
              stroke.groupedAnnotationGroupId == groupId,
        )
        .map((stroke) => stroke.copy())
        .toList();
    final overrides =
        _temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey]?[pageNumber];
    final hasOverride = overrides?.containsKey(groupId) ?? false;
    return _PdfAnnotationGroupSnapshot(
      persisted: persisted,
      hasTemporaryOverride: hasOverride,
      temporaryOverride: hasOverride ? overrides![groupId]?.copy() : null,
    );
  }

  void _finishPdfAnnotationGroupEdit(
    String groupId,
    List<int> pages,
    Map<int, _PdfAnnotationGroupSnapshot> before, {
    required bool persistedChanged,
    bool? persistOperation,
  }) {
    final after = _capturePdfAnnotationGroups(pages, groupId);
    _historySequence = pdf.smartPenManager.historySequence;
    final sequence = ++_historySequence;
    pdf.smartPenManager.historySequence = _historySequence;
    _pdfAnnotationUndo
        .putIfAbsent(_pdfAnnotationHistoryKey, () => [])
        .add(
          _PdfAnnotationHistoryEntry(
            affectedPages: List.of(pages),
            groupId: groupId,
            before: before,
            after: after,
            persistedChanged: persistedChanged,
            persistOperation: persistOperation,
            sequence: sequence,
          ),
        );
    _pdfAnnotationRedo[_pdfAnnotationHistoryKey]?.clear();
    canvas.clearRedo();
    _revision++;
    if (persistedChanged) dirty = true;
    notifyListeners();
  }

  void _pruneTemporaryOverrides(Map<int, Map<String, BoardStroke?>> overrides) {
    overrides.removeWhere((_, groups) => groups.isEmpty);
    if (overrides.isEmpty) {
      _temporaryPdfAnnotationOverrides.remove(_pdfAnnotationHistoryKey);
    }
  }

  void clearTemporarySmartPenAnswers({String? documentId}) {
    if (documentId == null) {
      if (_temporaryPdfAnnotationOverrides.isEmpty) return;
      _temporaryPdfAnnotationOverrides.clear();
      _revision++;
      notifyListeners();
      return;
    }
    if (_temporaryPdfAnnotationOverrides.remove(documentId) != null) {
      _revision++;
      notifyListeners();
    }
  }

  bool get _canUndoPluginAnnotation =>
      _pdfAnnotationUndo[_pdfAnnotationHistoryKey]?.isNotEmpty ?? false;

  bool get _canRedoPluginAnnotation =>
      _pdfAnnotationRedo[_pdfAnnotationHistoryKey]?.isNotEmpty ?? false;

  bool _undoPluginAnnotation() {
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
      return true;
    }
    return false;
  }

  bool _redoPluginAnnotation() {
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
      return true;
    }
    return false;
  }

  void _clearPdfAnnotationHistory({String? documentId}) {
    if (documentId == null) {
      _pdfAnnotationUndo.clear();
      _pdfAnnotationRedo.clear();
      return;
    }
    _pdfAnnotationUndo.remove(documentId);
    _pdfAnnotationRedo.remove(documentId);
  }

  void _applyPdfAnnotationHistory(
    _PdfAnnotationHistoryEntry entry,
    Map<int, _PdfAnnotationGroupSnapshot> snapshots,
  ) {
    final docOverrides = _temporaryPdfAnnotationOverrides.putIfAbsent(
      _pdfAnnotationHistoryKey,
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
              stroke.isGroupedPdfAnnotation &&
              stroke.groupedAnnotationGroupId == entry.groupId,
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
      _temporaryPdfAnnotationOverrides.remove(_pdfAnnotationHistoryKey);
    }
  }
}

extension StudioStatePdfAnnotationMigrationExt on StudioState {
  /// Rebase the two group timelines as one sequence of group replacements.
  /// This preserves the previous choice in both merge directions, including
  /// session-only overrides and operations already waiting on the redo stack.
  void _reconcilePluginAnnotationGroups(
    String from,
    String to,
    List<int> affectedPages,
  ) {
    bool belongs(_PdfAnnotationHistoryEntry entry) =>
        entry.groupId == from || entry.groupId == to;
    final applied =
        (_pdfAnnotationUndo[_pdfAnnotationHistoryKey] ?? [])
            .where(belongs)
            .toList()
          ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final undone =
        (_pdfAnnotationRedo[_pdfAnnotationHistoryKey] ?? [])
            .where(belongs)
            .toList()
          ..sort((a, b) => b.redoSequence.compareTo(a.redoSequence));
    final timeline = [...applied, ...undone];
    final pages = <int>{
      ...affectedPages,
      ...pdfAnnotations.keys,
      ...?_temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey]?.keys,
      for (final entry in timeline) ...entry.affectedPages,
    }.toList()..sort();
    Map<int, _PdfAnnotationGroupSnapshot> copy(
      Map<int, _PdfAnnotationGroupSnapshot> source,
    ) => {
      for (final page in pages)
        page: _PdfAnnotationGroupSnapshot(
          persisted: [
            for (final stroke in source[page]?.persisted ?? <BoardStroke>[])
              _copyGroupedPdfStroke(stroke, to),
          ],
          hasTemporaryOverride: source[page]?.hasTemporaryOverride ?? false,
          temporaryOverride: source[page]?.temporaryOverride == null
              ? null
              : _copyGroupedPdfStroke(source[page]!.temporaryOverride!, to),
        ),
    };
    final originalGroups = {for (final entry in timeline) entry: entry.groupId};
    final originalBefore = {
      for (final entry in timeline) entry: copy(entry.before),
    };
    final originalAfter = {
      for (final entry in timeline) entry: copy(entry.after),
    };
    Map<int, _PdfAnnotationGroupSnapshot> baseline(String group) {
      for (final entry in timeline) {
        if (originalGroups[entry] == group) return copy(originalBefore[entry]!);
      }
      return copy(_capturePdfAnnotationGroups(pages, group));
    }

    final canonicalBaseline = baseline(to);
    final hasCanonicalBaseline = canonicalBaseline.values.any(
      (snapshot) =>
          snapshot.persisted.isNotEmpty || snapshot.hasTemporaryOverride,
    );
    var state = hasCanonicalBaseline ? canonicalBaseline : baseline(from);
    String savedState(Map<int, _PdfAnnotationGroupSnapshot> snapshots) =>
        jsonEncode({
          for (final page in pages)
            '$page': snapshots[page]!.persisted
                .map((stroke) => stroke.toJson())
                .toList(),
        });
    void replay(_PdfAnnotationHistoryEntry entry) {
      final before = copy(state);
      final source = originalAfter[entry]!;
      if (entry.persistOperation == false) {
        // Session-only choices replace the visible item while retaining the
        // most recent persisted choice from the combined history.
        state = {
          for (final page in pages)
            page: _PdfAnnotationGroupSnapshot(
              persisted: before[page]!.persisted,
              hasTemporaryOverride: true,
              temporaryOverride: source[page]!.temporaryOverride?.copy(),
            ),
        };
      } else {
        state = copy(source);
      }
      entry.groupId = to;
      entry.affectedPages = List.of(pages);
      entry.before
        ..clear()
        ..addAll(before);
      entry.after
        ..clear()
        ..addAll(copy(state));
      entry.persistedChanged =
          entry.persistOperation != false &&
          savedState(before) != savedState(state);
    }

    for (final entry in applied) {
      replay(entry);
    }
    final currentState = copy(state);
    for (final entry in undone) {
      replay(entry);
    }
    final savedBefore = jsonEncode({
      for (final page in pages)
        '$page': (pdfAnnotations[page] ?? <BoardStroke>[])
            .where(
              (stroke) =>
                  stroke.groupedAnnotationGroupId == from ||
                  stroke.groupedAnnotationGroupId == to,
            )
            .map((stroke) => stroke.toJson())
            .toList(),
    });
    final overrides = _temporaryPdfAnnotationOverrides.putIfAbsent(
      _pdfAnnotationHistoryKey,
      () => <int, Map<String, BoardStroke?>>{},
    );
    for (final page in pages) {
      final snapshot = currentState[page]!;
      final strokes = pdfAnnotations[page] ?? <BoardStroke>[];
      strokes.removeWhere(
        (stroke) =>
            stroke.groupedAnnotationGroupId == from ||
            stroke.groupedAnnotationGroupId == to,
      );
      strokes.addAll(snapshot.persisted.map((stroke) => stroke.copy()));
      if (strokes.isEmpty) {
        pdfAnnotations.remove(page);
      } else {
        pdfAnnotations[page] = strokes;
      }
      final values = overrides.putIfAbsent(
        page,
        () => <String, BoardStroke?>{},
      );
      values.remove(from);
      values.remove(to);
      if (snapshot.hasTemporaryOverride) {
        values[to] = snapshot.temporaryOverride?.copy();
      }
    }
    _pruneTemporaryOverrides(overrides);
    _revision++;
    if (savedBefore != savedState(currentState)) dirty = true;
    notifyListeners();
  }

  void migratePdfAnnotationGroup(
    String provisionalId,
    String canonicalId, {
    required List<int> affectedPages,
    bool? preferProvisional,
    bool notifyChange = true,
  }) {
    if (provisionalId == canonicalId) return;
    if (preferProvisional == null) {
      _reconcilePluginAnnotationGroups(
        provisionalId,
        canonicalId,
        affectedPages,
      );
      return;
    }
    final history = _pdfAnnotationUndo[_pdfAnnotationHistoryKey] ?? const [];
    final pageSet = {
      ...affectedPages,
      ...pdfAnnotations.keys,
      ...?_temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey]?.keys,
      for (final entry in history)
        if (entry.groupId == provisionalId || entry.groupId == canonicalId)
          ...entry.affectedPages,
    };
    final isCurrentSelection = preferProvisional;
    final canonicalAlreadyHasAnswer = pageSet.any((page) {
      final saved =
          pdfAnnotations[page]?.any(
            (stroke) =>
                stroke.isGroupedPdfAnnotation &&
                stroke.groupedAnnotationGroupId == canonicalId,
          ) ??
          false;
      final temporary =
          _temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey]?[page]?[canonicalId]
              ?.isGroupedPdfAnnotation ??
          false;
      return saved || temporary;
    });
    final overrides =
        _temporaryPdfAnnotationOverrides[_pdfAnnotationHistoryKey];
    final provisionalHasSavedAnswer = pageSet.any(
      (page) =>
          pdfAnnotations[page]?.any(
            (stroke) =>
                stroke.isGroupedPdfAnnotation &&
                stroke.groupedAnnotationGroupId == provisionalId,
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
    final selectionHistoryEntry = replaceCanonical
        ? history
              .where((entry) => entry.groupId == provisionalId)
              .fold<_PdfAnnotationHistoryEntry?>(
                null,
                (latest, entry) =>
                    latest == null || entry.sequence > latest.sequence
                    ? entry
                    : latest,
              )
        : null;
    final canonicalBefore = replaceCanonical
        ? _capturePdfAnnotationGroups(pageSet.toList(), canonicalId)
        : const <int, _PdfAnnotationGroupSnapshot>{};
    final preserveCanonical = canonicalAlreadyHasAnswer && !isCurrentSelection;
    for (final page in pageSet) {
      final strokes = pdfAnnotations[page];
      if (strokes == null) continue;
      if (replaceCanonical && provisionalHasSavedAnswer) {
        strokes.removeWhere(
          (stroke) =>
              stroke.isGroupedPdfAnnotation &&
              stroke.groupedAnnotationGroupId == canonicalId,
        );
      }
      if (preserveCanonical) {
        strokes.removeWhere(
          (stroke) =>
              stroke.isGroupedPdfAnnotation &&
              stroke.groupedAnnotationGroupId == provisionalId,
        );
      } else {
        for (var i = 0; i < strokes.length; i++) {
          final stroke = strokes[i];
          if (stroke.isGroupedPdfAnnotation &&
              stroke.groupedAnnotationGroupId == provisionalId) {
            strokes[i] = _copyGroupedPdfStroke(stroke, canonicalId);
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
                    stroke.isGroupedPdfAnnotation &&
                    stroke.groupedAnnotationGroupId == canonicalId,
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
              : _copyGroupedPdfStroke(value, canonicalId);
        }
      }
    }
    for (final stacks in [_pdfAnnotationUndo, _pdfAnnotationRedo]) {
      for (final entry in stacks[_pdfAnnotationHistoryKey] ?? const []) {
        if (entry.groupId != provisionalId) continue;
        entry.groupId = canonicalId;
        for (final snapshots in [entry.before, entry.after]) {
          for (final snapshot in snapshots.values) {
            for (var i = 0; i < snapshot.persisted.length; i++) {
              snapshot.persisted[i] = _copyGroupedPdfStroke(
                snapshot.persisted[i],
                canonicalId,
              );
            }
            final temporary = snapshot.temporaryOverride;
            if (temporary != null) {
              snapshot.temporaryOverride = _copyGroupedPdfStroke(
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
        selectionHistoryEntry.after[page] = _capturePdfAnnotationGroup(
          page,
          canonicalId,
        );
      }
      selectionHistoryEntry.affectedPages = {
        ...selectionHistoryEntry.affectedPages,
        ...pageSet,
      }.toList()..sort();
    }
    if (notifyChange) {
      _revision++;
      if (provisionalHasSavedAnswer) dirty = true;
      notifyListeners();
    }
  }

  BoardStroke _copyGroupedPdfStroke(BoardStroke stroke, String groupId) =>
      BoardStroke(
        stroke.color,
        stroke.width,
        List.of(stroke.points),
        isEraser: stroke.isEraser,
        rect: stroke.rect,
        isHollow: stroke.isHollow,
        smartPenGroupId: stroke.annotationOwnerId == null
            ? groupId
            : stroke.smartPenGroupId,
        smartPenLabel: stroke.smartPenLabel,
        annotationOwnerId: stroke.annotationOwnerId,
        annotationGroupId: stroke.annotationOwnerId == null ? null : groupId,
        annotationItemId: stroke.annotationItemId,
      );
}
