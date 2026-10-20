import 'dart:convert';
import 'package:flutter/material.dart';
import '../../domain/models/smart_pen_answer_selection.dart';
import '../../domain/models/smart_pen_oval_annotation.dart';
import '../../domain/models/studio_board_models.dart';

class SmartPenGroupSnapshot {
  SmartPenGroupSnapshot({
    required this.persisted,
    required this.hasTemporaryOverride,
    required this.temporaryOverride,
  });

  final List<BoardStroke> persisted;
  final bool hasTemporaryOverride;
  BoardStroke? temporaryOverride;

  SmartPenGroupSnapshot copy() => SmartPenGroupSnapshot(
    persisted: persisted.map((stroke) => stroke.copy()).toList(),
    hasTemporaryOverride: hasTemporaryOverride,
    temporaryOverride: temporaryOverride?.copy(),
  );
}

class SmartPenHistoryEntry {
  SmartPenHistoryEntry({
    required this.affectedPages,
    required this.groupId,
    required this.before,
    required this.after,
    required this.persistedChanged,
    required this.sequence,
  });

  List<int> affectedPages;
  String groupId;
  final Map<int, SmartPenGroupSnapshot> before;
  final Map<int, SmartPenGroupSnapshot> after;
  final bool persistedChanged;
  int sequence;
  int redoSequence = 0;
}

/// Dedicated domain manager responsible for Smart Pen answer oval selections,
/// session-only (temporary) answer overrides, and isolated answer undo/redo histories.
class SmartPenAnswerManager {
  SmartPenAnswerManager({
    required this.getPdfAnnotations,
    required this.getHistoryKey,
    required this.onChanged,
    this.onMarkDirty,
  });

  final Map<int, List<BoardStroke>> Function() getPdfAnnotations;
  final String Function() getHistoryKey;
  final VoidCallback onChanged;
  VoidCallback? onMarkDirty;
  VoidCallback? onClearBoardRedo;

  bool smartSnapEnabled = false;
  bool saveAnswerCirclesEnabled = true;
  SmartPenAnswerSelection? smartPenAnswerSelection;

  final Map<String, List<SmartPenHistoryEntry>> smartPenUndo = {};
  final Map<String, List<SmartPenHistoryEntry>> smartPenRedo = {};
  final Map<String, Map<int, Map<String, BoardStroke?>>> temporarySmartPenOverrides = {};
  int historySequence = 0;

  void resetSession({bool resetSavingDefault = true}) {
    if (resetSavingDefault) saveAnswerCirclesEnabled = true;
    temporarySmartPenOverrides.clear();
    clearHistory();
  }

  void clearHistory({String? documentId}) {
    if (documentId == null) {
      smartPenUndo.clear();
      smartPenRedo.clear();
    } else {
      smartPenUndo.remove(documentId);
      smartPenRedo.remove(documentId);
    }
  }

  void clearTemporaryAnswers({String? documentId}) {
    if (documentId == null) {
      if (temporarySmartPenOverrides.isEmpty) return;
      temporarySmartPenOverrides.clear();
      onChanged();
      return;
    }
    if (temporarySmartPenOverrides.remove(documentId) != null) {
      onChanged();
    }
  }

  bool clearTemporaryAnswer(int pageNumber, String groupId) {
    final key = getHistoryKey();
    final documentOverrides = temporarySmartPenOverrides[key];
    final pageOverrides = documentOverrides?[pageNumber];
    if (pageOverrides == null || !pageOverrides.containsKey(groupId)) {
      return false;
    }
    pageOverrides.remove(groupId);
    if (pageOverrides.isEmpty) documentOverrides!.remove(pageNumber);
    if (documentOverrides!.isEmpty) {
      temporarySmartPenOverrides.remove(key);
    }
    onChanged();
    return true;
  }

  List<BoardStroke> filterVisibleAnnotations(int pageNumber, List<BoardStroke> persisted) {
    final key = getHistoryKey();
    final overrides = temporarySmartPenOverrides[key]?[pageNumber];
    if (overrides == null || overrides.isEmpty) return List.of(persisted);

    final visible = persisted.where((stroke) {
      final groupId = stroke.smartPenGroupId;
      return !stroke.isSmartPenOval || groupId == null || !overrides.containsKey(groupId);
    }).toList();
    visible.addAll(overrides.values.whereType<BoardStroke>());
    return visible;
  }

  void toggleSmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
    double strokeWidth = 3.5,
  }) {
    final pages = _normalizeAffectedPages(selection.pageNumber, affectedPages);
    if (!saveAnswerCirclesEnabled) {
      toggleTemporarySmartPenAnswer(selection, pageSize, affectedPages: pages, strokeWidth: strokeWidth);
      return;
    }

    final before = _captureSmartPenGroups(pages, selection.groupId);
    final pdfAnnotations = getPdfAnnotations();
    final isSameAnswer = pages.any(
      (pageNumber) => filterVisibleAnnotations(pageNumber, pdfAnnotations[pageNumber] ?? const <BoardStroke>[]).any(
        (stroke) =>
            stroke.isSmartPenOval &&
            stroke.smartPenGroupId == selection.groupId &&
            stroke.smartPenLabel == selection.label,
      ),
    );

    for (final pageNumber in pages) {
      pdfAnnotations[pageNumber]?.removeWhere(
        (stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == selection.groupId,
      );
      _removeTemporaryOverride(pageNumber, selection.groupId);
    }

    if (!isSameAnswer) {
      final oval = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: pageSize,
        color: Colors.red,
        width: strokeWidth,
      );
      pdfAnnotations.putIfAbsent(selection.pageNumber, () => <BoardStroke>[]).add(oval.toBoardStroke());
    }

    smartPenAnswerSelection = selection;
    final persistedChanged = pages.any((pageNumber) {
      final beforeStrokes = before[pageNumber]!.persisted;
      final afterStrokes = (pdfAnnotations[pageNumber] ?? const <BoardStroke>[])
          .where((stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == selection.groupId)
          .toList();
      return jsonEncode(beforeStrokes.map((s) => s.toJson()).toList()) !=
          jsonEncode(afterStrokes.map((s) => s.toJson()).toList());
    });

    _finishGroupEdit(selection, pages, before, persistedChanged: persistedChanged);
  }

  void toggleTemporarySmartPenAnswer(
    SmartPenAnswerSelection selection,
    Size pageSize, {
    List<int>? affectedPages,
    double strokeWidth = 3.5,
  }) {
    final pages = _normalizeAffectedPages(selection.pageNumber, affectedPages);
    final before = _captureSmartPenGroups(pages, selection.groupId);
    final key = getHistoryKey();
    final pdfAnnotations = getPdfAnnotations();

    final currentLabel = <BoardStroke>[
      for (final page in pages) ...?pdfAnnotations[page],
      for (final page in pages)
        ...?temporarySmartPenOverrides[key]?[page]?.values.whereType<BoardStroke>(),
    ].where((stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == selection.groupId).lastOrNull?.smartPenLabel;

    final isSameAnswer = currentLabel == selection.label;
    final hadTemporaryOverride = pages.any(
      (page) => temporarySmartPenOverrides[key]?[page]?.containsKey(selection.groupId) ?? false,
    );

    final documentOverrides = temporarySmartPenOverrides.putIfAbsent(
      key,
      () => <int, Map<String, BoardStroke?>>{},
    );

    for (final page in pages) {
      documentOverrides[page]?.remove(selection.groupId);
      if (!hadTemporaryOverride && isSameAnswer) {
        final hasSavedAnswer = pdfAnnotations[page]?.any(
          (stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == selection.groupId,
        ) ?? false;
        if (hasSavedAnswer) {
          documentOverrides.putIfAbsent(page, () => <String, BoardStroke?>{})[selection.groupId] = null;
        }
      } else if (!isSameAnswer) {
        documentOverrides.putIfAbsent(page, () => <String, BoardStroke?>{})[selection.groupId] = null;
      }
    }

    if (!isSameAnswer) {
      documentOverrides[selection.pageNumber]![selection.groupId] = SmartPenOvalAnnotation.fromSelection(
        selection: selection,
        pageSize: pageSize,
        color: Colors.red,
        width: strokeWidth,
      ).toBoardStroke();
    }

    _pruneTemporaryOverrides(documentOverrides);
    smartPenAnswerSelection = selection;
    _finishGroupEdit(selection, pages, before, persistedChanged: false);
  }

  void migrateSmartPenAnswerGroup(
    String provisionalId,
    String canonicalId, {
    required List<int> affectedPages,
  }) {
    if (provisionalId == canonicalId) return;
    final pageSet = affectedPages.toSet();
    final isCurrentSelection = smartPenAnswerSelection?.groupId == provisionalId;
    final pdfAnnotations = getPdfAnnotations();
    final key = getHistoryKey();

    final canonicalAlreadyHasAnswer = pageSet.any((page) {
      final saved = pdfAnnotations[page]?.any(
        (stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == canonicalId,
      ) ?? false;
      final temporary = temporarySmartPenOverrides[key]?[page]?[canonicalId]?.isSmartPenOval ?? false;
      return saved || temporary;
    });

    final overrides = temporarySmartPenOverrides[key];
    final provisionalHasSavedAnswer = pageSet.any(
      (page) => pdfAnnotations[page]?.any(
        (stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == provisionalId,
      ) ?? false,
    );
    final provisionalHasTemporaryOverride = pageSet.any(
      (page) => overrides?[page]?.containsKey(provisionalId) ?? false,
    );

    final replaceCanonical = isCurrentSelection &&
        canonicalAlreadyHasAnswer &&
        (provisionalHasSavedAnswer || provisionalHasTemporaryOverride);

    final history = smartPenUndo[key] ?? const [];
    final selectionHistoryEntry = replaceCanonical
        ? history.where((entry) => entry.groupId == provisionalId).fold<SmartPenHistoryEntry?>(
            null,
            (latest, entry) => latest == null || entry.sequence > latest.sequence ? entry : latest,
          )
        : null;

    final canonicalBefore = replaceCanonical
        ? _captureSmartPenGroups(pageSet.toList(), canonicalId)
        : const <int, SmartPenGroupSnapshot>{};
    final preserveCanonical = canonicalAlreadyHasAnswer && !isCurrentSelection;

    for (final page in pageSet) {
      final strokes = pdfAnnotations[page];
      if (strokes == null) continue;
      if (replaceCanonical && provisionalHasSavedAnswer) {
        strokes.removeWhere((stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == canonicalId);
      }
      if (preserveCanonical) {
        strokes.removeWhere((stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == provisionalId);
      } else {
        for (var i = 0; i < strokes.length; i++) {
          final stroke = strokes[i];
          if (stroke.isSmartPenOval && stroke.smartPenGroupId == provisionalId) {
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
          values.remove(canonicalId);
        } else if (replaceCanonical && provisionalHasTemporaryOverride) {
          final hasSavedCanonical = pdfAnnotations[page]?.any(
            (stroke) => stroke.isSmartPenOval && stroke.smartPenGroupId == canonicalId,
          ) ?? false;
          if (hasSavedCanonical) {
            values[canonicalId] = null;
          } else {
            values.remove(canonicalId);
          }
        }
        if (!values.containsKey(provisionalId)) continue;
        final value = values.remove(provisionalId);
        if (!preserveCanonical || !values.containsKey(canonicalId)) {
          values[canonicalId] = value == null ? null : _copySmartPenStroke(value, canonicalId);
        }
      }
    }

    for (final stacks in [smartPenUndo, smartPenRedo]) {
      for (final entry in stacks[key] ?? const []) {
        if (entry.groupId != provisionalId) continue;
        entry.groupId = canonicalId;
        for (final snapshots in [entry.before, entry.after]) {
          for (final snapshot in snapshots.values) {
            for (var i = 0; i < snapshot.persisted.length; i++) {
              snapshot.persisted[i] = _copySmartPenStroke(snapshot.persisted[i], canonicalId);
            }
            final temporary = snapshot.temporaryOverride;
            if (temporary != null) {
              snapshot.temporaryOverride = _copySmartPenStroke(temporary, canonicalId);
            }
          }
        }
      }
    }

    if (selectionHistoryEntry != null) {
      for (final page in pageSet) {
        selectionHistoryEntry.before.putIfAbsent(page, () => canonicalBefore[page]!.copy());
        selectionHistoryEntry.after[page] = _captureSmartPenGroup(page, canonicalId);
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

  bool undo() {
    final key = getHistoryKey();
    final pdfHistory = smartPenUndo[key];
    if (pdfHistory == null || pdfHistory.isEmpty) return false;

    final entry = pdfHistory.removeLast();
    applySmartPenHistory(entry, entry.before);
    entry.redoSequence = ++historySequence;
    smartPenRedo.putIfAbsent(key, () => []).add(entry);
    if (entry.persistedChanged) onMarkDirty?.call();
    onChanged();
    return true;
  }

  bool redo() {
    final key = getHistoryKey();
    final pdfHistory = smartPenRedo[key];
    if (pdfHistory == null || pdfHistory.isEmpty) return false;

    final entry = pdfHistory.removeLast();
    applySmartPenHistory(entry, entry.after);
    entry.sequence = ++historySequence;
    smartPenUndo.putIfAbsent(key, () => []).add(entry);
    if (entry.persistedChanged) onMarkDirty?.call();
    onChanged();
    return true;
  }

  void applySmartPenHistory(
    SmartPenHistoryEntry entry,
    Map<int, SmartPenGroupSnapshot> snapshots,
  ) {
    final key = getHistoryKey();
    final pdfAnnotations = getPdfAnnotations();
    final docOverrides = temporarySmartPenOverrides.putIfAbsent(
      key,
      () => <int, Map<String, BoardStroke?>>{},
    );

    for (final pageNumber in entry.affectedPages) {
      final snapshot = snapshots[pageNumber];
      if (snapshot == null) continue;
      final pageStrokes = pdfAnnotations[pageNumber];
      if (pageStrokes != null || snapshot.persisted.isNotEmpty) {
        final target = pageStrokes ?? <BoardStroke>[];
        target.removeWhere((s) => s.isSmartPenOval && s.smartPenGroupId == entry.groupId);
        target.addAll(snapshot.persisted.map((stroke) => stroke.copy()));
        if (target.isEmpty) {
          pdfAnnotations.remove(pageNumber);
        } else if (pageStrokes == null) {
          pdfAnnotations[pageNumber] = target;
        }
      }
      final pageOverrides = docOverrides.putIfAbsent(pageNumber, () => <String, BoardStroke?>{});
      if (snapshot.hasTemporaryOverride) {
        pageOverrides[entry.groupId] = snapshot.temporaryOverride?.copy();
      } else {
        pageOverrides.remove(entry.groupId);
      }
      if (pageOverrides.isEmpty) docOverrides.remove(pageNumber);
    }
    if (docOverrides.isEmpty) {
      temporarySmartPenOverrides.remove(key);
    }
  }

  void _finishGroupEdit(
    SmartPenAnswerSelection selection,
    List<int> pages,
    Map<int, SmartPenGroupSnapshot> before, {
    required bool persistedChanged,
  }) {
    final key = getHistoryKey();
    final after = _captureSmartPenGroups(pages, selection.groupId);
    smartPenUndo.putIfAbsent(key, () => []).add(
      SmartPenHistoryEntry(
        affectedPages: List.of(pages),
        groupId: selection.groupId,
        before: before,
        after: after,
        persistedChanged: persistedChanged,
        sequence: ++historySequence,
      ),
    );
    smartPenRedo[key]?.clear();
    onClearBoardRedo?.call();
    if (persistedChanged) onMarkDirty?.call();
    onChanged();
  }

  Map<int, SmartPenGroupSnapshot> _captureSmartPenGroups(List<int> pages, String groupId) =>
      {for (final page in pages) page: _captureSmartPenGroup(page, groupId)};

  SmartPenGroupSnapshot _captureSmartPenGroup(int pageNumber, String groupId) {
    final pdfAnnotations = getPdfAnnotations();
    final key = getHistoryKey();
    final persisted = (pdfAnnotations[pageNumber] ?? const <BoardStroke>[])
        .where((s) => s.isSmartPenOval && s.smartPenGroupId == groupId)
        .map((stroke) => stroke.copy())
        .toList();
    final overrides = temporarySmartPenOverrides[key]?[pageNumber];
    final hasOverride = overrides?.containsKey(groupId) ?? false;
    return SmartPenGroupSnapshot(
      persisted: persisted,
      hasTemporaryOverride: hasOverride,
      temporaryOverride: hasOverride ? overrides![groupId]?.copy() : null,
    );
  }

  bool _removeTemporaryOverride(int pageNumber, String groupId) {
    final key = getHistoryKey();
    final documentOverrides = temporarySmartPenOverrides[key];
    final pageOverrides = documentOverrides?[pageNumber];
    if (pageOverrides == null || !pageOverrides.containsKey(groupId)) return false;
    pageOverrides.remove(groupId);
    if (pageOverrides.isEmpty) documentOverrides!.remove(pageNumber);
    if (documentOverrides!.isEmpty) temporarySmartPenOverrides.remove(key);
    return true;
  }

  void _pruneTemporaryOverrides(Map<int, Map<String, BoardStroke?>> overrides) {
    overrides.removeWhere((_, groups) => groups.isEmpty);
    if (overrides.isEmpty) {
      temporarySmartPenOverrides.remove(getHistoryKey());
    }
  }

  List<int> _normalizeAffectedPages(int selectedPage, List<int>? pages) =>
      (pages ?? [selectedPage]).where((page) => page > 0).toSet().toList()..sort();

  BoardStroke _copySmartPenStroke(BoardStroke stroke, String groupId) => BoardStroke(
    stroke.color,
    stroke.width,
    List.of(stroke.points),
    isEraser: stroke.isEraser,
    rect: stroke.rect,
    isHollow: stroke.isHollow,
    smartPenGroupId: groupId,
    smartPenLabel: stroke.smartPenLabel,
  );
}
