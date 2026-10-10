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
            final cardW = _sizeNotifier.value.width.clamp(340.0, maxW);
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
                      // Right border resize handle (Kéo mép phải mở rộng ngang)
                      if (widget.interactive)
                        Positioned(
                          top: 38,
                          right: 0,
                          bottom: 22,
                          width: 8,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              onPanStart: (_) => _isResizing = true,
                              onPanUpdate: (d) {
                                final current = _sizeNotifier.value;
                                final newW = math.max(
                                  340.0,
                                  current.width + d.delta.dx,
                                );
                                _sizeNotifier.value = Size(
                                  newW.clamp(340.0, maxW),
                                  current.height,
                                );
                              },
                              onPanEnd: (_) {
                                _isResizing = false;
                                studio.setPdfWindowSize(_sizeNotifier.value);
                              },
                              onPanCancel: () => _isResizing = false,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                        ),
                      // Bottom border resize handle (Kéo mép đáy mở rộng dọc)
                      if (widget.interactive)
                        Positioned(
                          left: 0,
                          right: 22,
                          bottom: 0,
                          height: 8,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              onPanStart: (_) => _isResizing = true,
                              onPanUpdate: (d) {
                                final current = _sizeNotifier.value;
                                final newH = math.max(
                                  260.0,
                                  current.height + d.delta.dy,
                                );
                                _sizeNotifier.value = Size(
                                  current.width,
                                  newH.clamp(260.0, maxH),
                                );
                              },
                              onPanEnd: (_) {
                                _isResizing = false;
                                studio.setPdfWindowSize(_sizeNotifier.value);
                              },
                              onPanCancel: () => _isResizing = false,
                              child: Container(color: Colors.transparent),
                            ),
                          ),
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
                                  newW.clamp(340.0, maxW),
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
        child: LayoutBuilder(
          builder: (context, headerBox) {
            final isNarrow = headerBox.maxWidth < 580;
            return Row(
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
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
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
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
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
                const SizedBox(width: 3),
                // Zoom out [ - ]
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  tooltip: 'Thu nhỏ tài liệu',
                  onPressed: studio.zoomOutPdf,
                  icon: const Icon(
                    Icons.remove,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
                // Fit Page / Fit Width toggle button
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: studio.pdfFitPage
                      ? 'Vừa chiều rộng (Fit Width)'
                      : 'Xem toàn bộ trang (Fit Page)',
                  onPressed: studio.togglePdfFit,
                  icon: Icon(
                    studio.pdfFitPage ? Icons.fit_screen : Icons.aspect_ratio,
                    size: 17,
                    color: studio.pdfFitWidth
                        ? const Color(0xffd4e8a6)
                        : Colors.white70,
                  ),
                ),
                // Zoom in [ + ]
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  tooltip: 'Phóng to tài liệu',
                  onPressed: studio.zoomInPdf,
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: Colors.white70,
                  ),
                ),
                if (!isNarrow) ...[
                  const SizedBox(width: 2),
                  // Pan tool toggle (Bàn tay kéo cuộn trang)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: studio.tool == 'pan'
                        ? 'Đang kéo di chuyển (Bấm để quay lại Bút vẽ)'
                        : 'Bàn tay (Kéo cuộn trang bài giảng)',
                    onPressed: () {
                      studio.change(
                        () => studio.tool = studio.tool == 'pan' ? 'pen' : 'pan',
                        persist: false,
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: studio.tool == 'pan'
                          ? const Color(0xff2d4c3d)
                          : Colors.transparent,
                    ),
                    icon: Icon(
                      Icons.pan_tool_outlined,
                      size: 15,
                      color: studio.tool == 'pan'
                          ? const Color(0xffd4e8a6)
                          : Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Clear page annotations button
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Xóa nét vẽ trên trang này',
                    onPressed: studio.currentPdfStrokes.isNotEmpty
                        ? studio.clearPdfPage
                        : null,
                    icon: Icon(
                      Icons.clear_all,
                      size: 17,
                      color: studio.currentPdfStrokes.isNotEmpty
                          ? const Color(0xffffa089)
                          : Colors.white24,
                    ),
                  ),
                  const SizedBox(width: 2),
                  // Open / Pick another PDF file
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    tooltip: 'Đổi / Mở tệp PDF',
                    onPressed: studio.importPdfDialog,
                    icon: const Icon(
                      Icons.folder_open_outlined,
                      size: 17,
                      color: Colors.white70,
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                // Maximize / Restore
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  tooltip: 'Đóng tài liệu trên bảng',
                  onPressed: studio.closeDocOnBoard,
                  icon: const Icon(Icons.close, size: 18, color: Color(0xffff8585)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
