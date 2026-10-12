import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../models/studio_state.dart';

class StudioDocumentFilesList extends StatefulWidget {
  const StudioDocumentFilesList({super.key, required this.studio});

  final StudioState studio;

  @override
  State<StudioDocumentFilesList> createState() => _StudioDocumentFilesListState();
}

class _StudioDocumentFilesListState extends State<StudioDocumentFilesList> {
  bool _isDragging = false;

  Widget _buildSectionDivider() {
    final studio = widget.studio;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0x28ffffff), height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.folder_open_outlined,
                  size: 12,
                  color: Color(0xff8a9a8d),
                ),
                const SizedBox(width: 4),
                Text(
                  'TỆP TÀI LIỆU (${studio.importedDocs.length})',
                  style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: Color(0xff8a9a8d),
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: Divider(color: Color(0x28ffffff), height: 1)),
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _isDragging ? const Color(0x33d4e8a6) : const Color(0x14ffffff),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isDragging ? AppColors.lime : const Color(0x2effffff),
            width: _isDragging ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              _isDragging ? Icons.file_download_outlined : Icons.upload_file_outlined,
              size: 16,
              color: _isDragging ? AppColors.lime : const Color(0xffa5b5a8),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _isDragging ? 'Thả tệp vào đây' : 'Kéo thả PDF /',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: _isDragging ? AppColors.lime : const Color(0xffa5b5a8),
                ),
              ),
            ),
            InkWell(
              onTap: studio.importPdfDialog,
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lime,
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
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: isActiveOnBoard ? const Color(0x2ed4e8a6) : const Color(0x14ffffff),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActiveOnBoard ? AppColors.lime : const Color(0x22ffffff),
            width: isActiveOnBoard ? 1.3 : 1.0,
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
                  color: isActiveOnBoard ? AppColors.lime : const Color(0xffe57373),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isActiveOnBoard ? FontWeight.w700 : FontWeight.w500,
                      color: isActiveOnBoard ? AppColors.lime : const Color(0xffe8eae6),
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
                        color: Color(0xff8a9a8d),
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
                    color: Color(0xff8a9a8d),
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
                      color: const Color(0x33d4e8a6),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text(
                      'Đang mở',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.lime,
                      ),
                    ),
                  )
                else
                  const Text(
                    'Kéo vào bảng',
                    style: TextStyle(fontSize: 8, color: Color(0xff6e7e72)),
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
              color: const Color(0xee102019),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.lime, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 12,
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
                  color: AppColors.lime,
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
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Text(
                'Chưa có tài liệu nào\nKéo thả tệp hoặc bấm + Nhập tệp',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: Color(0xff6e7e72),
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
