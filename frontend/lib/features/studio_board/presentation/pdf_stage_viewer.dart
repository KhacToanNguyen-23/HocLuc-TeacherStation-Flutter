part of 'pdf_stage.dart';

// The viewer callback tree stays in the same library so it can use the
// state object's private indexing and pointer fields.
extension _PdfStageViewer on _PdfStageState {
  Widget _getPdfViewerWidget() {
    final studio = widget.studio;
    if (_cachedPdfViewer != null &&
        _cachedPdfPath == studio.pdfFilePath &&
        identical(_cachedPdfBytes, studio.pdfBytes)) {
      return _cachedPdfViewer!;
    }
    _cachedPdfPath = studio.pdfFilePath;
    _cachedPdfBytes = studio.pdfBytes;

    final params = PdfViewerParams(
      backgroundColor: chalkboardBg,
      textSelectionParams: PdfTextSelectionParams(
        onTextSelectionChange: (selection) async {
          final revision = ++_selectionRevision;
          final plugin = studio.activePlugin ?? studio.floatingPlugin;
          final target = studio.activeSubjectTool;
          final generation = studio.pdfContentGeneration;
          if (!_pluginTextSelectionEnabled ||
              plugin == null ||
              !selection.hasSelectedText ||
              !selection.isCopyAllowed) {
            return;
          }
          String? text;
          try {
            text = PluginTextSelection.term(await selection.getSelectedText());
          } catch (error) {
            debugPrint('[PluginSelection] Text extraction failed: $error');
            return;
          }
          if (!mounted ||
              revision != _selectionRevision ||
              text == null ||
              generation != studio.pdfContentGeneration ||
              (studio.activePlugin ?? studio.floatingPlugin)?.id != plugin.id ||
              target != studio.activeSubjectTool ||
              !_pluginTextSelectionEnabled) {
            return;
          }
          PluginEventHub.instance.dispatch(plugin.id, 'board:text_selected', {
            'text': text,
            'target': target,
          });
        },
      ),
      panAxis: ClassroomSettingsService.instance.boardOptimization
          ? PanAxis.free
          : PanAxis.aligned,
      scrollByMouseWheel: 1.0,
      boundaryMargin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 20.0,
      ),
      behaviorControlParams: const PdfViewerBehaviorControlParams(
        loadPageDimensionsOnDemand: true,
        trailingPageLoadingDelay: Duration.zero,
      ),
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        return Container(
          color: chalkboardBg,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xffd4e8a6)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đang tải trang tài liệu...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      onPageChanged: (page) {
        if (page != null && page != studio.pdfPage) {
          _lastPage = page;
          studio.setPdfPage(page);
        }
        if (page != null) _smartIndexScheduler?.setVisiblePage(page);
      },
      onDocumentChanged: (doc) {
        if (doc != null && doc.pages.length != studio.pdfTotalPages) {
          studio.setPdfTotalPages(doc.pages.length);
        }
        if (doc != null) _beginSmartIndexing(doc);
      },
      onViewerReady: (doc, controller) {
        _beginSmartIndexing(doc);
        if (studio.pdfPage > 1 && studio.pdfPage <= doc.pages.length) {
          controller.goToPage(
            pageNumber: studio.pdfPage,
            duration: Duration.zero,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applyFit();
        });
      },
      viewerOverlayBuilder: (context, size, handleLinkTap) => [
        PdfViewerScrollThumb(
          controller: _pdfController,
          orientation: ScrollbarOrientation.right,
          margin: 4,
          thumbSize: const Size(18, 48),
          thumbBuilder: (context, thumbSize, pageNumber, controller) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xd0243b30),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xffd4e8a6).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.unfold_more,
                  size: 14,
                  color: Color(0xffd4e8a6),
                ),
              ),
            );
          },
        ),
      ],
      pageOverlaysBuilder: (context, pageRect, page) {
        _smartPageRects[page.pageNumber] = pageRect;
        return [
          Positioned.fill(
            child: RepaintBoundary(
              child: ListenableBuilder(
                listenable: studio,
                builder: (context, _) {
                  final isPanMode =
                      studio.tool == 'pan' || studio.isSpacePressed;
                  final isSelectingText = _pluginTextSelectionEnabled;
                  return Listener(
                    onPointerDown: (event) {
                      if (isSelectingText ||
                          !studio.smartSnapEnabled ||
                          studio.tool != 'pen' ||
                          isPanMode ||
                          !widget.interactive ||
                          studio.activeToolCapturesBoardInput ||
                          event.buttons & kPrimaryButton == 0) {
                        return;
                      }
                      _smartPointerDowns[event.pointer] = _SmartPenPointerDown(
                        pageNumber: page.pageNumber,
                        localPosition: event.localPosition,
                        timestamp: event.timeStamp,
                      );
                    },
                    onPointerUp: (event) {
                      final down = _smartPointerDowns.remove(event.pointer);
                      if (isSelectingText ||
                          down == null ||
                          down.pageNumber != page.pageNumber ||
                          !studio.smartSnapEnabled ||
                          studio.tool != 'pen' ||
                          isPanMode ||
                          !widget.interactive ||
                          studio.activeToolCapturesBoardInput ||
                          event.timeStamp - down.timestamp >=
                              kLongPressTimeout ||
                          (event.localPosition - down.localPosition).distance >
                              kTouchSlop) {
                        return;
                      }
                      _queueOrResolveSmartTap(
                        page: page,
                        pageRect: pageRect,
                        targetStrokes: studio.pdfAnnotations.putIfAbsent(
                          page.pageNumber,
                          () => <BoardStroke>[],
                        ),
                        normalizedPoint: Offset(
                          (down.localPosition.dx / pageRect.width).clamp(
                            0.0,
                            1.0,
                          ),
                          (down.localPosition.dy / pageRect.height).clamp(
                            0.0,
                            1.0,
                          ),
                        ),
                      );
                    },
                    onPointerCancel: (event) {
                      _smartPointerDowns.remove(event.pointer);
                    },
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (HardwareKeyboard.instance.isControlPressed) {
                          if (event.scrollDelta.dy < 0) {
                            _pdfController.zoomUp();
                          } else if (event.scrollDelta.dy > 0) {
                            _pdfController.zoomDown();
                          }
                        } else {
                          _pdfController.handlePointerSignalEvent(event);
                        }
                      }
                    },
                    child: IgnorePointer(
                      ignoring:
                          isSelectingText || isPanMode || !widget.interactive,
                      child: Stack(
                        children: [
                          StrokeCanvas(
                            studio: studio,
                            pageNumber: page.pageNumber,
                            targetStrokes: studio.pdfAnnotations.putIfAbsent(
                              page.pageNumber,
                              () => [],
                            ),
                            displayStrokes: studio.pdfAnnotationsForPage(
                              page.pageNumber,
                            ),
                            interactive:
                                widget.interactive &&
                                !isPanMode &&
                                !studio.activeToolCapturesBoardInput,
                            deferTapToOverlay:
                                studio.smartSnapEnabled &&
                                studio.tool == 'pen' &&
                                widget.interactive &&
                                !isPanMode &&
                                !studio.activeToolCapturesBoardInput,
                          ),
                          if (_showSmartPenDebugBounds)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _smartIndexRevision,
                                  builder: (context, _, _) {
                                    final index = _smartIndexStore.indexFor(
                                      page.pageNumber,
                                    );
                                    final currentIds =
                                        _smartAnswerGroups
                                            ?.candidatesForPage(page.pageNumber)
                                            .map(
                                              (candidate) => candidate.groupId,
                                            )
                                            .toSet() ??
                                        const <String>{};
                                    final linkedIds = <String>{};
                                    for (
                                      var otherPage = 1;
                                      otherPage <=
                                          (_smartIndexDocument?.pages.length ??
                                              0);
                                      otherPage++
                                    ) {
                                      if (otherPage == page.pageNumber) {
                                        continue;
                                      }
                                      for (final candidate
                                          in _smartAnswerGroups
                                                  ?.candidatesForPage(
                                                    otherPage,
                                                  ) ??
                                              const <
                                                SmartPenAnswerCandidate
                                              >[]) {
                                        if (currentIds.contains(
                                          candidate.groupId,
                                        )) {
                                          linkedIds.add(candidate.groupId);
                                        }
                                      }
                                    }
                                    return CustomPaint(
                                      painter: _SmartPenDebugBoundsPainter(
                                        candidates:
                                            _smartAnswerGroups
                                                ?.candidatesForPage(
                                                  page.pageNumber,
                                                ) ??
                                            index?.candidates ??
                                            const [],
                                        partialGroups:
                                            index?.partialGroups ?? const [],
                                        partialGroupIds: {
                                          for (final group
                                              in index?.partialGroups ??
                                                  const [])
                                            for (final partial
                                                in group.candidates)
                                              _smartAnswerGroups
                                                      ?.canonicalGroupIdFor(
                                                        page.pageNumber,
                                                        partial,
                                                      ) ??
                                                  partial.groupId,
                                        },
                                        debugFragments:
                                            index?.debugFragments ?? const [],
                                        linkedGroupIds: linkedIds,
                                        pageSize:
                                            index?.pageSize ??
                                            SmartPenPdfTextExtractor.canonicalPageSize(
                                              page,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),

                          SmartChalkOverlay(
                            studio: studio,
                            targetAnnotations: studio.getPdfChalkAnnotations(
                              page.pageNumber,
                            ),
                            onDelete: (id) => studio.removePdfChalkAnnotation(
                              page.pageNumber,
                              id,
                            ),
                          ),
                          // In-Document DGNL Multi-layer Highlight Overlay
                          if (!PluginTextSelection.prefersRawSnippets(
                            (studio.activePlugin ?? studio.floatingPlugin)
                                ?.manifest,
                          ))
                            Positioned.fill(
                              child: PdfDgnlPassageOverlay(
                                studio: studio,
                                pageNumber: page.pageNumber,
                                pageRect: pageRect,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ];
      },
    );

    final hasLocalFile =
        studio.pdfFilePath != null &&
        studio.pdfFilePath!.isNotEmpty &&
        File(studio.pdfFilePath!).existsSync();

    _cachedPdfViewer = RepaintBoundary(
      key: _pdfViewerKey,
      child: hasLocalFile
          ? PdfViewer.file(
              studio.pdfFilePath!,
              controller: _pdfController,
              params: params,
            )
          : (studio.pdfBytes != null
                ? PdfViewer.data(
                    studio.pdfBytes!,
                    sourceName: studio.pdfFilePath ?? 'document.pdf',
                    controller: _pdfController,
                    params: params,
                  )
                : PdfViewer.file(
                    studio.pdfFilePath!,
                    controller: _pdfController,
                    params: params,
                  )),
    );
    return _cachedPdfViewer!;
  }
}
