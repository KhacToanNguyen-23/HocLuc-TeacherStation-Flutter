import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:teaching_companion/core/theme/theme.dart';
import 'package:teaching_companion/features/studio_board/domain/models/studio_state.dart';

class StudioDocumentFilesList extends StatefulWidget {
  const StudioDocumentFilesList({super.key, required this.studio});

  final StudioState studio;

  @override
  State<StudioDocumentFilesList> createState() =>
      _StudioDocumentFilesListState();
}

class _StudioDocumentFilesListState extends State<StudioDocumentFilesList> {
  bool _isDragging = false;

  Widget _buildSectionDivider() {
    final studio = widget.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(
            child: Divider(color: AppColors.overlayBorder, height: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_open_outlined,
                  size: 12,
                  color: AppColors.overlayMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'TỆP TÀI LIỆU (${studio.importedDocs.length})',
                  style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.overlayMuted,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Divider(color: AppColors.overlayBorder, height: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDropTargetBar() {
    final studio = widget.studio;
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (detail) async {
        setState(() => _isDragging = false);
        for (final file in detail.files) {
          if (file.name.toLowerCase().endsWith('.pdf')) {
            final bytes = await file.readAsBytes();
            studio.addImportedDoc(file.name, file.path, bytes);
          }
        }
      },
      child: AnimatedContainer(
        duration: AppMotion.duration(context, milliseconds: 150),
        curve: AppMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _isDragging
              ? AppColors.overlaySelected
              : AppColors.overlayRaised,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: _isDragging ? AppColors.overlayAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isDragging
                  ? Icons.file_download_outlined
                  : Icons.upload_file_outlined,
              size: 16,
              color: _isDragging
                  ? AppColors.overlayAccent
                  : AppColors.overlayMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isDragging ? 'Thả tệp vào đây' : 'Kéo thả PDF /',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: _isDragging
                      ? AppColors.overlayAccent
                      : AppColors.overlayMuted,
                ),
              ),
            ),
            InkWell(
              onTap: studio.importPdfDialog,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.overlayAccent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '+ Nhập tệp',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff14221d),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocCard(ImportedDocument doc, bool isActiveOnBoard) {
    final studio = widget.studio;
    return InkWell(
      onTap: () {
        studio.selectDoc(doc.id, targetMode: StudioViewportMode.split);
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: AppMotion.duration(context, milliseconds: 150),
        curve: AppMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: isActiveOnBoard
              ? AppColors.overlaySelected
              : AppColors.overlayRaised,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActiveOnBoard
                ? AppColors.overlayAccent
                : Colors.transparent,
            width: 1.3,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 14,
                  color: isActiveOnBoard
                      ? AppColors.overlayAccent
                      : AppColors.errorSurface,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isActiveOnBoard
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isActiveOnBoard
                          ? AppColors.overlayAccent
                          : AppColors.overlayText,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Xóa tệp khỏi khay',
                  child: InkWell(
                    onTap: () => studio.removeDoc(doc.id),
                    borderRadius: BorderRadius.circular(3),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: AppColors.overlayMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${doc.totalPages > 1 ? "${doc.totalPages} trang" : "1 trang"}${doc.formattedSize.isNotEmpty ? " · ${doc.formattedSize}" : ""}',
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AppColors.overlayMuted,
                  ),
                ),
                const Spacer(),
                if (isActiveOnBoard)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.overlaySelected,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Đang mở',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.overlayAccent,
                      ),
                    ),
                  )
                else
                  const Text(
                    'Kéo vào bảng',
                    style: TextStyle(
                      fontSize: 8,
                      color: AppColors.overlayMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableDocItem(ImportedDocument doc, bool isActiveOnBoard) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Draggable<ImportedDocument>(
        data: doc,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.overlaySurface,
              borderRadius: BorderRadius.circular(AppRadii.control),
              border: Border.all(color: AppColors.overlayAccent, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 14,
                  color: AppColors.overlayAccent,
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    doc.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _buildDocCard(doc, isActiveOnBoard),
        ),
        child: _buildDocCard(doc, isActiveOnBoard),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionDivider(),
        _buildDropTargetBar(),
        const SizedBox(height: 6),
        if (studio.importedDocs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Text(
                'Chưa có tài liệu nào\nKéo thả tệp hoặc bấm + Nhập tệp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: AppColors.overlayMuted,
                ),
              ),
            ),
          )
        else
          for (final doc in studio.importedDocs)
            _buildDraggableDocItem(
              doc,
              doc.id == studio.activeDocId &&
                  studio.viewportMode != StudioViewportMode.fullBoard,
            ),
      ],
    );
  }
}

