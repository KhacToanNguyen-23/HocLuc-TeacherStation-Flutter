part of 'smart_pen_answer_index.dart';

@immutable
class SmartPenAnswerClassification {
  SmartPenAnswerClassification({
    required List<SmartPenAnswerCandidate> candidates,
    required List<SmartPenPartialAnswerGroup> partialGroups,
    List<SmartPenDebugFragment> debugFragments = const [],
  }) : candidates = List.unmodifiable(candidates),
       partialGroups = List.unmodifiable(partialGroups),
       debugFragments = List.unmodifiable(debugFragments);

  final List<SmartPenAnswerCandidate> candidates;
  final List<SmartPenPartialAnswerGroup> partialGroups;
  final List<SmartPenDebugFragment> debugFragments;
}

/// Conservative text-and-geometry classifier for multiple-choice labels.
///
/// It first reconstructs visual rows and columns from positioned fragments,
/// then admits exact A-D marker tokens only when they begin a column and form
/// an unambiguous nearby group with other distinct markers. Repeated fragments
/// following a diagonal path are excluded as likely watermarks.
class SmartPenAnswerClassifier {
  static final _labelPattern = RegExp(r'^[\(\[]?([A-D])[\.\:\uFF1A\)\]]?$');
  static final _attachedLabelPattern = RegExp(
    r'^([\(\[]?[A-D][\.\:\uFF1A\)\]])(.+)$',
  );

  List<SmartPenAnswerCandidate> classify(
    List<SmartPenTextFragment> fragments,
  ) => analyze(fragments).candidates;

  SmartPenAnswerClassification analyze(
    List<SmartPenTextFragment> fragments, {
    Size? pageSize,
    int pageNumber = 1,
    int documentGeneration = 0,
    bool includeDebugData = false,
  }) {
    final validFragments = fragments
        .where(
          (fragment) =>
              fragment.text.trim().isNotEmpty &&
              !fragment.bounds.isEmpty &&
              _isFiniteRect(fragment.bounds),
        )
        .toList();
    if (validFragments.isEmpty) {
      return SmartPenAnswerClassification(
        candidates: const [],
        partialGroups: const [],
      );
    }

    final typicalHeight = _median(
      validFragments
          .map((fragment) => fragment.bounds.height)
          .where((height) => height > 0),
      fallback: 10,
    );
    final watermarkTexts = _diagonalWatermarkTexts(
      validFragments,
      typicalHeight,
    );
    final visible =
        validFragments
            .where(
              (fragment) =>
                  !watermarkTexts.contains(_normalizedText(fragment.text)),
            )
            .expand(
              (fragment) => _splitAttachedMarkerFragment(
                fragment,
                typicalHeight: typicalHeight,
              ),
            )
            .toList()
          ..sort((a, b) {
            final y = a.bounds.center.dy.compareTo(b.bounds.center.dy);
            return y != 0 ? y : a.bounds.left.compareTo(b.bounds.left);
          });
    if (visible.isEmpty) {
      return SmartPenAnswerClassification(
        candidates: const [],
        partialGroups: const [],
        debugFragments: includeDebugData
            ? _buildDebugFragments(
                validFragments,
                const [],
                const [],
                watermarkTexts,
                typicalHeight,
              )
            : const [],
      );
    }
    final rowTolerance = math.max(typicalHeight * 0.55, 1.0);
    // Keep a marker and its formula/text fragment in one visual column even
    // when the PDF places a wide gap between them. Distant answer columns are
    // still separated by the larger gap between the complete fragments.
    final columnGap = math.max(typicalHeight * 6.5, 18.0);
    final xTolerance = math.max(typicalHeight * 2.5, 12.0);
    final verticalGap = math.max(typicalHeight * 4.2, 34.0);
    final edgeMargin = pageSize == null
        ? 0.0
        : math.max(pageSize.height * 0.08, typicalHeight * 4).toDouble();
    final rows = _groupRows(visible, rowTolerance);

    final markerRuns = <_MarkerRun>[];
    final inlineAnswerRuns = <List<_MarkerRun>>[];
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      final inlineRow = _inlineOptionMarkers(
        row,
        rowTolerance: rowTolerance,
        typicalHeight: typicalHeight,
      );
      final bareInlineLabelCount = row
          .where(
            (fragment) => RegExp(r'^[A-D]$').hasMatch(fragment.text.trim()),
          )
          .length;
      final columns = _splitColumns(row, columnGap);
      final rowMarkers = <_MarkerRun>[];
      for (final column in columns) {
        if (column.isEmpty) continue;

        // A marker must start the column after likely diagonal watermark text
        // has been removed, with option text immediately to its right.
        final first = column.first;
        if (inlineRow == null &&
            bareInlineLabelCount >= 2 &&
            RegExp(r'^[A-D]$').hasMatch(first.text.trim())) {
          continue;
        }
        final match = _labelPattern.firstMatch(first.text.trim());
        if (match == null) continue;
        final firstIndex = row.indexOf(first);
        final precedingProse = row
            .take(firstIndex)
            .where(
              (fragment) => !RegExp(r'^\d+\.?$').hasMatch(fragment.text.trim()),
            )
            .isNotEmpty;
        final hasPriorAnswerContext =
            rowMarkers.isNotEmpty ||
            markerRuns.any(
              (marker) =>
                  (marker.rowCenterY - first.bounds.center.dy).abs() <=
                      verticalGap &&
                  (marker.columnCenterX - first.bounds.center.dx).abs() <=
                      xTolerance,
            );
        if ((precedingProse && !hasPriorAnswerContext) ||
            !_hasNearbyOptionText(
              row,
              firstIndex,
              rowTolerance: rowTolerance,
              typicalHeight: typicalHeight,
            )) {
          continue;
        }
        final marker = _MarkerRun(
          label: match.group(1)!,
          bounds: first.bounds,
          rowCenterY: first.bounds.center.dy,
          columnCenterX: first.bounds.center.dx,
        );
        markerRuns.add(marker);
        rowMarkers.add(marker);
      }
      final edgePartialRow = inlineRow == null
          ? _edgePartialOptionRow(
              rowMarkers,
              pageSize: pageSize,
              edgeMargin: edgeMargin,
            )
          : null;
      if (inlineRow != null) {
        inlineAnswerRuns.add(inlineRow);
      } else if (edgePartialRow != null) {
        inlineAnswerRuns.add(edgePartialRow);
        markerRuns.removeWhere(edgePartialRow.contains);
      } else {
        final correctionRow = _inlineCorrectionMarkers(
          rows,
          rowIndex,
          rowTolerance: rowTolerance,
          typicalHeight: typicalHeight,
        );
        if (correctionRow != null) {
          inlineAnswerRuns.add(correctionRow);
        }
      }
    }

    if (markerRuns.isEmpty && inlineAnswerRuns.isEmpty) {
      return SmartPenAnswerClassification(
        candidates: const [],
        partialGroups: const [],
        debugFragments: includeDebugData
            ? _buildDebugFragments(
                validFragments,
                const [],
                const [],
                watermarkTexts,
                typicalHeight,
              )
            : const [],
      );
    }

    // Keep labels in the same answer column together. A large horizontal gap
    // separates page columns; answer choices in a vertical list remain aligned.
    markerRuns.sort((a, b) {
      final y = a.rowCenterY.compareTo(b.rowCenterY);
      return y != 0 ? y : a.columnCenterX.compareTo(b.columnCenterX);
    });
    final inlineMarkers = inlineAnswerRuns.expand((run) => run).toList();
    final verticalMarkerRuns = markerRuns
        .where(
          (marker) => !inlineMarkers.any(
            (inlineMarker) =>
                inlineMarker.label == marker.label &&
                inlineMarker.bounds == marker.bounds,
          ),
        )
        .toList();
    final components = <List<_MarkerRun>>[];
    final activeComponents = <List<_MarkerRun>>[];
    for (final marker in verticalMarkerRuns) {
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

    // A new A (or repeated/out-of-order marker) in the same vertical column
    // starts a new question. Without this boundary, nearby questions can be
    // treated as one answer group and selecting the lower question removes
    // the upper question's selection.
    final questionRuns = <List<_MarkerRun>>[...inlineAnswerRuns];
    for (final component in components) {
      var run = <_MarkerRun>[];
      var previousRank = -1;
      for (final marker in component) {
        final rank = _labelRank(marker.label);
        final previous = run.isEmpty ? null : run.last;
        final runLabels = run.map((item) => item.label).toList();
        final restartsTwoColumnQuestion =
            runLabels.length == 2 &&
            ((runLabels[0] == 'A' &&
                    runLabels[1] == 'C' &&
                    marker.label == 'A') ||
                (runLabels[0] == 'B' &&
                    runLabels[1] == 'D' &&
                    marker.label == 'B'));
        final questionBreak =
            previous != null &&
            rank <= previousRank &&
            (restartsTwoColumnQuestion ||
                rank == 0 && previousRank == 3 ||
                marker.rowCenterY - previous.rowCenterY > typicalHeight * 2.7);
        if (questionBreak) {
          questionRuns.add(run);
          run = <_MarkerRun>[];
        }
        run.add(marker);
        previousRank = rank;
      }
      if (run.isNotEmpty) questionRuns.add(run);
    }

    // In a two-column question, A/C are commonly in the left column and B/D
    // in the right column. Pair those aligned option rows so all four labels
    // share one selection group. Independent question columns (A-D beside
    // another A-D) remain separate.
    final mergedRuns = <List<_MarkerRun>>[];
    final consumedRuns = <int>{};
    for (var i = 0; i < questionRuns.length; i++) {
      if (consumedRuns.contains(i)) continue;
      List<_MarkerRun>? paired;
      for (var j = i + 1; j < questionRuns.length; j++) {
        if (consumedRuns.contains(j)) continue;
        if (_isTwoColumnQuestionPair(
          questionRuns[i],
          questionRuns[j],
          rowTolerance: rowTolerance,
          xTolerance: xTolerance,
        )) {
          consumedRuns.add(j);
          paired = [...questionRuns[i], ...questionRuns[j]];
          break;
        }
      }
      mergedRuns.add(paired ?? questionRuns[i]);
    }

    final candidates = <SmartPenAnswerCandidate>[];
    final partialGroups = <SmartPenPartialAnswerGroup>[];
    var groupNumber = 0;
    var partialGroupNumber = 0;
    for (final component in mergedRuns) {
      final labels = component.map((marker) => marker.label).toList();
      final distinct = labels.toSet();
      // Repeated labels inside a compact component are ambiguous (e.g. a
      // repeated heading); fail closed rather than retaining only some hits.
      final groupId = 'answer-group-${groupNumber++}';
      final groupCandidates = component
          .map(
            (marker) => SmartPenAnswerCandidate(
              label: marker.label,
              bounds: marker.bounds,
              groupId: groupId,
            ),
          )
          .toList();
      final isUnambiguous = distinct.length == labels.length;
      if (!isUnambiguous) continue;

      final firstCenterY = component
          .map((marker) => marker.rowCenterY)
          .reduce(math.min);
      final lastCenterY = component
          .map((marker) => marker.rowCenterY)
          .reduce(math.max);
      final edge = pageSize == null
          ? null
          : firstCenterY <= edgeMargin
          ? SmartPenPageEdge.top
          : pageSize.height - lastCenterY <= edgeMargin
          ? SmartPenPageEdge.bottom
          : null;
      final completeAnswerSet =
          distinct.length == 4 && distinct.containsAll({'A', 'B', 'C', 'D'});
      // Edge fragments may belong to an answer group continuing on the next
      // page. Keep them available to the linker, but don't make incomplete
      // groups tappable until there is enough evidence to classify the page.
      if (distinct.length >= 2 && (edge == null || completeAnswerSet)) {
        candidates.addAll(groupCandidates);
      }
      if (edge != null && distinct.length < 4) {
        final partialCandidates = groupCandidates
            .map(
              (candidate) => SmartPenAnswerCandidate(
                label: candidate.label,
                bounds: candidate.bounds,
                groupId:
                    'partial-g$documentGeneration-p$pageNumber-$partialGroupNumber',
              ),
            )
            .toList();
        partialGroups.add(
          SmartPenPartialAnswerGroup(
            pageNumber: pageNumber,
            edge: edge,
            candidates: partialCandidates,
            hasQuestionHeadingEvidence: _hasNearbyQuestionHeading(
              visible,
              component,
              typicalHeight: typicalHeight,
              edgeMargin: edgeMargin,
            ),
          ),
        );
        partialGroupNumber++;
      }
    }
    return SmartPenAnswerClassification(
      candidates: candidates,
      partialGroups: partialGroups,
      debugFragments: includeDebugData
          ? _buildDebugFragments(
              validFragments,
              candidates,
              partialGroups,
              watermarkTexts,
              typicalHeight,
            )
          : const [],
    );
  }

  List<SmartPenDebugFragment> _buildDebugFragments(
    List<SmartPenTextFragment> source,
    List<SmartPenAnswerCandidate> candidates,
    List<SmartPenPartialAnswerGroup> partialGroups,
    Set<String> watermarkTexts,
    double typicalHeight,
  ) {
    final acceptedBounds = candidates
        .map((candidate) => candidate.bounds)
        .toSet();
    final partialBounds = partialGroups
        .expand((group) => group.candidates)
        .map((candidate) => candidate.bounds)
        .toSet();
    return [
      for (final original in source)
        () {
          final parts = _splitAttachedMarkerFragment(
            original,
            typicalHeight: typicalHeight,
          ).toList();
          final accepted = parts.any(
            (part) => acceptedBounds.contains(part.bounds),
          );
          final partial = parts.any(
            (part) => partialBounds.contains(part.bounds),
          );
          final markerLike = parts.any(
            (part) =>
                _labelPattern.hasMatch(part.text.trim()) ||
                _attachedLabelPattern.hasMatch(part.text.trim()),
          );
          final isWatermark = watermarkTexts.contains(
            _normalizedText(original.text),
          );
          return SmartPenDebugFragment(
            fragment: original,
            decision: accepted
                ? SmartPenDebugDecision.accepted
                : partial
                ? SmartPenDebugDecision.partial
                : markerLike
                ? SmartPenDebugDecision.rejected
                : SmartPenDebugDecision.raw,
            reasonCode: accepted
                ? 'candidate_accepted'
                : partial
                ? 'edge_partial'
                : markerLike
                ? isWatermark
                      ? 'diagonal_watermark'
                      : 'classifier_filter'
                : 'text_fragment',
          );
        }(),
    ];
  }

  static Iterable<SmartPenTextFragment> _splitAttachedMarkerFragment(
    SmartPenTextFragment fragment, {
    required double typicalHeight,
  }) sync* {
    final text = fragment.text.trim();
    final match = _attachedLabelPattern.firstMatch(text);
    if (match == null || match.group(2)!.trim().isEmpty) {
      yield fragment;
      return;
    }

    final markerText = match.group(1)!;
    final remainingText = match.group(2)!.trimLeft();
    final leadingSpaceCount = match.group(2)!.length - remainingText.length;
    final markerLength = markerText.length;
    final remainingLength = match.group(2)!.length - leadingSpaceCount;
    final totalLength = markerLength + leadingSpaceCount + remainingLength;
    final maxMarkerWidth = math.min(fragment.bounds.width, typicalHeight * 1.5);
    final markerWidth = (fragment.bounds.width * markerLength / totalLength)
        .clamp(1.0, maxMarkerWidth)
        .toDouble();
    final markerBounds = Rect.fromLTRB(
      fragment.bounds.left,
      fragment.bounds.top,
      fragment.bounds.left + markerWidth,
      fragment.bounds.bottom,
    );
    yield SmartPenTextFragment(text: markerText, bounds: markerBounds);
    final remainingLeft = markerBounds.right;
    if (remainingLeft < fragment.bounds.right) {
      yield SmartPenTextFragment(
        text: remainingText,
        bounds: Rect.fromLTRB(
          remainingLeft,
          fragment.bounds.top,
          fragment.bounds.right,
          fragment.bounds.bottom,
        ),
      );
    }
  }

  static String _normalizedText(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static Set<String> _diagonalWatermarkTexts(
    List<SmartPenTextFragment> fragments,
    double typicalHeight,
  ) {
    final byText = <String, List<SmartPenTextFragment>>{};
    for (final fragment in fragments) {
      final text = _normalizedText(fragment.text);
      if (text.length >= 8) byText.putIfAbsent(text, () => []).add(fragment);
    }

    final watermarkTexts = <String>{};
    final diagonalThreshold = math.max(typicalHeight * 2, 18.0);
    for (final entry in byText.entries) {
      if (entry.value.length < 2) continue;
      final occurrences = [...entry.value]
        ..sort((a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy));
      final first = occurrences.first.bounds.center;
      final last = occurrences.last.bounds.center;
      if ((first.dx - last.dx).abs() >= diagonalThreshold &&
          (first.dy - last.dy).abs() >= diagonalThreshold) {
        watermarkTexts.add(entry.key);
      }
    }
    return watermarkTexts;
  }

  static int _labelRank(String label) =>
      label.codeUnitAt(0) - 'A'.codeUnitAt(0);

  static bool _isInlineOptionRow(
    List<_MarkerRun> markers, {
    required double rowTolerance,
  }) {
    if (markers.length != 4) return false;
    for (var i = 0; i < markers.length; i++) {
      if (_labelRank(markers[i].label) != i) return false;
      if (i > 0 &&
          (markers[i].rowCenterY - markers.first.rowCenterY).abs() >
              rowTolerance * 1.5) {
        return false;
      }
      if (i > 0 && markers[i].columnCenterX <= markers[i - 1].columnCenterX) {
        return false;
      }
    }
    return true;
  }

  static List<_MarkerRun>? _inlineOptionMarkers(
    List<SmartPenTextFragment> row, {
    required double rowTolerance,
    required double typicalHeight,
  }) {
    final ordered = [...row]
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final markerIndices = <int>[];
    final markers = <_MarkerRun>[];
    for (var i = 0; i < ordered.length; i++) {
      final match = _labelPattern.firstMatch(ordered[i].text.trim());
      if (match == null) continue;
      markerIndices.add(i);
      markers.add(
        _MarkerRun(
          label: match.group(1)!,
          bounds: ordered[i].bounds,
          rowCenterY: ordered[i].bounds.center.dy,
          columnCenterX: ordered[i].bounds.center.dx,
        ),
      );
    }
    if (!_isInlineOptionRow(markers, rowTolerance: rowTolerance)) return null;

    // Permit a leading question number, but not prose before the first option
    // marker. This keeps ordinary inline references to A, B, C and D out.
    final firstMarkerIndex = markerIndices.first;
    if (ordered
        .take(firstMarkerIndex)
        .any(
          (fragment) => !RegExp(r'^\d+\.?$').hasMatch(fragment.text.trim()),
        )) {
      return null;
    }

    final maxGap = math.max(typicalHeight * 6, 16.0);
    for (
      var markerIndex = 0;
      markerIndex < markerIndices.length;
      markerIndex++
    ) {
      final textStart = markerIndices[markerIndex] + 1;
      final textEnd = markerIndex + 1 < markerIndices.length
          ? markerIndices[markerIndex + 1]
          : ordered.length;
      final markerBounds = markers[markerIndex].bounds;
      SmartPenTextFragment? optionText;
      for (final fragment
          in ordered.skip(textStart).take(textEnd - textStart)) {
        if (RegExp(
          r'[A-Za-z0-9\u00C0-\u024F\u1E00-\u1EFF]',
        ).hasMatch(fragment.text)) {
          optionText = fragment;
          break;
        }
      }
      if (optionText == null) return null;
      final gap = optionText.bounds.left - markerBounds.right;
      if (gap < -typicalHeight * 0.25 || gap > maxGap) return null;
    }
    return markers;
  }

  static List<_MarkerRun>? _edgePartialOptionRow(
    List<_MarkerRun> markers, {
    required Size? pageSize,
    required double edgeMargin,
  }) {
    if (pageSize == null || markers.length != 2) return null;
    final labels = markers.map((marker) => marker.label).toList();
    final expectedPair =
        labels[0] == 'A' && labels[1] == 'B' ||
        labels[0] == 'C' && labels[1] == 'D';
    if (!expectedPair) return null;
    final y = (markers[0].rowCenterY + markers[1].rowCenterY) / 2;
    if (y > edgeMargin && pageSize.height - y > edgeMargin) return null;
    return markers;
  }

  static List<_MarkerRun>? _inlineCorrectionMarkers(
    List<List<SmartPenTextFragment>> rows,
    int rowIndex, {
    required double rowTolerance,
    required double typicalHeight,
  }) {
    final row = rows[rowIndex];
    final fragments = [...row]
      ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    final markers = <_MarkerRun>[];
    for (final fragment in fragments) {
      final match = _labelPattern.firstMatch(fragment.text.trim());
      if (match == null) return null;
      markers.add(
        _MarkerRun(
          label: match.group(1)!,
          bounds: fragment.bounds,
          rowCenterY: fragment.bounds.center.dy,
          columnCenterX: fragment.bounds.center.dx,
        ),
      );
    }
    if (!_isInlineOptionRow(markers, rowTolerance: rowTolerance)) return null;

    // Error-identification PDFs place bare A-D markers below a numbered
    // sentence segment. Accept that layout only when a nearby numbered text
    // row spans the marker positions; isolated A-D rows stay unclassified.
    for (final neighborIndex in [rowIndex - 1, rowIndex + 1]) {
      if (neighborIndex < 0 || neighborIndex >= rows.length) continue;
      final neighbor = rows[neighborIndex];
      final centerY =
          (neighbor.first.bounds.center.dy + neighbor.last.bounds.center.dy) /
          2;
      if ((centerY - markers.first.rowCenterY).abs() > typicalHeight * 3.5 ||
          neighbor.length < 3 ||
          !RegExp(r'^\d{1,3}\.?$').hasMatch(neighbor.first.text.trim())) {
        continue;
      }
      final textFragments = neighbor.skip(1).toList();
      if (!textFragments.any(
        (fragment) => RegExp(
          r'[A-Za-z\u00C0-\u024F\u1E00-\u1EFF]',
        ).hasMatch(fragment.text),
      )) {
        continue;
      }
      final textLeft = textFragments.first.bounds.left;
      final textRight = textFragments.last.bounds.right;
      final horizontalPadding = typicalHeight * 3;
      if (markers.first.columnCenterX >= textLeft - horizontalPadding &&
          markers.last.columnCenterX <= textRight + horizontalPadding) {
        return markers;
      }
    }
    return null;
  }

  static bool _hasNearbyOptionText(
    List<SmartPenTextFragment> column,
    int markerIndex, {
    required double rowTolerance,
    required double typicalHeight,
  }) {
    final marker = column[markerIndex].bounds;
    final maxGap = math.max(typicalHeight * 8, 16.0);
    for (final following in column.skip(markerIndex + 1)) {
      final verticalDistance = (following.bounds.center.dy - marker.center.dy)
          .abs();
      if (verticalDistance > rowTolerance * 1.5) continue;
      final gap = following.bounds.left - marker.right;
      if (gap >= -typicalHeight * 0.25 && gap <= maxGap) return true;
    }
    return false;
  }

  static bool _isTwoColumnQuestionPair(
    List<_MarkerRun> first,
    List<_MarkerRun> second, {
    required double rowTolerance,
    required double xTolerance,
  }) {
    if (first.length != 2 || second.length != 2) return false;
    final firstCenter =
        first.map((marker) => marker.columnCenterX).reduce((a, b) => a + b) /
        first.length;
    final secondCenter =
        second.map((marker) => marker.columnCenterX).reduce((a, b) => a + b) /
        second.length;
    if ((firstCenter - secondCenter).abs() <= xTolerance) return false;

    final left = firstCenter < secondCenter ? first : second;
    final right = firstCenter < secondCenter ? second : first;
    final leftRows = [...left]
      ..sort((a, b) => a.rowCenterY.compareTo(b.rowCenterY));
    final rightRows = [...right]
      ..sort((a, b) => a.rowCenterY.compareTo(b.rowCenterY));
    for (var i = 0; i < 2; i++) {
      if ((leftRows[i].rowCenterY - rightRows[i].rowCenterY).abs() >
              rowTolerance * 1.5 ||
          _labelRank(rightRows[i].label) != _labelRank(leftRows[i].label) + 1) {
        return false;
      }
    }
    return _labelRank(leftRows.first.label) == 0 &&
        _labelRank(leftRows.last.label) == 2;
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
      final gap = columns.isEmpty
          ? 0.0
          : fragment.bounds.left - columns.last.last.bounds.right;
      final startsNewMarkerColumn =
          columns.isNotEmpty && _labelPattern.hasMatch(fragment.text.trim());
      if (columns.isEmpty || gap > gapThreshold || startsNewMarkerColumn) {
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

  static bool _hasNearbyQuestionHeading(
    List<SmartPenTextFragment> fragments,
    List<_MarkerRun> component, {
    required double typicalHeight,
    required double edgeMargin,
  }) {
    final componentY =
        component.map((marker) => marker.rowCenterY).reduce((a, b) => a + b) /
        component.length;
    final headingPattern = RegExp(
      r'^(?:(?:câu|question)\s*\d+|\d{1,3}\.?\s+\S+)',
      caseSensitive: false,
    );
    final rowTolerance = math.max(typicalHeight * 0.55, 1.0);
    return _groupRows(fragments, rowTolerance).any((row) {
      final ordered = [...row]
        ..sort((left, right) => left.bounds.left.compareTo(right.bounds.left));
      final rowText = ordered.map((fragment) => fragment.text.trim()).join(' ');
      if (!headingPattern.hasMatch(rowText)) return false;
      final headingY =
          ordered
              .map((fragment) => fragment.bounds.center.dy)
              .reduce((a, b) => a + b) /
          ordered.length;
      return headingY <= edgeMargin &&
          (headingY - componentY).abs() <= typicalHeight * 8;
    });
  }

  static bool _isFiniteRect(Rect rect) =>
      rect.left.isFinite &&
      rect.top.isFinite &&
      rect.right.isFinite &&
      rect.bottom.isFinite;
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
