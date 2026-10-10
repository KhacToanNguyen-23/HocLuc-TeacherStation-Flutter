import 'dart:typed_data';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/studio_state.dart';
import 'grid_painter.dart';
import 'stroke_canvas.dart';

class PdfStage extends StatefulWidget {
  const PdfStage({super.key, required this.studio, this.interactive = true});

  final StudioState studio;
  final bool interactive;

  @override
  State<PdfStage> createState() => _PdfStageState();
}

class _PdfStageState extends State<PdfStage> {
  final PdfViewerController _pdfController = PdfViewerController();
  bool _isDragging = false;

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
    final studio = widget.studio;
    final hasPdf = studio.pdfFilePath != null || studio.pdfBytes != null;

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
      onPageChanged: (page) {
        if (page != null && page != studio.pdfPage) {
          studio.setPdfPage(page);
        }
      },
      onDocumentChanged: (doc) {
        if (doc != null && doc.pages.length != studio.pdfTotalPages) {
          studio.setPdfTotalPages(doc.pages.length);
        }
      },
    );

    _cachedPdfViewer = RepaintBoundary(
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
    final studio = widget.studio;

    return Stack(
      children: [
        // PDF Render Layer (cached & RepaintBoundary isolated)
        Positioned.fill(child: _getPdfViewerWidget()),

        // Transparent Per-Page Annotation Layer (RepaintBoundary isolated)
        Positioned.fill(
          child: RepaintBoundary(
            child: StrokeCanvas(
              studio: studio,
              targetStrokes: studio.currentPdfStrokes,
              interactive: widget.interactive,
            ),
          ),
        ),

        // Floating PDF Navigation Header
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xee14221d),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x22ffffff)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.picture_as_pdf,
                  size: 16,
                  color: Color(0xffd4e8a6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    studio.pdfFilePath?.split(RegExp(r'[\\/]')).last ??
                        'Tài liệu PDF',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xffe8eae6),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Page controls
                IconButton(
                  tooltip: 'Trang trước',
                  icon: const Icon(Icons.chevron_left, size: 18),
                  color: const Color(0xffe8eae6),
                  onPressed: studio.pdfPage > 1
                      ? () {
                          final prev = studio.pdfPage - 1;
                          studio.setPdfPage(prev);
                          _pdfController.goToPage(pageNumber: prev);
                        }
                      : null,
                ),
                Text(
                  '${studio.pdfPage} / ${studio.pdfTotalPages}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xffd4e8a6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  tooltip: 'Trang sau',
                  icon: const Icon(Icons.chevron_right, size: 18),
                  color: const Color(0xffe8eae6),
                  onPressed: studio.pdfPage < studio.pdfTotalPages
                      ? () {
                          final next = studio.pdfPage + 1;
                          studio.setPdfPage(next);
                          _pdfController.goToPage(pageNumber: next);
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                // Actions
                IconButton(
                  tooltip: 'Xóa nét vẽ trang này',
                  icon: const Icon(Icons.clear_all, size: 18),
                  color: const Color(0xffffa089),
                  onPressed: studio.currentPdfStrokes.isNotEmpty
                      ? studio.clearPdfPage
                      : null,
                ),
                if (studio.viewportMode == StudioViewportMode.split)
                  IconButton(
                    tooltip: studio.pdfOnRight
                        ? 'Chuyển tài liệu sang bên Trái'
                        : 'Chuyển tài liệu sang bên Phải',
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    color: const Color(0xffd4e8a6),
                    onPressed: studio.togglePdfPosition,
                  ),
                IconButton(
                  tooltip: 'Đổi tệp PDF khác',
                  icon: const Icon(Icons.folder_open_outlined, size: 18),
                  color: const Color(0xffe8eae6),
                  onPressed: _pickFile,
                ),
                IconButton(
                  tooltip: 'Đóng tài liệu trên bảng (về bảng vẽ)',
                  icon: const Icon(Icons.close, size: 18),
                  color: const Color(0xffe8eae6),
                  onPressed: studio.closeDocOnBoard,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
