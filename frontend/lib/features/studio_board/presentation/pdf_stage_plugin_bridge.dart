part of 'pdf_stage.dart';

extension _PdfStagePluginBridge on _PdfStageState {
  void _dispatchPdfTextFragments(
    int pageNumber,
    int generation,
    Size pageSize,
    List<SmartPenTextFragment> fragments,
  ) {
    final studio = widget.studio;
    final plugin = studio.activePlugin;
    final activeTarget = studio.activeSubjectTool;
    if (plugin == null || activeTarget == null) return;
    final ownsPdfTool = plugin.manifest.contributesTools.any(
      (tool) => tool.pdfTapMode && (tool.target ?? tool.id) == activeTarget,
    );
    if (!ownsPdfTool ||
        !plugin.manifest.permissions.contains('board:read_text')) {
      return;
    }
    final indexStatus = _smartIndexStore.statusFor(pageNumber);
    if (indexStatus != SmartPenPageIndexStatus.ready &&
        indexStatus != SmartPenPageIndexStatus.empty) {
      return;
    }

    PluginEventHub.instance.dispatch(plugin.id, 'board:pdf_text_fragments', {
      'page_number': pageNumber,
      'document_generation': studio.pdfContentGeneration,
      'page_size': {'width': pageSize.width, 'height': pageSize.height},
      'answer_candidates': [
        for (final candidate in
            _smartAnswerGroups?.candidatesForPage(pageNumber) ??
                _smartIndexStore.indexFor(pageNumber)?.candidates ??
                const <SmartPenAnswerCandidate>[])
          {
            'label': candidate.label,
            'group_id': candidate.groupId,
            'bounds': {
              'x': candidate.bounds.left,
              'y': candidate.bounds.top,
              'width': candidate.bounds.width,
              'height': candidate.bounds.height,
            },
          },
      ],
      'fragments': [
        for (final fragment in fragments)
          {
            'text': fragment.text,
            'bounds': {
              'x': fragment.bounds.left,
              'y': fragment.bounds.top,
              'width': fragment.bounds.width,
              'height': fragment.bounds.height,
            },
          },
      ],
    });
  }

  void _dispatchCachedPdfTextToActivePlugin() {
    final studio = widget.studio;
    if (_pdfTextCacheContentGeneration != studio.pdfContentGeneration) return;
    final plugin = studio.activePlugin;
    final target = studio.activeSubjectTool;
    final ownsPdfTool =
        plugin?.manifest.contributesTools.any(
          (tool) => tool.pdfTapMode && (tool.target ?? tool.id) == target,
        ) ??
        false;
    final canReadText =
        plugin?.manifest.permissions.contains('board:read_text') ?? false;
    final key = ownsPdfTool && canReadText && plugin != null
        ? '${plugin.id}:$target:${studio.pdfContentGeneration}'
        : null;
    if (key == _lastPdfDispatchTarget) return;
    _lastPdfDispatchTarget = key;
    if (key == null) return;

    for (final entry in _pdfTextPages.entries) {
      _dispatchPdfTextFragments(
        entry.key,
        _smartDocumentGeneration,
        entry.value.pageSize,
        entry.value.fragments,
      );
    }
  }

  void _syncPluginRegionSubscription() {
    final studio = widget.studio;
    final plugin = studio.activePlugin ?? studio.floatingPlugin;
    final target = studio.activeSubjectTool;
    final ownsPdfTool =
        plugin?.manifest.contributesTools.any(
          (tool) => tool.pdfTapMode && (tool.target ?? tool.id) == target,
        ) ??
        false;
    final canPublishRegions =
        plugin?.manifest.permissions.contains('board:publish_pdf_regions') ??
        false;
    final key = ownsPdfTool && canPublishRegions && plugin != null
        ? '${plugin.id}:$target:${studio.pdfContentGeneration}'
        : null;
    if (key == _pluginRegionSubscriptionKey) return;

    unawaited(_pluginRegionSubscription?.cancel());
    _pluginRegionSubscription = null;
    _pluginPdfPagesReady.clear();
    _pluginRegionSubscriptionKey = key;
    if (plugin == null || key == null) return;

    final pluginId = plugin.id;
    _pluginRegionSubscription = PluginEventHub.instance
        .messagesFor(pluginId)
        .listen((message) {
          if (message.action != 'board:publish_pdf_regions' ||
              message.payload['document_generation'] !=
                  widget.studio.pdfContentGeneration) {
            return;
          }
          final pageNumber = message.payload['page_number'];
          if (pageNumber is! int || pageNumber < 1) {
            return;
          }
          _pluginPdfPagesReady.add(pageNumber);
          if (_showSmartPenDebugBounds && mounted) {
            _smartIndexRevision.value++;
          }
          _resolvePendingPluginTaps(pageNumber, _smartDocumentGeneration);
        });
  }

  void _dispatchPdfTapToActivePlugin(int pageNumber, Offset pagePoint) {
    final plugin = widget.studio.activePlugin;
    if (plugin == null) return;
    final pageSize = _pdfTextPages[pageNumber]?.pageSize;
    final pageRect = _smartPageRects[pageNumber];
    final zoomScale = pageSize == null ||
            pageRect == null ||
            pageSize.width <= 0
        ? 1.0
        : pageRect.width / pageSize.width;
    PluginEventHub.instance.dispatch(plugin.id, 'board:pdf_tap', {
      'page_number': pageNumber,
      'document_generation': widget.studio.pdfContentGeneration,
      'page_point': {'x': pagePoint.dx, 'y': pagePoint.dy},
      // Keep the pointer target comfortable in screen space while the plugin
      // continues to test against PDF-space region bounds.
      'hit_tolerance': 12 / zoomScale,
    });
  }

  void _dispatchActivePluginToolState() {
    final studio = widget.studio;
    final plugin = studio.activePlugin ?? studio.floatingPlugin;
    final key = plugin == null
        ? null
        : '${plugin.id}:${studio.activeSubjectTool ?? ''}';
    if (key == _lastPluginToolStateKey) return;
    _lastPluginToolStateKey = key;
    if (plugin == null) return;
    PluginEventHub.instance.dispatch(plugin.id, 'board:tool_state', {
      'active_tool': studio.activeSubjectTool,
    });
  }

  bool get _activePluginOwnsPdfTool {
    final plugin = widget.studio.activePlugin;
    final target = widget.studio.activeSubjectTool;
    if (plugin == null || target == null) return false;
    if (!plugin.manifest.permissions.contains('board:read_text') ||
        !plugin.manifest.permissions.contains('board:publish_pdf_regions')) {
      return false;
    }
    return plugin.manifest.contributesTools.any(
      (tool) =>
          tool.action == 'toggle_tool' &&
          tool.pdfTapMode &&
          (tool.target ?? tool.id) == target,
    );
  }

  void _resolvePendingPluginTaps(
    int pageNumber,
    int generation, {
    bool forceOrdinaryTap = false,
  }) {
    if (!mounted || generation != _smartDocumentGeneration) return;
    final taps = _smartTapQueue.takeForPage(pageNumber, generation);
    if (taps.isEmpty) return;
    final index = _smartIndexStore.indexFor(pageNumber);
    final pageSize = _pdfTextPages[pageNumber]?.pageSize ?? index?.pageSize;
    final pageRect = _smartPageRects[pageNumber];
    for (final tap in taps) {
      final target = widget.studio.pdfAnnotations.putIfAbsent(
        pageNumber,
        () => <BoardStroke>[],
      );
      if (forceOrdinaryTap || pageSize == null || pageRect == null) {
        _addOrdinaryPdfTap(
          Offset(
            tap.pagePoint.dx / (pageSize?.width ?? 1),
            tap.pagePoint.dy / (pageSize?.height ?? 1),
          ),
          target,
        );
      } else {
        _resolveSmartTap(
          pageNumber: pageNumber,
          generation: generation,
          pageRect: pageRect,
          targetStrokes: target,
          normalizedPoint: Offset(
            tap.pagePoint.dx / pageSize.width,
            tap.pagePoint.dy / pageSize.height,
          ),
        );
      }
    }
  }

  void _flushQueuedPluginTapsToOrdinaryInk() {
    final taps = _smartTapQueue.takeForGeneration(_smartDocumentGeneration);
    for (final tap in taps) {
      final pageSize =
          _pdfTextPages[tap.pageNumber]?.pageSize ??
          _smartIndexStore.indexFor(tap.pageNumber)?.pageSize;
      if (pageSize == null) continue;
      final target = widget.studio.pdfAnnotations.putIfAbsent(
        tap.pageNumber,
        () => <BoardStroke>[],
      );
      _addOrdinaryPdfTap(
        Offset(
          tap.pagePoint.dx / pageSize.width,
          tap.pagePoint.dy / pageSize.height,
        ),
        target,
      );
    }
  }
}
