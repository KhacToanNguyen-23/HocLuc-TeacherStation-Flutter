import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../models/studio_state.dart';
import '../services/plugin_manager.dart';

class DrawerQuestions extends StatefulWidget {
  const DrawerQuestions({super.key, required this.studio});

  final StudioState studio;

  @override
  State<DrawerQuestions> createState() => _DrawerQuestionsState();
}

class _DrawerQuestionsState extends State<DrawerQuestions> {
  bool _isDragging = false;
  ScrollController? _pagesScrollController;
  ScrollController get pagesScrollController =>
      _pagesScrollController ??= ScrollController();

  ScrollController? _docsScrollController;
  ScrollController get docsScrollController =>
      _docsScrollController ??= ScrollController();

  @override
  void dispose() {
    _pagesScrollController?.dispose();
    _docsScrollController?.dispose();
    super.dispose();
  }

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
              duration: AppMotion.duration(context, milliseconds: 220),
              curve: Curves.easeOutCubic,
              left: isOpen ? 0 : -256,
              top: 0,
              bottom: 0,
              width: 252,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.overlaySurface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                  border: Border.all(
                    color: AppColors.overlayBorder,
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x77000000),
                      blurRadius: 8,
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
                          bottom: BorderSide(color: AppColors.overlayBorder),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.collections_bookmark_outlined,
                            size: 15,
                            color: AppColors.overlayAccent,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Tài liệu giảng dạy',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.overlayText,
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
                              color: AppColors.overlaySelected,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                            child: Text(
                              '${studio.pages.length} trang${studio.importedDocs.isNotEmpty ? " · ${studio.importedDocs.length} tệp" : ""}',
                              style: const TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.overlayAccent,
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
                                color: AppColors.overlayMuted,
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
                                color: AppColors.overlayAccent,
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                'TRANG BÀI GIẢNG',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.overlayAccent,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'P.${studio.page + 1}/${studio.pages.length}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.overlayMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _buildPagesList(studio),
                          _buildAddPageButton(studio),

                          // 2. PHÂN CÁCH NGĂN CÁCH VỚI CÁC TỆP FILE
                          _buildSectionDivider(studio),

                          // 3. DANH SÁCH TỆP TÀI LIỆU (PDF)
                          _buildDropTargetBar(studio),
                          const SizedBox(height: 6),
                          _buildDocsList(studio),

                          // 4. TIỆN ÍCH MÔN HỌC (PLUGINS)
                          _buildPluginsSection(context),
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
                        color: AppColors.overlaySurface,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(7),
                          bottomRight: Radius.circular(7),
                        ),
                        border: Border.all(color: AppColors.overlayBorder),
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
                            color: AppColors.overlayAccent,
                          ),
                          if (studio.importedDocs.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.overlayRaised,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${studio.importedDocs.length}',
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.overlayAccent,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right,
                            size: 12,
                            color: AppColors.overlayMuted,
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

  Widget _buildPagesList(StudioState studio) {
    final pageCount = studio.pages.length;
    if (pageCount <= 3) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < pageCount; i++) _buildPageItem(studio, i),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 126),
      child: Scrollbar(
        controller: pagesScrollController,
        thumbVisibility: true,
        thickness: 3.5,
        radius: const Radius.circular(3),
        child: ListView.builder(
          controller: pagesScrollController,
          padding: EdgeInsets.zero,
          itemCount: pageCount,
          itemBuilder: (context, i) => _buildPageItem(studio, i),
        ),
      ),
    );
  }

  Widget _buildDocsList(StudioState studio) {
    if (studio.importedDocs.isEmpty) {
      return const Center(
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
      );
    }
    if (studio.importedDocs.length <= 3) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final doc in studio.importedDocs)
            _buildDraggableDocItem(
              studio,
              doc,
              doc.id == studio.activeDocId &&
                  studio.viewportMode != StudioViewportMode.fullBoard,
            ),
        ],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 156),
      child: Scrollbar(
        controller: docsScrollController,
        thumbVisibility: true,
        thickness: 3.5,
        radius: const Radius.circular(3),
        child: ListView.builder(
          controller: docsScrollController,
          padding: EdgeInsets.zero,
          itemCount: studio.importedDocs.length,
          itemBuilder: (context, i) {
            final doc = studio.importedDocs[i];
            return _buildDraggableDocItem(
              studio,
              doc,
              doc.id == studio.activeDocId &&
                  studio.viewportMode != StudioViewportMode.fullBoard,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPluginsSection(BuildContext context) {
    return ListenableBuilder(
      listenable: PluginManager.instance,
      builder: (context, _) {
        final plugins = PluginManager.instance.installedPlugins;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 10, bottom: 8),
              child: Divider(color: AppColors.overlayBorder, height: 1),
            ),
            Row(
              children: [
                const Icon(
                  Icons.extension_outlined,
                  size: 13,
                  color: AppColors.overlayAccent,
                ),
                const SizedBox(width: 5),
                const Expanded(
                  child: Text(
                    'TIỆN ÍCH MÔN HỌC',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: AppColors.overlayAccent,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.overlaySelected,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    plugins.isEmpty ? 'Plugins' : '${plugins.length}',
                    style: const TextStyle(
                      fontSize: 7.5,
                      color: AppColors.overlayAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            for (final p in plugins) ...[
              InkWell(
                onTap: () {
                  if (p is InstalledPlugin) {
                    widget.studio.openPlugin(p);
                  } else {
                    PluginManager.instance.openPlugin(p);
                  }
                },
                borderRadius: BorderRadius.circular(AppRadii.control),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.overlaySelected,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    border: Border.all(color: AppColors.overlaySelected),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.extension,
                        size: 14,
                        color: AppColors.overlayAccent,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          p is InstalledPlugin ? p.manifest.name : p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.overlayAccent,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 10,
                        color: AppColors.overlayMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            InkWell(
              onTap: () => _showInstallPluginDialog(context),
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.overlayRaised,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: AppColors.overlayBorder),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      size: 14,
                      color: AppColors.overlayAccent,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cài thêm tiện ích môn',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.overlayAccent,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: AppColors.overlayMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInstallPluginDialog(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xff122019),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.overlayBorder),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.extension_outlined,
              color: AppColors.overlayAccent,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Thêm tiện ích môn học',
              style: TextStyle(
                color: AppColors.overlayText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Chọn nguồn tiện ích để cài đặt vào Học Lực Studio:',
              style: TextStyle(color: AppColors.overlayMuted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'sample'),
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overlaySelected,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: AppColors.overlaySelected),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.overlayAccent,
                      size: 20,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cài đặt Plugin Mẫu (Trợ giảng Tiếng Anh)',
                            style: TextStyle(
                              color: AppColors.overlayAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Bóc tách S-V-O & bắt lỗi ngữ pháp với spaCy & LanguageTool',
                            style: TextStyle(
                              color: AppColors.overlayMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () => Navigator.pop(ctx, 'file'),
              borderRadius: BorderRadius.circular(AppRadii.control),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.overlayRaised,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: AppColors.overlayBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.folder_open, color: AppColors.border, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chọn tệp .hlep từ máy tính...',
                            style: TextStyle(
                              color: AppColors.border,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Nạp gói plugin đóng gói chuẩn .hlep hoặc .zip',
                            style: TextStyle(
                              color: AppColors.overlayMuted,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Đóng',
              style: TextStyle(color: AppColors.overlayMuted),
            ),
          ),
        ],
      ),
    );

    if (!context.mounted || result == null) return;

    if (result == 'sample') {
      try {
        await PluginManager.instance.installSampleEnglishPlugin();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Đã cài đặt thành công plugin "Trợ giảng Tiếng Anh"!',
              ),
              backgroundColor: Color(0xff1b2e25),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cài đặt plugin: $e'),
              backgroundColor: const Color(0xff8b1c1c),
            ),
          );
        }
      }
    } else if (result == 'file') {
      try {
        final files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['hlep', 'zip'],
        );
        if (files.isNotEmpty) {
          final file = files.first;
          final bytes = await file.readAsBytes();
          await PluginManager.instance.installPluginFromBytes(bytes, file.name);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Đã cài đặt thành công plugin "${file.name}"!'),
                backgroundColor: const Color(0xff1b2e25),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể nạp tệp plugin: $e'),
              backgroundColor: const Color(0xff8b1c1c),
            ),
          );
        }
      }
    }
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
              backgroundColor: AppColors.overlayRaised,
              foregroundColor: AppColors.overlayAccent,
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
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
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: AnimatedContainer(
          duration: AppMotion.duration(context, milliseconds: 150),
          curve: AppMotion.stateCurve,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCurrent
                ? AppColors.overlaySelected
                : AppColors.overlayRaised,
            border: Border.all(
              color: isCurrent
                  ? AppColors.overlayAccent
                  : AppColors.overlayBorder,
              width: isCurrent ? 1.4 : 1.0,
            ),
            borderRadius: BorderRadius.circular(AppRadii.control),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.overlayAccent
                      : AppColors.overlayBorder,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isCurrent
                          ? const Color(0xff14221d)
                          : AppColors.overlayText,
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
                    color: isCurrent ? Colors.white : AppColors.overlayText,
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
                      color: AppColors.overlayMuted,
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
                        color: AppColors.errorSurface,
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
                    ? AppColors.overlayAccent
                    : AppColors.overlayMuted,
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
      borderRadius: BorderRadius.circular(AppRadii.control),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        margin: const EdgeInsets.only(top: 2, bottom: 4),
        decoration: BoxDecoration(
          color: AppColors.overlaySelected,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.overlaySelected),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 14, color: AppColors.overlayAccent),
            SizedBox(width: 4),
            Flexible(
              child: Text(
                'Thêm trang bài giảng',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.overlayAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionDivider(StudioState studio) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(color: AppColors.overlayBorder, height: 1),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.folder_open_outlined,
                size: 13,
                color: AppColors.overlayAccent,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'TỆP TÀI LIỆU (${studio.importedDocs.length})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.overlayAccent,
                  ),
                ),
              ),
            ],
          ),
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
        duration: AppMotion.duration(context, milliseconds: 150),
        curve: AppMotion.stateCurve,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _isDragging
              ? AppColors.overlaySelected
              : AppColors.overlayRaised,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(
            color: _isDragging
                ? AppColors.overlayAccent
                : AppColors.overlayBorder,
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
                : AppColors.overlayBorder,
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
}
