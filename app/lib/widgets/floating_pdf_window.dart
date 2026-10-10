import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/studio_state.dart';
import 'pdf_stage.dart';

class FloatingPdfWindow extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xff182721),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0x44ffffff), width: 1.5),
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
                    child: PdfStage(studio: studio, interactive: interactive),
                  ),
                ],
              ),
            ),
          );
        }

        final maxW = math.max(360.0, boardConstraints.maxWidth);
        final maxH = math.max(280.0, boardConstraints.maxHeight);

        final cardW = studio.pdfWindowSize.width.clamp(340.0, maxW * 0.95);
        final cardH = studio.pdfWindowSize.height.clamp(260.0, maxH * 0.95);

        final maxX = math.max(0.0, boardConstraints.maxWidth - cardW);
        final maxY = math.max(0.0, boardConstraints.maxHeight - cardH);

        final posX = studio.pdfWindowPosition.dx.clamp(0.0, maxX);
        final posY = studio.pdfWindowPosition.dy.clamp(0.0, maxY);

        return Positioned(
          left: posX,
          top: posY,
          width: cardW,
          height: cardH,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff182721),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x44ffffff), width: 1.5),
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
                      child: PdfStage(studio: studio, interactive: interactive),
                    ),
                  ],
                ),
                // Resize handle at bottom-right corner
                if (interactive)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeDownRight,
                      child: GestureDetector(
                        onPanUpdate: (d) {
                          final newW = math.max(340.0, cardW + d.delta.dx);
                          final newH = math.max(260.0, cardH + d.delta.dy);
                          studio.setPdfWindowSize(Size(newW, newH));
                        },
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
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String docName, {
    required bool isMaximized,
  }) {
    return GestureDetector(
      onPanUpdate: isMaximized || !interactive
          ? null
          : (d) {
              final newPos = studio.pdfWindowPosition + d.delta;
              studio.setPdfWindowPosition(newPos);
            },
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
            // Page controls
            if (studio.pdfTotalPages > 1) ...[
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Trang trước',
                onPressed: studio.pdfPage > 1
                    ? () => studio.setPdfPage(studio.pdfPage - 1)
                    : null,
                icon: const Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: Colors.white70,
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
                icon: const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
            ],
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
