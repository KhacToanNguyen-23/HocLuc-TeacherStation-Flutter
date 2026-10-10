import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import 'pdf_stage.dart';

class FloatingPdfWindow extends StatefulWidget {
  const FloatingPdfWindow({
    super.key,
    required this.studio,
    required this.boardConstraints,
    this.interactive = true,
  });

  final StudioState studio;
  final BoxConstraints boardConstraints;
  final bool interactive;

  @override
  State<FloatingPdfWindow> createState() => _FloatingPdfWindowState();
}

class _FloatingPdfWindowState extends State<FloatingPdfWindow> {
  late final ValueNotifier<Offset> _posNotifier;
  late final ValueNotifier<Size> _sizeNotifier;
  bool _isDragging = false;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    final boardH = widget.boardConstraints.maxHeight > 0
        ? widget.boardConstraints.maxHeight
        : 720.0;
    final boardW = widget.boardConstraints.maxWidth > 0
        ? widget.boardConstraints.maxWidth
        : 1280.0;
    final defaultW = (boardH * 0.72).clamp(360.0, boardW * 0.65);
    final defaultH = boardH;

    final initialSize = widget.studio.hasCustomPdfWindowSize
        ? widget.studio.pdfWindowSize
        : Size(defaultW, defaultH);

    final initialPos = widget.studio.hasCustomPdfWindowPos
        ? widget.studio.pdfWindowPosition
        : const Offset(0, 0);

    _posNotifier = ValueNotifier(initialPos);
    _sizeNotifier = ValueNotifier(initialSize);
  }

  @override
  void didUpdateWidget(covariant FloatingPdfWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.studio.hasCustomPdfWindowSize &&
        widget.boardConstraints.maxHeight > 0 &&
        _sizeNotifier.value.height != widget.boardConstraints.maxHeight) {
      final boardH = widget.boardConstraints.maxHeight;
      final boardW = widget.boardConstraints.maxWidth;
      final defaultW = (boardH * 0.72).clamp(360.0, boardW * 0.65);
      _sizeNotifier.value = Size(defaultW, boardH);
    }
    if (!_isDragging &&
        widget.studio.hasCustomPdfWindowPos &&
        _posNotifier.value != widget.studio.pdfWindowPosition) {
      _posNotifier.value = widget.studio.pdfWindowPosition;
    }
    if (!_isResizing &&
        widget.studio.hasCustomPdfWindowSize &&
        _sizeNotifier.value != widget.studio.pdfWindowSize) {
      _sizeNotifier.value = widget.studio.pdfWindowSize;
    }
  }

  @override
  void dispose() {
    _posNotifier.dispose();
    _sizeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;

    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final doc = studio.activeDoc;
        final docName =
            doc?.name ??
            (studio.pdfFilePath != null
                ? studio.pdfFilePath!.split(RegExp(r'[\\/]')).last
                : 'Tài liệu bài giảng.pdf');

        if (studio.pdfWindowMaximized) {
          return Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xff182721),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x44ffffff),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 20,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _buildHeader(context, docName, isMaximized: true),
                    Expanded(
                      child: RepaintBoundary(
                        child: PdfStage(
                          studio: studio,
                          interactive: widget.interactive,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final maxW = math.max(360.0, widget.boardConstraints.maxWidth);
        final maxH = math.max(280.0, widget.boardConstraints.maxHeight);

        return ListenableBuilder(
          listenable: Listenable.merge([_posNotifier, _sizeNotifier]),
          builder: (context, _) {
            final cardW = _sizeNotifier.value.width.clamp(340.0, maxW * 0.95);
            final cardH = _sizeNotifier.value.height.clamp(260.0, maxH);

            final maxX = math.max(
              0.0,
              widget.boardConstraints.maxWidth - cardW,
            );
            final maxY = math.max(
              0.0,
              widget.boardConstraints.maxHeight - cardH,
            );

            final posX = _posNotifier.value.dx.clamp(0.0, maxX);
            final posY = _posNotifier.value.dy.clamp(0.0, maxY);

            return Positioned(
              left: posX,
              top: posY,
              width: cardW,
              height: cardH,
              child: RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xff182721),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x44ffffff),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          _buildHeader(context, docName, isMaximized: false),
                          Expanded(
                            child: RepaintBoundary(
                              child: PdfStage(
                                studio: studio,
                                interactive: widget.interactive,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Resize handle at bottom-right corner
                      if (widget.interactive)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeDownRight,
                            child: GestureDetector(
                              onPanStart: (_) => _isResizing = true,
                              onPanUpdate: (d) {
                                final current = _sizeNotifier.value;
                                final newW = math.max(
                                  340.0,
                                  current.width + d.delta.dx,
                                );
                                final newH = math.max(
                                  260.0,
                                  current.height + d.delta.dy,
                                );
                                _sizeNotifier.value = Size(
                                  newW.clamp(340.0, maxW * 0.95),
                                  newH.clamp(260.0, maxH),
                                );
                              },
                              onPanEnd: (_) {
                                _isResizing = false;
                                studio.setPdfWindowSize(_sizeNotifier.value);
                              },
                              onPanCancel: () => _isResizing = false,
                              child: Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.bottomRight,
                                padding: const EdgeInsets.all(3),
                                child: const Icon(
                                  Icons.south_east,
                                  size: 14,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String docName, {
    required bool isMaximized,
  }) {
    final studio = widget.studio;

    return GestureDetector(
      onPanStart: isMaximized || !widget.interactive
          ? null
          : (_) => _isDragging = true,
      onPanUpdate: isMaximized || !widget.interactive
          ? null
          : (d) {
              final current = _posNotifier.value;
              final maxW = math.max(360.0, widget.boardConstraints.maxWidth);
              final maxH = math.max(280.0, widget.boardConstraints.maxHeight);
              final cardW = _sizeNotifier.value.width.clamp(340.0, maxW * 0.95);
              final cardH = _sizeNotifier.value.height.clamp(260.0, maxH);
              final maxX = math.max(
                0.0,
                widget.boardConstraints.maxWidth - cardW,
              );
              final maxY = math.max(
                0.0,
                widget.boardConstraints.maxHeight - cardH,
              );

              _posNotifier.value = Offset(
                (current.dx + d.delta.dx).clamp(0.0, maxX),
                (current.dy + d.delta.dy).clamp(0.0, maxY),
              );
            },
      onPanEnd: isMaximized || !widget.interactive
          ? null
          : (_) {
              _isDragging = false;
              studio.setPdfWindowPosition(_posNotifier.value);
            },
      onPanCancel: isMaximized || !widget.interactive
          ? null
          : () => _isDragging = false,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
          color: Color(0xff14201b),
          border: Border(bottom: BorderSide(color: Color(0x22ffffff))),
        ),
        child: Row(
          children: [
            // Drag Indicator & Icon
            const Icon(Icons.drag_indicator, size: 16, color: Colors.white38),
            const SizedBox(width: 4),
            const Icon(
              Icons.picture_as_pdf,
              size: 16,
              color: Color(0xffff6b6b),
            ),
            const SizedBox(width: 6),
            // Document title
            Expanded(
              child: Tooltip(
                message: docName,
                child: Text(
                  docName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Page navigation: < 1 / 12 >
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Trang trước',
              onPressed: studio.pdfPage > 1
                  ? () => studio.setPdfPage(studio.pdfPage - 1)
                  : null,
              icon: Icon(
                Icons.chevron_left,
                size: 18,
                color: studio.pdfPage > 1 ? Colors.white70 : Colors.white24,
              ),
            ),
            Text(
              '${studio.pdfPage}/${studio.pdfTotalPages}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xffd4e8a6),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Trang sau',
              onPressed: studio.pdfPage < studio.pdfTotalPages
                  ? () => studio.setPdfPage(studio.pdfPage + 1)
                  : null,
              icon: Icon(
                Icons.chevron_right,
                size: 18,
                color: studio.pdfPage < studio.pdfTotalPages
                    ? Colors.white70
                    : Colors.white24,
              ),
            ),
            const SizedBox(width: 4),
            // Fit Page / Fit Width toggle button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: studio.pdfFitPage
                  ? 'Vừa chiều rộng (Fit Width)'
                  : 'Xem toàn bộ trang (Fit Page)',
              onPressed: studio.togglePdfFit,
              icon: Icon(
                studio.pdfFitPage ? Icons.fit_screen : Icons.aspect_ratio,
                size: 18,
                color: studio.pdfFitPage
                    ? const Color(0xffd4e8a6)
                    : Colors.white70,
              ),
            ),
            const SizedBox(width: 2),
            // Clear page annotations button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Xóa nét vẽ trên trang này',
              onPressed: studio.currentPdfStrokes.isNotEmpty
                  ? studio.clearPdfPage
                  : null,
              icon: Icon(
                Icons.clear_all,
                size: 18,
                color: studio.currentPdfStrokes.isNotEmpty
                    ? const Color(0xffffa089)
                    : Colors.white24,
              ),
            ),
            const SizedBox(width: 2),
            // Open / Pick another PDF file
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Đổi / Mở tệp PDF',
              onPressed: studio.importPdfDialog,
              icon: const Icon(
                Icons.folder_open_outlined,
                size: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 2),
            // Maximize / Restore
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: isMaximized
                  ? 'Thu nhỏ cửa sổ'
                  : 'Phóng to toàn màn hình',
              onPressed: studio.togglePdfWindowMaximized,
              icon: Icon(
                isMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                size: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(width: 2),
            // Close window button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Đóng tài liệu trên bảng',
              onPressed: studio.closeDocOnBoard,
              icon: const Icon(Icons.close, size: 18, color: Color(0xffff8585)),
            ),
          ],
        ),
      ),
    );
  }
}
