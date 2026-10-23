import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

part 'smart_pen_answer_classifier.dart';

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

enum SmartPenPageEdge { top, bottom }

enum SmartPenDebugDecision { raw, accepted, partial, rejected }

@immutable
class SmartPenDebugFragment {
  const SmartPenDebugFragment({
    required this.fragment,
    required this.decision,
    required this.reasonCode,
  });

  final SmartPenTextFragment fragment;
  final SmartPenDebugDecision decision;
  final String reasonCode;
}

@immutable
class SmartPenPartialAnswerGroup {
  SmartPenPartialAnswerGroup({
    required this.pageNumber,
    required this.edge,
    required List<SmartPenAnswerCandidate> candidates,
    this.hasQuestionHeadingEvidence = false,
  }) : candidates = List.unmodifiable(candidates);

  final int pageNumber;
  final SmartPenPageEdge edge;
  final List<SmartPenAnswerCandidate> candidates;
  final bool hasQuestionHeadingEvidence;
}

/// Stable, generation-scoped IDs for page-local groups and conservative links
/// between complementary answer fragments at adjacent page edges.
class SmartPenAnswerGroupMap {
  SmartPenAnswerGroupMap._(
    this.generation,
    this._canonicalIds,
    this._candidatesByPage,
  );

  final int generation;
  final Map<String, String> _canonicalIds;
  final Map<int, List<SmartPenAnswerCandidate>> _candidatesByPage;

  String canonicalGroupIdFor(
    int pageNumber,
    SmartPenAnswerCandidate candidate,
  ) {
    final key = _key(pageNumber, candidate.groupId);
    return _canonicalIds[key] ?? candidate.groupId;
  }

  List<SmartPenAnswerCandidate> candidatesForPage(int pageNumber) =>
      _candidatesByPage[pageNumber] ?? const [];

  static String _key(int pageNumber, String localId) => '$pageNumber::$localId';
}

class SmartPenDocumentAnswerLinker {
  const SmartPenDocumentAnswerLinker._();

  static SmartPenAnswerGroupMap resolve({
    required int generation,
    required Map<int, SmartPenPageIndex> indexes,
    SmartPenAnswerGroupMap? previous,
    int? changedPage,
  }) {
    final incremental =
        previous != null &&
        previous.generation == generation &&
        changedPage != null;
    final canonical = incremental
        ? Map<String, String>.of(previous._canonicalIds)
        : <String, String>{};
    final groups = <(int, SmartPenPartialAnswerGroup)>[];
    final recomputePages = incremental
        ? {changedPage - 1, changedPage, changedPage + 1}
        : indexes.keys.toSet();
    for (final entry in indexes.entries) {
      if (entry.value.documentGeneration != generation ||
          entry.key != entry.value.pageNumber) {
        continue;
      }
      for (final partial in entry.value.partialGroups) {
        final isAffectedEdge =
            !incremental ||
            (entry.key == changedPage - 1 &&
                partial.edge == SmartPenPageEdge.bottom) ||
            (entry.key == changedPage &&
                (partial.edge == SmartPenPageEdge.top ||
                    partial.edge == SmartPenPageEdge.bottom)) ||
            (entry.key == changedPage + 1 &&
                partial.edge == SmartPenPageEdge.top);
        if (isAffectedEdge) {
          groups.add((entry.key, partial));
          for (final candidate in partial.candidates) {
            canonical.remove(
              SmartPenAnswerGroupMap._key(entry.key, candidate.groupId),
            );
          }
        }
      }
      if (!incremental || entry.key == changedPage) {
        for (final candidate in entry.value.candidates) {
          canonical[SmartPenAnswerGroupMap._key(entry.key, candidate.groupId)] =
              'answer-g$generation-p${entry.key}-${candidate.groupId}';
        }
      }
    }
    groups.sort((a, b) => a.$1.compareTo(b.$1));
    final linked = <int>{};
    for (var i = 0; i < groups.length; i++) {
      if (linked.contains(i)) continue;
      final (page, lower) = groups[i];
      if (lower.edge != SmartPenPageEdge.bottom ||
          lower.hasQuestionHeadingEvidence ||
          !_hasComplementaryLabels(lower.candidates, {'A', 'B'})) {
        continue;
      }
      final options = <int>[];
      for (var j = 0; j < groups.length; j++) {
        if (i == j || linked.contains(j)) continue;
        final (otherPage, upper) = groups[j];
        if (otherPage != page + 1 ||
            upper.edge != SmartPenPageEdge.top ||
            upper.hasQuestionHeadingEvidence ||
            !_hasComplementaryLabels(upper.candidates, {'C', 'D'}) ||
            !_compatibleGeometry(
              lower.candidates,
              upper.candidates,
              indexes[page]!.pageSize,
              indexes[otherPage]!.pageSize,
            )) {
          continue;
        }
        options.add(j);
      }
      if (options.length != 1) continue;
      final j = options.single;
      final (otherPage, upper) = groups[j];
      final competingLower = groups.where(
        (group) =>
            group.$1 == otherPage - 1 &&
            group.$2.edge == SmartPenPageEdge.bottom &&
            !group.$2.hasQuestionHeadingEvidence &&
            _hasComplementaryLabels(group.$2.candidates, {'A', 'B'}) &&
            _compatibleGeometry(
              group.$2.candidates,
              upper.candidates,
              indexes[group.$1]!.pageSize,
              indexes[otherPage]!.pageSize,
            ),
      );
      if (competingLower.length != 1) continue;
      final id =
          'answer-g$generation-p$page-${lower.candidates.first.groupId}-p$otherPage-${upper.candidates.first.groupId}';
      for (final candidate in lower.candidates) {
        canonical[SmartPenAnswerGroupMap._key(page, candidate.groupId)] = id;
      }
      for (final candidate in upper.candidates) {
        canonical[SmartPenAnswerGroupMap._key(otherPage, candidate.groupId)] =
            id;
      }
      linked
        ..add(i)
        ..add(j);
    }
    final byPage = incremental
        ? Map<int, List<SmartPenAnswerCandidate>>.of(previous._candidatesByPage)
        : <int, List<SmartPenAnswerCandidate>>{};
    for (final entry in indexes.entries) {
      if (entry.value.documentGeneration != generation ||
          !recomputePages.contains(entry.key)) {
        continue;
      }
      final all = <SmartPenAnswerCandidate>[
        ...entry.value.candidates,
        ...entry.value.partialGroups.expand((group) => group.candidates),
      ];
      final seen = <String>{};
      byPage[entry.key] = [
        for (final candidate in all)
          if (seen.add(
            '${candidate.groupId}:${candidate.label}:${candidate.bounds}',
          ))
            SmartPenAnswerCandidate(
              label: candidate.label,
              bounds: candidate.bounds,
              groupId:
                  canonical[SmartPenAnswerGroupMap._key(
                    entry.key,
                    candidate.groupId,
                  )] ??
                  'answer-g$generation-p${entry.key}-${candidate.groupId}',
            ),
      ];
    }
    return SmartPenAnswerGroupMap._(
      generation,
      Map.unmodifiable(canonical),
      Map.unmodifiable(byPage),
    );
  }

  static bool _hasComplementaryLabels(
    List<SmartPenAnswerCandidate> candidates,
    Set<String> expected,
  ) {
    final labels = candidates.map((candidate) => candidate.label).toList();
    final orderedExpected = expected.toList();
    return labels.length == 2 &&
        labels[0] == orderedExpected[0] &&
        labels[1] == orderedExpected[1];
  }

  static bool _compatibleGeometry(
    List<SmartPenAnswerCandidate> lower,
    List<SmartPenAnswerCandidate> upper,
    Size lowerSize,
    Size upperSize,
  ) {
    double centerX(List<SmartPenAnswerCandidate> candidates, Size size) =>
        candidates
            .map((c) => c.bounds.center.dx / size.width)
            .reduce((a, b) => a + b) /
        candidates.length;
    final lowerX = centerX(lower, lowerSize);
    final upperX = centerX(upper, upperSize);
    return (lowerX - upperX).abs() <= 0.12;
  }
}

@immutable
class SmartPenPageIndex {
  SmartPenPageIndex.fromCandidates({
    required this.documentGeneration,
    required this.pageNumber,
    required this.pageSize,
    required List<SmartPenAnswerCandidate> candidates,
    List<SmartPenPartialAnswerGroup> partialGroups = const [],
    List<SmartPenDebugFragment> debugFragments = const [],
  }) : candidates = List.unmodifiable(candidates),
       partialGroups = List.unmodifiable(partialGroups),
       debugFragments = List.unmodifiable(debugFragments);

  factory SmartPenPageIndex.build({
    required int documentGeneration,
    required int pageNumber,
    required Size pageSize,
    required List<SmartPenTextFragment> fragments,
    bool includeDebugData = false,
  }) {
    final classification = SmartPenAnswerClassifier().analyze(
      fragments,
      pageSize: pageSize,
      pageNumber: pageNumber,
      documentGeneration: documentGeneration,
      includeDebugData: includeDebugData,
    );
    return SmartPenPageIndex.fromCandidates(
      documentGeneration: documentGeneration,
      pageNumber: pageNumber,
      pageSize: pageSize,
      candidates: classification.candidates,
      partialGroups: classification.partialGroups,
      debugFragments: classification.debugFragments,
    );
  }

  final int documentGeneration;
  final int pageNumber;
  final Size pageSize;
  final List<SmartPenAnswerCandidate> candidates;
  final List<SmartPenPartialAnswerGroup> partialGroups;
  final List<SmartPenDebugFragment> debugFragments;

  /// Queries a point in canonical page coordinates. The viewport tolerance is
  /// converted to page units with the displayed logical-pixels-per-page-unit
  /// scale. Multiple matches are rejected as ambiguous.
  SmartPenAnswerCandidate? hitTest(
    Offset pagePoint, {
    required double logicalPixelTolerance,
    required double zoomScale,
    List<SmartPenAnswerCandidate>? candidates,
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
    for (final candidate in candidates ?? this.candidates) {
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

  List<SmartPenPendingTap> takeForGeneration(int generation) {
    final matching = _taps
        .where((tap) => tap.documentGeneration == generation)
        .toList(growable: false);
    _taps.removeWhere((tap) => tap.documentGeneration == generation);
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

