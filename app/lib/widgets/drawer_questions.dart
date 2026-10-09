import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import '../models/studio_state.dart';

class DrawerQuestions extends StatefulWidget {
  const DrawerQuestions({super.key, required this.studio});

  final StudioState studio;

  @override
  State<DrawerQuestions> createState() => _DrawerQuestionsState();
}

class _DrawerQuestionsState extends State<DrawerQuestions> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;

    return ListenableBuilder(
      listenable: studio,
      builder: (context, _) {
        final isOpen = studio.showQuestionsDrawer;

        return Stack(
          children: [
            // Backdrop to dismiss on outside click
            if (isOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => studio.setQuestionsDrawer(false),
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.transparent),
                ),
              ),

            // Animated Compact Drawer Panel (width: 236)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: isOpen ? 0 : -240,
              top: 0,
              bottom: 0,
              width: 236,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xf70e1a15),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: const Color(0x33ffffff),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 18,
                      offset: Offset(3, 0),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Compact Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0x22ffffff)),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 15,
                            color: Color(0xffd4e8a6),
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Tài liệu giảng dạy',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xffe8eae6),
                              ),
                            ),
                          ),
                          if (studio.importedDocs.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: const Color(0x28d4e8a6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${studio.importedDocs.length}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xffd4e8a6),
                                ),
                              ),
                            ),
                          InkWell(
                            onTap: () => studio.setQuestionsDrawer(false),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Color(0xffa5b5a8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Compact Import / Drop Bar (no verbose texts)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: DropTarget(
                        onDragEntered: (_) =>
                            setState(() => _isDragging = true),
                        onDragExited: (_) =>
                            setState(() => _isDragging = false),
                        onDragDone: (detail) async {
                          setState(() => _isDragging = false);
                          for (final file in detail.files) {
                            if (file.name.toLowerCase().endsWith('.pdf')) {
                              final bytes = await file.readAsBytes();
                              studio.addImportedDoc(
                                file.name,
                                file.path,
                                bytes,
                              );
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _isDragging
                                ? const Color(0x33d4e8a6)
                                : const Color(0x14ffffff),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _isDragging
                                  ? const Color(0xffd4e8a6)
                                  : const Color(0x2effffff),
                              width: _isDragging ? 1.5 : 1.0,
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
                                    ? const Color(0xffd4e8a6)
                                    : const Color(0xffa5b5a8),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _isDragging
                                      ? 'Thả tệp vào đây'
                                      : 'Kéo thả PDF /',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _isDragging
                                        ? const Color(0xffd4e8a6)
                                        : const Color(0xffa5b5a8),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: studio.importPdfDialog,
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xffd4e8a6),
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
                      ),
                    ),

                    // Document List
                    Expanded(
                      child: studio.importedDocs.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: Text(
                                  'Chưa có tài liệu nào\nKéo thả tệp hoặc bấm + Nhập tệp',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    height: 1.4,
                                    color: Color(0xff6e7e72),
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                              itemCount: studio.importedDocs.length,
                              itemBuilder: (context, index) {
                                final doc = studio.importedDocs[index];
                                final isActiveOnBoard =
                                    doc.id == studio.activeDocId &&
                                    studio.viewportMode !=
                                        StudioViewportMode.fullBoard;
                                return _buildDraggableDocItem(
                                  studio,
                                  doc,
                                  isActiveOnBoard,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            // Sleek Collapsible Pull Tab on left edge of the chalkboard
            if (!isOpen)
              Positioned(
                left: 0,
                top: 36,
                child: Tooltip(
                  message:
                      'Tài liệu giảng dạy (${studio.importedDocs.length} tệp)',
                  child: InkWell(
                    onTap: () => studio.setQuestionsDrawer(true),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(7),
                      bottomRight: Radius.circular(7),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xee112019),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                        border: Border.all(color: const Color(0x33ffffff)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x55000000),
                            blurRadius: 6,
                            offset: Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 13,
                            color: Color(0xffd4e8a6),
                          ),
                          if (studio.importedDocs.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xff2b4d3f),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${studio.importedDocs.length}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xffd4e8a6),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right,
                            size: 12,
                            color: Color(0xffa5b5a8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDraggableDocItem(
    StudioState studio,
    ImportedDocument doc,
    bool isActiveOnBoard,
  ) {
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
              border: Border.all(color: const Color(0xffd4e8a6), width: 1.5),
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
                  color: Color(0xffd4e8a6),
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
          child: _buildDocCard(studio, doc, isActiveOnBoard),
        ),
        child: _buildDocCard(studio, doc, isActiveOnBoard),
      ),
    );
  }

  Widget _buildDocCard(
    StudioState studio,
    ImportedDocument doc,
    bool isActiveOnBoard,
  ) {
    return InkWell(
      onTap: () {
        studio.selectDoc(doc.id, targetMode: StudioViewportMode.split);
      },
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: isActiveOnBoard
              ? const Color(0x2ed4e8a6)
              : const Color(0x14ffffff),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActiveOnBoard
                ? const Color(0xffd4e8a6)
                : const Color(0x22ffffff),
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
                  color: isActiveOnBoard
                      ? const Color(0xffd4e8a6)
                      : const Color(0xffe57373),
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
                          ? const Color(0xffd4e8a6)
                          : const Color(0xffe8eae6),
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
                        color: Color(0xffd4e8a6),
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
}
