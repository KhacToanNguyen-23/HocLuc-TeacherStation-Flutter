import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

/// A positioned text fragment in canonical page coordinates (points, origin at
/// the page's top-left). Fragments are expected to be word-level where the PDF
/// renderer exposes them that way.
@immutable
class SmartPenTextFragment {
  const SmartPenTextFragment({required this.text, required this.bounds});

  final String text;
  final Rect bounds;
}

@immutable
class SmartPenAnswerCandidate {
  const SmartPenAnswerCandidate({
    required this.label,
    required this.bounds,
    required this.groupId,
  });

  final String label;
  final Rect bounds;
  final String groupId;
}

/// Conservative text-and-geometry classifier for multiple-choice labels.
///
/// It first reconstructs visual rows and columns from positioned fragments,
/// then admits exact A-D marker tokens only when they begin a column and form
/// an unambiguous nearby group with other distinct markers.
class SmartPenAnswerClassifier {
  static final _labelPattern = RegExp(r'^\(?([A-D])[\.:)]?$');

  List<SmartPenAnswerCandidate> classify(List<SmartPenTextFragment> fragments) {
    final visible =
        fragments
            .where(
              (fragment) =>
                  fragment.text.trim().isNotEmpty &&
                  !fragment.bounds.isEmpty &&
                  _isFiniteRect(fragment.bounds),
            )
            .toList()
          ..sort((a, b) {
            final y = a.bounds.center.dy.compareTo(b.bounds.center.dy);
            return y != 0 ? y : a.bounds.left.compareTo(b.bounds.left);
          });
    if (visible.isEmpty) return const [];

    final typicalHeight = _median(
      visible
          .map((fragment) => fragment.bounds.height)
          .where((height) => height > 0),
      fallback: 10,
    );
    final rowTolerance = math.max(typicalHeight * 0.55, 1.0);
    final columnGap = math.max(typicalHeight * 4.0, 18.0);
    final rows = _groupRows(visible, rowTolerance);

    final markerRuns = <_MarkerRun>[];
    for (final row in rows) {
      final columns = _splitColumns(row, columnGap);
      for (var columnIndex = 0; columnIndex < columns.length; columnIndex++) {
        final column = columns[columnIndex];
        if (column.isEmpty) continue;

        // A label must be the first meaningful token in its visual column.
        final first = column.first;
        final match = _labelPattern.firstMatch(first.text.trim());
        if (match == null) continue;

        markerRuns.add(
          _MarkerRun(
            label: match.group(1)!,
            bounds: first.bounds,
            rowCenterY: first.bounds.center.dy,
            columnCenterX: first.bounds.center.dx,
          ),
        );
      }
    }

    if (markerRuns.length < 2) return const [];

    // Keep labels in the same answer column together. A large horizontal gap
    // separates page columns; answer choices in a vertical list remain aligned.
    markerRuns.sort((a, b) {
      final y = a.rowCenterY.compareTo(b.rowCenterY);
      return y != 0 ? y : a.columnCenterX.compareTo(b.columnCenterX);
    });
    final xTolerance = math.max(typicalHeight * 2.5, 12.0);
    final verticalGap = math.max(typicalHeight * 3.0, 28.0);
    final components = <List<_MarkerRun>>[];
    final activeComponents = <List<_MarkerRun>>[];
    for (final marker in markerRuns) {
      activeComponents.removeWhere(
        (candidate) =>
            marker.rowCenterY - candidate.last.rowCenterY > verticalGap,
      );
      List<_MarkerRun>? component;
      for (final candidate in activeComponents.reversed) {
        final last = candidate.last;
        if ((marker.columnCenterX - last.columnCenterX).abs() <= xTolerance &&
            marker.rowCenterY - last.rowCenterY <= verticalGap &&
            marker.rowCenterY >= last.rowCenterY) {
          component = candidate;
          break;
        }
      }
      if (component == null) {
        final newComponent = [marker];
        components.add(newComponent);
        activeComponents.add(newComponent);
      } else {
        component.add(marker);
      }
    }

    final candidates = <SmartPenAnswerCandidate>[];
    var groupNumber = 0;
    for (final component in components) {
      final labels = component.map((marker) => marker.label).toList();
      final distinct = labels.toSet();
      // Repeated labels inside a compact component are ambiguous (e.g. a
      // repeated heading); fail closed rather than retaining only some hits.
      if (distinct.length < 2 || distinct.length != labels.length) continue;

      final groupId = 'answer-group-${groupNumber++}';
      candidates.addAll(
        component.map(
          (marker) => SmartPenAnswerCandidate(
            label: marker.label,
            bounds: marker.bounds,
            groupId: groupId,
          ),
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  static List<List<SmartPenTextFragment>> _groupRows(
    List<SmartPenTextFragment> fragments,
    double tolerance,
  ) {
    final rows = <_VisualTextRow>[];
    for (final fragment in fragments) {
      _VisualTextRow? row;
      for (final candidate in rows.reversed) {
        final verticalOffset = fragment.bounds.center.dy - candidate.centerY;
        if (verticalOffset > tolerance) break;
        if (verticalOffset >= -tolerance) {
          row = candidate;
          break;
        }
      }
      if (row == null) {
        rows.add(_VisualTextRow(fragment));
      } else {
        row.add(fragment);
      }
    }
    for (final row in rows) {
      row.fragments.sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    }
    return rows.map((row) => row.fragments).toList();
  }

  static List<List<SmartPenTextFragment>> _splitColumns(
    List<SmartPenTextFragment> row,
    double gapThreshold,
  ) {
    final columns = <List<SmartPenTextFragment>>[];
    for (final fragment in row) {
      if (columns.isEmpty ||
          fragment.bounds.left - columns.last.last.bounds.right >
              gapThreshold) {
        columns.add([fragment]);
      } else {
        columns.last.add(fragment);
      }
    }
    return columns;
  }

  static double _median(Iterable<double> values, {required double fallback}) {
    final sorted = values.toList()..sort();
    if (sorted.isEmpty) return fallback;
    final middle = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[middle];
    return (sorted[middle - 1] + sorted[middle]) / 2;
  }

  static bool _isFiniteRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
}

@immutable
class SmartPenPageIndex {
  SmartPenPageIndex.fromCandidates({
    required this.documentGeneration,
    required this.pageNumber,
    required this.pageSize,
    required List<SmartPenAnswerCandidate> candidates,
  }) : candidates = List.unmodifiable(candidates);

  factory SmartPenPageIndex.build({
    required int documentGeneration,
    required int pageNumber,
    required Size pageSize,
    required List<SmartPenTextFragment> fragments,
  }) => SmartPenPageIndex.fromCandidates(
    documentGeneration: documentGeneration,
    pageNumber: pageNumber,
    pageSize: pageSize,
    candidates: SmartPenAnswerClassifier().classify(fragments),
  );

  final int documentGeneration;
  final int pageNumber;
  final Size pageSize;
  final List<SmartPenAnswerCandidate> candidates;

  /// Queries a point in canonical page coordinates. The viewport tolerance is
  /// converted to page units with the displayed logical-pixels-per-page-unit
  /// scale. Multiple matches are rejected as ambiguous.
  SmartPenAnswerCandidate? hitTest(
    Offset pagePoint, {
    required double logicalPixelTolerance,
    required double zoomScale,
  }) {
    if (!pagePoint.dx.isFinite ||
        !pagePoint.dy.isFinite ||
        !zoomScale.isFinite ||
        zoomScale <= 0 ||
        logicalPixelTolerance < 0) {
      return null;
    }
    final tolerance = logicalPixelTolerance / zoomScale;
    SmartPenAnswerCandidate? match;
    for (final candidate in candidates) {
      final hitRect = candidate.bounds.inflate(tolerance);
      if (!hitRect.contains(pagePoint)) continue;
      if (match != null) return null;
      match = candidate;
    }
    return match;
  }
}

enum SmartPenPageIndexStatus { notStarted, building, ready, empty, failed }

@immutable
class SmartPenPendingTap {
  const SmartPenPendingTap({
    required this.pageNumber,
    required this.documentGeneration,
    required this.pagePoint,
  });

  final int pageNumber;
  final int documentGeneration;
  final Offset pagePoint;
}

/// Bounded FIFO retaining taps against the page and document they came from.
class SmartPenTapQueue {
  SmartPenTapQueue({required this.maxLength}) : assert(maxLength > 0);

  final int maxLength;
  final List<SmartPenPendingTap> _taps = [];

  int get length => _taps.length;

  bool enqueue(SmartPenPendingTap tap) {
    if (_taps.length >= maxLength) return false;
    _taps.add(tap);
    return true;
  }

  List<SmartPenPendingTap> takeForPage(int pageNumber, int generation) {
    final matching = <SmartPenPendingTap>[];
    _taps.removeWhere((tap) {
      if (tap.pageNumber == pageNumber &&
          tap.documentGeneration == generation) {
        matching.add(tap);
        return true;
      }
      return false;
    });
    return List.unmodifiable(matching);
  }

  void clear() => _taps.clear();
}

/// Serializes page extraction and keeps the visible page ahead of nearby work.
/// The callback should catch/report page-specific extraction failures itself;
/// a failure never stops later pages from being scheduled.
class SmartPenPageIndexScheduler {
  SmartPenPageIndexScheduler({
    required this.documentGeneration,
    required this.pageCount,
    required this.buildPageIndex,
    this.nearbyPageRadius = 2,
  }) : assert(pageCount >= 0),
       assert(nearbyPageRadius >= 0);

  final int documentGeneration;
  final int pageCount;
  final Future<void> Function(int pageNumber, int generation) buildPageIndex;
  final int nearbyPageRadius;

  final List<int> _pending = [];
  final Set<int> _known = {};
  final Set<int> _finished = {};
  Future<void>? _drainFuture;
  int? _runningPage;

  void requestPage(int pageNumber) {
    _enqueue(pageNumber);
    _startDrain();
  }

  void setVisiblePage(int pageNumber) {
    if (!_isValid(pageNumber)) return;
    final prioritizedPages = <int>[];
    void prioritize(int page) {
      if (!_isValid(page) || _finished.contains(page) || page == _runningPage) {
        return;
      }
      _known.add(page);
      _pending.remove(page);
      prioritizedPages.add(page);
    }

    prioritize(pageNumber);
    for (var distance = 1; distance <= nearbyPageRadius; distance++) {
      prioritize(pageNumber - distance);
      prioritize(pageNumber + distance);
    }
    _pending.insertAll(0, prioritizedPages);
    _startDrain();
  }

  bool _isValid(int pageNumber) => pageNumber >= 1 && pageNumber <= pageCount;

  void _enqueue(int pageNumber, {bool first = false}) {
    if (!_isValid(pageNumber) ||
        _known.contains(pageNumber) ||
        _finished.contains(pageNumber)) {
      if (first && _pending.remove(pageNumber)) _pending.insert(0, pageNumber);
      return;
    }
    _known.add(pageNumber);
    if (first) {
      _pending.insert(0, pageNumber);
    } else {
      _pending.add(pageNumber);
    }
  }

  void _startDrain() {
    if (_drainFuture != null || _pending.isEmpty) return;
    _drainFuture = _drain().whenComplete(() {
      _drainFuture = null;
      if (_pending.isNotEmpty) _startDrain();
    });
  }

  Future<void> _drain() async {
    while (_pending.isNotEmpty) {
      final pageNumber = _pending.removeAt(0);
      _runningPage = pageNumber;
      try {
        await buildPageIndex(pageNumber, documentGeneration);
      } catch (_) {
        // A failed page is terminal for this scheduler; continue nearby work.
      } finally {
        _finished.add(pageNumber);
        _runningPage = null;
      }
    }
  }

  Future<void> whenIdle() async {
    while (_drainFuture != null || _pending.isNotEmpty) {
      _startDrain();
      await _drainFuture;
    }
  }
}

/// Per-document-generation lifecycle store. Starting a new generation drops
/// every prior page result, and asynchronous completions from older documents
/// are ignored.
class SmartPenPageIndexStore {
  int? _generation;
  final Map<int, SmartPenPageIndexStatus> _statuses = {};
  final Map<int, SmartPenPageIndex> _indices = {};

  int? get generation => _generation;

  void beginGeneration(int generation) {
    _generation = generation;
    _statuses.clear();
    _indices.clear();
  }

  SmartPenPageIndexStatus statusFor(int pageNumber) =>
      _statuses[pageNumber] ?? SmartPenPageIndexStatus.notStarted;

  SmartPenPageIndex? indexFor(int pageNumber) => _indices[pageNumber];

  bool beginPage(int pageNumber) {
    if (_generation == null || pageNumber < 1) return false;
    if (statusFor(pageNumber) == SmartPenPageIndexStatus.building ||
        statusFor(pageNumber) == SmartPenPageIndexStatus.ready) {
      return false;
    }
    _statuses[pageNumber] = SmartPenPageIndexStatus.building;
    return true;
  }

  bool completePage(SmartPenPageIndex index) {
    if (index.documentGeneration != _generation ||
        statusFor(index.pageNumber) != SmartPenPageIndexStatus.building) {
      return false;
    }
    _indices[index.pageNumber] = index;
    _statuses[index.pageNumber] = SmartPenPageIndexStatus.ready;
    return true;
  }

  bool markTextless(int pageNumber) =>
      _setTerminalStatus(pageNumber, SmartPenPageIndexStatus.empty);

  bool failPage(int pageNumber) =>
      _setTerminalStatus(pageNumber, SmartPenPageIndexStatus.failed);

  bool _setTerminalStatus(int pageNumber, SmartPenPageIndexStatus status) {
    if (_generation == null || pageNumber < 1) return false;
    _indices.remove(pageNumber);
    _statuses[pageNumber] = status;
    return true;
  }
}

/// Extracts word-level text fragments after waiting for the latest loaded page
/// instance. PdfRect uses a bottom-left origin; this adapter maps it to a
/// top-left-origin canonical point space used by the canvas.
class SmartPenPdfTextExtractor {
  /// pdfrx exposes width/height in the effective displayed page orientation.
  static Size canonicalPageSize(PdfPage page) => Size(page.width, page.height);

  Future<List<SmartPenTextFragment>> extract(PdfPage sourcePage) async {
    final page = await sourcePage.ensureLoaded();
    final text = await page.loadStructuredText(ensureLoaded: true);
    final pageHeight = canonicalPageSize(page).height;
    return List.unmodifiable(
      text.fragments.where((fragment) => fragment.text.trim().isNotEmpty).map((
        fragment,
      ) {
        final pdfRect = fragment.bounds;
        if (pdfRect.isEmpty) return null;
        final rect = pdfRect.rotate(page.rotation.index, page);
        return SmartPenTextFragment(
          text: fragment.text,
          bounds: Rect.fromLTRB(
            rect.left,
            pageHeight - rect.top,
            rect.right,
            pageHeight - rect.bottom,
          ),
        );
      }).whereType<SmartPenTextFragment>(),
    );
  }
}

class _MarkerRun {
  const _MarkerRun({
    required this.label,
    required this.bounds,
    required this.rowCenterY,
    required this.columnCenterX,
  });

  final String label;
  final Rect bounds;
  final double rowCenterY;
  final double columnCenterX;
}

class _VisualTextRow {
  _VisualTextRow(SmartPenTextFragment first)
    : fragments = [first],
      _bounds = first.bounds;

  final List<SmartPenTextFragment> fragments;
  Rect _bounds;

  double get centerY => _bounds.center.dy;

  void add(SmartPenTextFragment fragment) {
    fragments.add(fragment);
    _bounds = _bounds.expandToInclude(fragment.bounds);
  }
}
