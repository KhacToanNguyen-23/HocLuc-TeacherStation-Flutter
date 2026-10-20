import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';
import 'grid_painter.dart';
import 'stroke_canvas.dart';
import 'smart_chalk_overlay.dart';
import 'pdf_dgnl_passage_overlay.dart';
import '../services/smart_pen_answer_index.dart';

part 'pdf_stage_viewer.dart';

const _showSmartPenDebugBounds = bool.fromEnvironment('SMART_PEN_DEBUG');

class _SmartPenPointerDown {
  const _SmartPenPointerDown({
    required this.pageNumber,
    required this.localPosition,
    required this.timestamp,
  });

  final int pageNumber;
  final Offset localPosition;
  final Duration timestamp;
}

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
  final Map<int, _SmartPenPointerDown> _smartPointerDowns = {};
  final ValueNotifier<int> _smartIndexRevision = ValueNotifier(0);
  final SmartPenPdfTextExtractor _smartTextExtractor =
      SmartPenPdfTextExtractor();
  SmartPenAnswerGroupMap? _smartAnswerGroups;
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
      _smartAnswerGroups = null;
      _smartPageRects.clear();
      _smartPointerDowns.clear();
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
    _smartPointerDowns.clear();
    _smartIndexRevision.dispose();
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
      if (!_lastSmartSnapEnabled) {
        _smartTapQueue.clear();
        _smartPointerDowns.clear();
      }
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
    _smartAnswerGroups = null;
    _smartPointerDowns.clear();
    final generation = ++_smartDocumentGeneration;
    _smartTapQueue.clear();
    _smartIndexStore.beginGeneration(generation);
    if (_showSmartPenDebugBounds) _smartIndexRevision.value++;
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
          includeDebugData: _showSmartPenDebugBounds,
        );
        _smartIndexStore.completePage(index);
        _refreshSmartAnswerGroups(generation, pageNumber);
      }
      if (_showSmartPenDebugBounds && mounted) {
        _smartIndexRevision.value++;
      }
      _resolveQueuedSmartTaps(pageNumber, generation);
    } catch (_) {
      if (generation != _smartDocumentGeneration) return;
      _smartIndexStore.failPage(pageNumber);
      if (_showSmartPenDebugBounds && mounted) {
        _smartIndexRevision.value++;
      }
      _resolveQueuedSmartTaps(pageNumber, generation);
    }
  }

  void _refreshSmartAnswerGroups(int generation, int changedPage) {
    final indexes = <int, SmartPenPageIndex>{};
    for (
      var page = 1;
      page <= (_smartIndexDocument?.pages.length ?? 0);
      page++
    ) {
      final index = _smartIndexStore.indexFor(page);
      if (index != null) indexes[page] = index;
    }
    if (generation != _smartDocumentGeneration) return;
    final next = SmartPenDocumentAnswerLinker.resolve(
      generation: generation,
      indexes: indexes,
      previous: _smartAnswerGroups,
      changedPage: changedPage,
    );
    final previous = _smartAnswerGroups;
    if (previous != null) {
      for (final entry in indexes.entries) {
        final oldCandidates = previous.candidatesForPage(entry.key);
        final newCandidates = next.candidatesForPage(entry.key);
        for (final old in oldCandidates) {
          final replacement = newCandidates
              .where(
                (candidate) =>
                    candidate.label == old.label &&
                    candidate.bounds == old.bounds,
              )
              .firstOrNull;
          if (replacement != null && replacement.groupId != old.groupId) {
            final affected = <int>{entry.key - 1, entry.key, entry.key + 1}
                .where(
                  (page) => next
                      .candidatesForPage(page)
                      .any(
                        (candidate) => candidate.groupId == replacement.groupId,
                      ),
                )
                .toSet();
            widget.studio.migrateSmartPenAnswerGroup(
              old.groupId,
              replacement.groupId,
              affectedPages: affected.toList(),
            );
          }
        }
      }
    }
    _smartAnswerGroups = next;
    if (_showSmartPenDebugBounds && mounted) _smartIndexRevision.value++;
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
      candidates: _smartAnswerGroups?.candidatesForPage(pageNumber),
    );
    final onSmartAnswerTap = widget.onSmartAnswerTap;
    if (candidate != null) {
      final selection = SmartPenAnswerSelection(
        pageNumber: pageNumber,
        label: candidate.label,
        bounds: candidate.bounds,
        groupId: candidate.groupId,
      );
      final affectedPages = <int>[];
      for (
        var page = 1;
        page <= (_smartIndexDocument?.pages.length ?? 0);
        page++
      ) {
        if (_smartAnswerGroups
                ?.candidatesForPage(page)
                .any((item) => item.groupId == candidate.groupId) ??
            false) {
          affectedPages.add(page);
        }
      }
      widget.studio.toggleSmartPenAnswer(
        selection,
        index.pageSize,
        affectedPages: affectedPages.isEmpty ? [pageNumber] : affectedPages,
      );
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

  Widget _buildPdfView() {
    return _getPdfViewerWidget();
  }
}

class _SmartPenDebugBoundsPainter extends CustomPainter {
  const _SmartPenDebugBoundsPainter({
    required this.candidates,
    required this.partialGroups,
    required this.partialGroupIds,
    required this.debugFragments,
    required this.linkedGroupIds,
    required this.pageSize,
  });

  final List<SmartPenAnswerCandidate> candidates;
  final List<SmartPenPartialAnswerGroup> partialGroups;
  final Set<String> partialGroupIds;
  final List<SmartPenDebugFragment> debugFragments;
  final Set<String> linkedGroupIds;
  final Size pageSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (pageSize.width <= 0 || pageSize.height <= 0) return;
    final fill = Paint()
      ..color = Colors.red.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final outline = Paint()
      ..color = Colors.red
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Rect scaleRect(Rect rect) => Rect.fromLTRB(
      rect.left / pageSize.width * size.width,
      rect.top / pageSize.height * size.height,
      rect.right / pageSize.width * size.width,
      rect.bottom / pageSize.height * size.height,
    );
    for (final diagnostic in debugFragments) {
      final bounds = scaleRect(diagnostic.fragment.bounds);
      final color = switch (diagnostic.decision) {
        SmartPenDebugDecision.raw => Colors.grey,
        SmartPenDebugDecision.accepted => Colors.green,
        SmartPenDebugDecision.partial => Colors.orange,
        SmartPenDebugDecision.rejected => Colors.red,
      };
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );
      canvas.drawRect(
        bounds,
        Paint()
          ..color = color.withValues(alpha: 0.75)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
      final rawText = diagnostic.fragment.text.trim();
      final shortText = rawText.length > 48
          ? '${rawText.substring(0, 45)}…'
          : rawText;
      final tag = TextPainter(
        text: TextSpan(
          text: diagnostic.decision == SmartPenDebugDecision.raw
              ? shortText
              : '${diagnostic.decision.name} · ${diagnostic.reasonCode} · $shortText',
          style: TextStyle(
            color: color,
            fontSize: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * 0.45);
      tag.paint(canvas, bounds.bottomLeft);
    }
    for (final candidate in candidates) {
      final bounds = scaleRect(candidate.bounds);
      canvas.drawRect(bounds, fill);
      canvas.drawRect(bounds, outline);
      final isPartial = partialGroupIds.contains(candidate.groupId);
      final questionHeading = partialGroups.any(
        (group) =>
            group.hasQuestionHeadingEvidence &&
            group.candidates.any(
              (item) =>
                  item.label == candidate.label &&
                  item.bounds == candidate.bounds,
            ),
      );
      final linkStatus = !isPartial
          ? 'local'
          : linkedGroupIds.contains(candidate.groupId)
          ? 'linked'
          : questionHeading
          ? 'unlinked: question_heading'
          : 'unlinked: no_unique_continuation';
      final label = TextPainter(
        text: TextSpan(
          text: '${candidate.label} · ${candidate.groupId} · $linkStatus',
          style: const TextStyle(
            color: Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, bounds.topLeft - const Offset(0, 11));
    }
  }

  @override
  bool shouldRepaint(covariant _SmartPenDebugBoundsPainter oldDelegate) =>
      oldDelegate.candidates != candidates ||
      oldDelegate.partialGroups != partialGroups ||
      oldDelegate.partialGroupIds != partialGroupIds ||
      oldDelegate.debugFragments != debugFragments ||
      oldDelegate.linkedGroupIds != linkedGroupIds ||
      oldDelegate.pageSize != pageSize;
}

