import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/studio_state.dart';
import 'grid_painter.dart';
import 'stroke_canvas.dart';
import 'smart_chalk_overlay.dart';
import 'pdf_dgnl_passage_overlay.dart';
import '../services/smart_pen_answer_index.dart';

class PdfStage extends StatefulWidget {
  const PdfStage({
    super.key,
    required this.studio,
    this.interactive = true,
    this.onSmartAnswerTap,
  });

  final StudioState studio;
  final bool interactive;
  final ValueChanged<SmartPenAnswerCandidate>? onSmartAnswerTap;

  @override
  State<PdfStage> createState() => _PdfStageState();
}

class _PdfStageState extends State<PdfStage> {
  final PdfViewerController _pdfController = PdfViewerController();
  final GlobalKey _pdfViewerKey = GlobalKey();
  bool _isDragging = false;
  bool _lastFitWidth = true;
  int _lastPage = 1;
  int _lastZoomAction = 0;
  Size? _lastContainerSize;
  final SmartPenPageIndexStore _smartIndexStore = SmartPenPageIndexStore();
  final SmartPenTapQueue _smartTapQueue = SmartPenTapQueue(maxLength: 32);
  final Map<int, Rect> _smartPageRects = {};
  final SmartPenPdfTextExtractor _smartTextExtractor =
      SmartPenPdfTextExtractor();
  SmartPenPageIndexScheduler? _smartIndexScheduler;
  PdfDocument? _smartIndexDocument;
  int _smartDocumentGeneration = 0;
  bool _lastSmartSnapEnabled = false;

  @override
  void initState() {
    super.initState();
    widget.studio.pdfViewerController = _pdfController;
    widget.studio.pdfViewerKey = _pdfViewerKey;
    _lastFitWidth = widget.studio.pdfFitWidth;
    _lastPage = widget.studio.pdfPage;
    _lastZoomAction = widget.studio.pdfZoomAction;
    _lastSmartSnapEnabled = widget.studio.smartSnapEnabled;
    widget.studio.addListener(_onStudioChanged);
  }

  @override
  void didUpdateWidget(covariant PdfStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studio != widget.studio) {
      oldWidget.studio.removeListener(_onStudioChanged);
      widget.studio.addListener(_onStudioChanged);
      _smartTapQueue.clear();
      _smartDocumentGeneration++;
      _smartIndexDocument = null;
      _smartIndexScheduler = null;
      _smartPageRects.clear();
      _lastSmartSnapEnabled = widget.studio.smartSnapEnabled;
      widget.studio.pdfViewerController = _pdfController;
      widget.studio.pdfViewerKey = _pdfViewerKey;
    }
  }

  @override
  void dispose() {
    _smartDocumentGeneration++;
    _smartTapQueue.clear();
    _smartIndexScheduler = null;
    _smartIndexDocument = null;
    _smartPageRects.clear();
    if (widget.studio.pdfViewerController == _pdfController) {
      widget.studio.pdfViewerController = null;
      widget.studio.pdfViewerKey = null;
    }
    widget.studio.removeListener(_onStudioChanged);
    super.dispose();
  }

  void _onStudioChanged() {
    if (_lastSmartSnapEnabled != widget.studio.smartSnapEnabled) {
      _lastSmartSnapEnabled = widget.studio.smartSnapEnabled;
      if (!_lastSmartSnapEnabled) _smartTapQueue.clear();
    }
    if (!_pdfController.isReady) return;

    final pageChanged =
        widget.studio.pdfPage != _lastPage &&
        widget.studio.pdfPage >= 1 &&
        widget.studio.pdfPage <= widget.studio.pdfTotalPages;
    final fitChanged = widget.studio.pdfFitWidth != _lastFitWidth;
    final zoomChanged = widget.studio.pdfZoomAction != _lastZoomAction;

    if (pageChanged) {
      _lastPage = widget.studio.pdfPage;
      _smartIndexScheduler?.setVisiblePage(widget.studio.pdfPage);
      _pdfController.goToPage(pageNumber: widget.studio.pdfPage);
      Future.microtask(() => _applyFit());
    } else if (fitChanged) {
      _lastFitWidth = widget.studio.pdfFitWidth;
      _applyFit();
    } else if (zoomChanged) {
      final action = widget.studio.pdfZoomAction;
      final prev = _lastZoomAction;
      _lastZoomAction = action;
      if (action == 999) {
        _applyFit();
      } else if (action > prev) {
        _pdfController.zoomUp();
      } else if (action < prev) {
        _pdfController.zoomDown();
      }
    }
  }

  void _beginSmartIndexing(PdfDocument document) {
    if (identical(_smartIndexDocument, document)) return;
    _smartIndexDocument = document;
    final generation = ++_smartDocumentGeneration;
    _smartTapQueue.clear();
    _smartIndexStore.beginGeneration(generation);
    _smartIndexScheduler = SmartPenPageIndexScheduler(
      documentGeneration: generation,
      pageCount: document.pages.length,
      nearbyPageRadius: 2,
      buildPageIndex: (pageNumber, requestedGeneration) =>
          _buildSmartPageIndex(document, pageNumber, requestedGeneration),
    )..setVisiblePage(widget.studio.pdfPage);
  }

  Future<void> _buildSmartPageIndex(
    PdfDocument document,
    int pageNumber,
    int generation,
  ) async {
    if (generation != _smartDocumentGeneration ||
        pageNumber < 1 ||
        pageNumber > document.pages.length ||
        !_smartIndexStore.beginPage(pageNumber)) {
      return;
    }

    try {
      final page = await document.pages[pageNumber - 1].ensureLoaded();
      final fragments = await _smartTextExtractor.extract(page);
      if (generation != _smartDocumentGeneration) return;
      if (fragments.isEmpty) {
        _smartIndexStore.markTextless(pageNumber);
      } else {
        final index = SmartPenPageIndex.build(
          documentGeneration: generation,
          pageNumber: pageNumber,
          pageSize: SmartPenPdfTextExtractor.canonicalPageSize(page),
          fragments: fragments,
        );
        _smartIndexStore.completePage(index);
      }
      _resolveQueuedSmartTaps(pageNumber, generation);
    } catch (_) {
      if (generation != _smartDocumentGeneration) return;
      _smartIndexStore.failPage(pageNumber);
      _resolveQueuedSmartTaps(pageNumber, generation);
    }
  }

  void _queueOrResolveSmartTap({
    required PdfPage page,
    required Rect pageRect,
    required List<BoardStroke> targetStrokes,
    required Offset normalizedPoint,
  }) {
    final generation = _smartDocumentGeneration;
    final pageNumber = page.pageNumber;
    final status = _smartIndexStore.statusFor(pageNumber);
    if (status == SmartPenPageIndexStatus.notStarted ||
        status == SmartPenPageIndexStatus.building) {
      final scheduler = _smartIndexScheduler;
      if (scheduler == null) {
        _addOrdinaryPdfTap(normalizedPoint, targetStrokes);
        return;
      }
      final pageSize = SmartPenPdfTextExtractor.canonicalPageSize(page);
      final tap = SmartPenPendingTap(
        pageNumber: pageNumber,
        documentGeneration: generation,
        pagePoint: Offset(
          normalizedPoint.dx * pageSize.width,
          normalizedPoint.dy * pageSize.height,
        ),
      );
      if (_smartTapQueue.enqueue(tap)) {
        scheduler.requestPage(pageNumber);
      } else {
        _addOrdinaryPdfTap(normalizedPoint, targetStrokes);
      }
      return;
    }

    _resolveSmartTap(
      pageNumber: pageNumber,
      generation: generation,
      pageRect: pageRect,
      targetStrokes: targetStrokes,
      normalizedPoint: normalizedPoint,
    );
  }

  void _resolveQueuedSmartTaps(int pageNumber, int generation) {
    if (!mounted ||
        !widget.studio.smartSnapEnabled ||
        generation != _smartDocumentGeneration) {
      return;
    }
    final index = _smartIndexStore.indexFor(pageNumber);
    final pageSize = index?.pageSize;
    if (pageSize == null) {
      // Textless and failed pages have no index geometry. Taps still use the
      // ordinary pen fallback in their original page coordinates.
      final page = _smartIndexDocument?.pages[pageNumber - 1];
      if (page == null) return;
      final size = SmartPenPdfTextExtractor.canonicalPageSize(page);
      for (final tap in _smartTapQueue.takeForPage(pageNumber, generation)) {
        final target = widget.studio.pdfAnnotations.putIfAbsent(
          pageNumber,
          () => <BoardStroke>[],
        );
        _addOrdinaryPdfTap(
          Offset(tap.pagePoint.dx / size.width, tap.pagePoint.dy / size.height),
          target,
        );
      }
      return;
    }
    final pageRect =
        _smartPageRects[pageNumber] ??
        (_pdfController.isReady
            ? Rect.fromLTWH(
                0,
                0,
                pageSize.width * _pdfController.currentZoom,
                pageSize.height * _pdfController.currentZoom,
              )
            : null);
    if (pageRect == null) return;
    for (final tap in _smartTapQueue.takeForPage(pageNumber, generation)) {
      final target = widget.studio.pdfAnnotations.putIfAbsent(
        pageNumber,
        () => <BoardStroke>[],
      );
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

  void _resolveSmartTap({
    required int pageNumber,
    required int generation,
    required Rect pageRect,
    required List<BoardStroke> targetStrokes,
    required Offset normalizedPoint,
  }) {
    final index = _smartIndexStore.indexFor(pageNumber);
    if (!widget.studio.smartSnapEnabled ||
        generation != _smartDocumentGeneration ||
        index == null) {
      _addOrdinaryPdfTap(normalizedPoint, targetStrokes);
      return;
    }

    final pagePoint = Offset(
      normalizedPoint.dx * index.pageSize.width,
      normalizedPoint.dy * index.pageSize.height,
    );
    final zoomScale = pageRect.width / index.pageSize.width;
    final candidate = index.hitTest(
      pagePoint,
      logicalPixelTolerance: 10,
      zoomScale: zoomScale,
    );
    final onSmartAnswerTap = widget.onSmartAnswerTap;
    if (candidate != null) {
      final selection = SmartPenAnswerSelection(
        pageNumber: pageNumber,
        label: candidate.label,
        bounds: candidate.bounds,
        groupId: candidate.groupId,
      );
      widget.studio.toggleSmartPenAnswer(selection, index.pageSize);
      onSmartAnswerTap?.call(candidate);
      return;
    }
    _addOrdinaryPdfTap(normalizedPoint, targetStrokes);
  }

  void _addOrdinaryPdfTap(Offset normalizedPoint, List<BoardStroke> target) {
    final studio = widget.studio;
    final highlighter = studio.tool == 'highlight';
    final width = highlighter ? studio.highlighterWidth : studio.strokeWidth;
    final stroke = BoardStroke(studio.ink, width, [normalizedPoint]);
    studio.addStroke(stroke, target: target);
  }

  void _applyFit() {
    if (!_pdfController.isReady) return;
    final page = widget.studio.pdfPage;
    if (widget.studio.pdfFitWidth) {
      final fitW = _pdfController.calcMatrixFitWidthForPage(pageNumber: page);
      if (fitW != null) {
        _pdfController.goTo(fitW);
      }
    } else {
      final fitH = _pdfController.calcMatrixFitHeightForPage(pageNumber: page);
      if (fitH != null) {
        _pdfController.goTo(fitH);
      }
    }
  }

  Future<void> _pickFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isNotEmpty) {
      final file = files.first;
      final bytes = await file.readAsBytes();
      widget.studio.setPdfFile(file.path ?? file.name, bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    widget.studio.pdfViewerController = _pdfController;
    widget.studio.pdfViewerKey = _pdfViewerKey;
    final studio = widget.studio;
    final hasPdf = studio.pdfFilePath != null || studio.pdfBytes != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final currentSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_lastContainerSize != null &&
            (_lastContainerSize!.width != currentSize.width ||
                _lastContainerSize!.height != currentSize.height)) {
          _lastContainerSize = currentSize;
          if (_pdfController.isReady && widget.studio.pdfFitWidth) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _applyFit();
            });
          }
        } else {
          _lastContainerSize = currentSize;
        }

        return DropTarget(
          onDragEntered: (_) => setState(() => _isDragging = true),
          onDragExited: (_) => setState(() => _isDragging = false),
          onDragDone: (detail) async {
            setState(() => _isDragging = false);
            if (detail.files.isNotEmpty) {
              final file = detail.files.first;
              if (file.name.toLowerCase().endsWith('.pdf')) {
                final bytes = await file.readAsBytes();
                widget.studio.setPdfFile(file.path, bytes);
              }
            }
          },
          child: Container(
            color: chalkboardBg,
            child: hasPdf ? _buildPdfView() : _buildEmptyState(),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0x14ffffff),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isDragging
                    ? const Color(0xffd4e8a6)
                    : const Color(0x28ffffff),
                width: _isDragging ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDragging
                      ? Icons.file_download_outlined
                      : Icons.picture_as_pdf_outlined,
                  size: 36,
                  color: _isDragging
                      ? const Color(0xffd4e8a6)
                      : const Color(0xff9eaea2),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDragging
                      ? 'Thả tệp PDF vào đây'
                      : 'Kéo thả tệp PDF vào đây để mở',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xffe8eae6),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Hỗ trợ giáo trình, đề kiểm tra PDF',
                  style: TextStyle(fontSize: 11, color: Color(0xff8a9a8d)),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _pickFile,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xffd4e8a6),
                    foregroundColor: const Color(0xff14221d),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.folder_open, size: 15),
                  label: const Text(
                    'Mở tệp PDF từ máy',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _cachedPdfViewer;
  String? _cachedPdfPath;
  Uint8List? _cachedPdfBytes;

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
      panAxis: PanAxis.free,
      scrollByMouseWheel: 1.0,
      boundaryMargin: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 20.0,
      ),
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
          controller.goToPage(pageNumber: studio.pdfPage);
        }
        Future.microtask(() => _applyFit());
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
                  return Listener(
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
                      ignoring: isPanMode || !widget.interactive,
                      child: Stack(
                        children: [
                          StrokeCanvas(
                            studio: studio,
                            targetStrokes: studio.pdfAnnotations.putIfAbsent(
                              page.pageNumber,
                              () => [],
                            ),
                            interactive:
                                widget.interactive &&
                                !isPanMode &&
                                studio.activeSubjectTool != 'svo',
                            smartSnapEnabled:
                                studio.smartSnapEnabled && studio.tool == 'pen',
                            onSmartTap: (normalizedPoint) =>
                                _queueOrResolveSmartTap(
                                  page: page,
                                  pageRect: pageRect,
                                  targetStrokes: studio.pdfAnnotations
                                      .putIfAbsent(
                                        page.pageNumber,
                                        () => <BoardStroke>[],
                                      ),
                                  normalizedPoint: normalizedPoint,
                                ),
                          ),
                          if (studio.activeSubjectTool == 'svo')
                            Positioned.fill(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (details) async {
                                    final normX =
                                        (details.localPosition.dx /
                                                pageRect.width)
                                            .clamp(0.0, 1.0);
                                    final normY =
                                        (details.localPosition.dy /
                                                pageRect.height)
                                            .clamp(0.0, 1.0);

                                    String? extractedText;
                                    Rect? textNormalizedRect;

                                    try {
                                      final pageText = await page.loadText();
                                      final full =
                                          pageText?.fullText.trim() ?? '';
                                      if (full.isNotEmpty) {
                                        final rawLines = full
                                            .split('\n')
                                            .map((l) => l.trim())
                                            .where((l) => l.isNotEmpty)
                                            .toList();
                                        if (rawLines.isNotEmpty) {
                                          final idx = (normY * rawLines.length)
                                              .clamp(0, rawLines.length - 1)
                                              .toInt();
                                          extractedText = rawLines[idx];
                                          final approxW =
                                              (extractedText.length * 0.018)
                                                  .clamp(0.12, 0.70);
                                          textNormalizedRect = Rect.fromLTWH(
                                            (normX - approxW / 2).clamp(
                                              0.04,
                                              0.96 - approxW,
                                            ),
                                            (normY - 0.012).clamp(0.005, 0.96),
                                            approxW,
                                            0.022,
                                          );
                                        }
                                      }
                                    } catch (_) {}

                                    studio.analyzePdfSentenceAt(
                                      page.pageNumber,
                                      Offset(normX, normY),
                                      sampleText: extractedText,
                                      targetRect: textNormalizedRect,
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

    _cachedPdfViewer = RepaintBoundary(
      key: _pdfViewerKey,
      child: studio.pdfBytes != null
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
            ),
    );
    return _cachedPdfViewer!;
  }

  Widget _buildPdfView() {
    return _getPdfViewerWidget();
  }
}
