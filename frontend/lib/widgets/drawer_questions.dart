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

            // Animated Compact Drawer Panel (width: 252)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: isOpen ? 0 : -256,
              top: 0,
              bottom: 0,
              width: 252,
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
                              '${studio.pages.length} trang${studio.importedDocs.isNotEmpty ? " · ${studio.importedDocs.length} tệp" : ""}',
                              style: const TextStyle(
                                fontSize: 8.5,
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

                    // Scrollable Drawer Content (Pages + Divider + Documents)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                        children: [
                          // 1. CÁC TRANG BÀI GIẢNG
                          Row(
                            children: [
                              const Icon(
                                Icons.layers_outlined,
                                size: 13,
                                color: Color(0xffd4e8a6),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'TRANG BÀI GIẢNG',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xffd4e8a6),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'P.${studio.page + 1}/${studio.pages.length}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xffa5b5a8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          for (int i = 0; i < studio.pages.length; i++)
                            _buildPageItem(studio, i),
                          _buildAddPageButton(studio),

                          // 2. PHÂN CÁCH NGĂN CÁCH VỚI CÁC TỆP FILE
                          _buildSectionDivider(studio),

                          // 3. DANH SÁCH TỆP TÀI LIỆU (PDF)
                          _buildDropTargetBar(studio),
                          const SizedBox(height: 6),
                          if (studio.importedDocs.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: const Text(
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
                                studio,
                                doc,
                                doc.id == studio.activeDocId &&
                                    studio.viewportMode !=
                                        StudioViewportMode.fullBoard,
                              ),
                        ],
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

  Future<void> _showRenamePageDialog(int index) async {
    final studio = widget.studio;
    final currentTitle = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final input = TextEditingController(text: currentTitle);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Đổi tên Trang ${index + 1}'),
        content: TextField(
          controller: input,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Nhập tiêu đề trang...'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xff2d4c3d),
              foregroundColor: const Color(0xffd4e8a6),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    input.dispose();
    if (result != null && result.isNotEmpty) {
      studio.renamePage(index, result);
    }
  }

  Future<void> _confirmDeletePage(int index) async {
    final studio = widget.studio;
    if (studio.pages.length <= 1) return;
    final pageTitle = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final hasStrokes = studio.pages[index].isNotEmpty;

    if (hasStrokes) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận xóa trang'),
          content: Text(
            'Trang "$pageTitle" đang có nét vẽ bài giảng. Bạn có chắc chắn muốn xóa không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffc2410c),
              ),
              child: const Text('Xóa trang'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        studio.deletePage(index);
      }
    } else {
      studio.deletePage(index);
    }
  }

  Widget _buildPageItem(StudioState studio, int index) {
    final isCurrent = studio.page == index && studio.view == 'board';
    final label = index < studio.pageTitles.length
        ? studio.pageTitles[index]
        : 'Trang ${index + 1}';
    final hasStrokes = studio.pages[index].isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        onTap: () => studio.change(() {
          studio.setPage(index);
          studio.view = 'board';
        }),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? const Color(0x33d4e8a6)
                : const Color(0x14ffffff),
            border: Border.all(
              color: isCurrent
                  ? const Color(0xffd4e8a6)
                  : const Color(0x22ffffff),
              width: isCurrent ? 1.4 : 1.0,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xffd4e8a6)
                      : const Color(0x24ffffff),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: isCurrent
                          ? const Color(0xff14221d)
                          : const Color(0xffd0ded3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                    color: isCurrent ? Colors.white : const Color(0xffe0eae2),
                  ),
                ),
              ),
              Tooltip(
                message: 'Đổi tên trang',
                child: InkWell(
                  onTap: () => _showRenamePageDialog(index),
                  borderRadius: BorderRadius.circular(4),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.edit_outlined,
                      size: 13,
                      color: Color(0xffa5b5a8),
                    ),
                  ),
                ),
              ),
              if (studio.pages.length > 1) ...[
                const SizedBox(width: 3),
                Tooltip(
                  message: 'Xóa trang này',
                  child: InkWell(
                    onTap: () => _confirmDeletePage(index),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_outline,
                        size: 13,
                        color: Color(0xffff7b7b),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                hasStrokes ? Icons.draw_outlined : Icons.crop_portrait,
                size: 12,
                color: isCurrent
                    ? const Color(0xffd4e8a6)
                    : const Color(0x55ffffff),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddPageButton(StudioState studio) {
    return InkWell(
      onTap: () => studio.change(() {
        studio.addPage();
        studio.view = 'board';
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        decoration: BoxDecoration(
          color: const Color(0x18d4e8a6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x44d4e8a6)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 14, color: Color(0xffd4e8a6)),
            SizedBox(width: 4),
            Text(
              'Thêm trang bài giảng',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: Color(0xffd4e8a6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(StudioState studio) {
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

  Widget _buildDropTargetBar(StudioState studio) {
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
                _isDragging ? 'Thả tệp vào đây' : 'Kéo thả PDF /',
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
